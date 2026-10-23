#!/usr/bin/env python3
"""Local PostgreSQL only. Network-disabled disposable container; no hosted credentials."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
NAME = os.environ['BB_PLANNER_TEST_CONTAINER']
assert NAME.startswith('bb-planner-disposable-'), 'Disposable container required'
ENV = {k: v for k, v in os.environ.items() if k not in ('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH')}
DOCKER = ['docker','--host=unix:///var/run/docker.sock']
def sql(s, ok=True):
    p = subprocess.run(DOCKER + ['exec','-i',NAME,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-U','postgres','-d','bb_planner_disposable'], input=s, text=True, capture_output=True, env=ENV)
    if ok and p.returncode: raise AssertionError(p.stderr)
    return p

A,B,C,D = [f'00000000-0000-4000-8000-{x:012d}' for x in range(1,5)]
H,J = [f'10000000-0000-4000-8000-{x:012d}' for x in range(1,3)]
def item(n): return f'20000000-0000-4000-8000-{n:012d}'
def arr(ids): return "ARRAY[" + ','.join("'%s'::uuid" % x for x in ids) + ']'
def as_user(u, s): return f"SET SESSION AUTHORIZATION authenticated; SET request.jwt.claim.sub='{u}'; " + s
checks = []
def allow(label,u,s):
    p=sql(as_user(u,s)); checks.append(label); return p.stdout.strip()
def deny(label,u,s,code='42501'):
    p=sql(as_user(u,s),False)
    assert p.returncode and code in p.stderr, (label,p.stdout,p.stderr)
    checks.append(label)
def create(n,kind='task',mode='individual',ids=None,u=A,h=H):
    return allow(f'create {n}',u,f"SELECT public.bb_planner_create('{h}','{item(n)}','{kind}','Fictional item {n}','{mode}',{arr(ids or [B])});")

# Bootstrap is deliberately usable only in an explicitly disposable local database.
sql("""DO $$ BEGIN IF current_database()<>'bb_planner_disposable' THEN RAISE EXCEPTION 'Local only'; END IF; END $$;
CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),(nullif(current_setting('request.jwt.claims',true),'')::jsonb ->> 'sub'))::uuid $$;
REVOKE ALL ON SCHEMA auth FROM PUBLIC;
GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
CREATE TABLE public.bb_test_canary(id integer PRIMARY KEY,payload text);
INSERT INTO public.bb_test_canary VALUES(1,'preserve');
ALTER TABLE public.bb_test_canary ENABLE ROW LEVEL SECURITY;
"""
)
p=sql((ROOT/'schema.sql').read_text(),False)
assert p.returncode and 'explicit planner-v1 opt-in' in p.stderr
checks.append('schema refuses missing administrator opt-in')
sql("SET bb_planner.approved_schema='planner-v1';\n" + (ROOT/'schema.sql').read_text())
sql((ROOT/'hosted-identity-compatibility.sql').read_text())
sql((ROOT/'indexes.sql').read_text())
sql("REVOKE USAGE ON SCHEMA auth FROM bb_planner_executor;")
assert sql("SELECT has_schema_privilege('bb_planner_executor','auth','USAGE');").stdout.strip()=='f'
checks.append('restricted executor works without managed auth schema access')
sql('INSERT INTO auth.users VALUES '+','.join(f"('{x}')" for x in [A,B,C,D])+';'+
    f"INSERT INTO public.bb_planner_households(id,label) VALUES('{H}','Fictional test household'),('{J}','Unrelated fictional household');"+
    'INSERT INTO public.bb_planner_members(household_id,user_id,member_role) VALUES '+','.join(f"('{h}','{u}','{r}')" for h,u,r in [(H,A,'adult'),(H,B,'child'),(H,C,'child'),(J,D,'adult')])+';')
create(1)
deny('child cannot create Task',B,f"SELECT public.bb_planner_create('{H}','{item(2)}','task','Fictional','individual',{arr([B])});")
create(2,'activity',u=B)
deny('child cannot assign sibling on create',B,f"SELECT public.bb_planner_create('{H}','{item(3)}','activity','Fictional','individual',{arr([C])});")
deny('child cannot broaden Activity to Shared',B,f"SELECT public.bb_planner_create('{H}','{item(3)}','activity','Fictional','shared',{arr([B,C])});")
deny('outsider cannot create',D,f"SELECT public.bb_planner_create('{H}','{item(3)}','task','Fictional','individual',{arr([B])});")
deny('sibling cannot rename Activity',C,f"SELECT public.bb_planner_rename('{item(2)}','Changed',1);")
allow('owner can rename Activity',B,f"SELECT public.bb_planner_rename('{item(2)}','Changed',1);")
deny('stale version rejected',B,f"SELECT public.bb_planner_rename('{item(2)}','Changed again',1);",'40001')
deny('child cannot rename Task',B,f"SELECT public.bb_planner_rename('{item(1)}','Changed',1);")
deny('sibling cannot complete individual',C,f"SELECT public.bb_planner_complete('{item(1)}');")
deny('child cannot impersonate',C,f"SELECT public.bb_planner_complete('{item(1)}','{B}');")
allow('assigned child completes',B,f"SELECT public.bb_planner_complete('{item(1)}');")
allow('duplicate individual completion idempotent',B,f"SELECT public.bb_planner_complete('{item(1)}');")
deny('reassignment after completion rejected',A,f"SELECT public.bb_planner_assign('{item(1)}','individual',{arr([C])},2);",'55000')
deny('child cannot reassign',B,f"SELECT public.bb_planner_assign('{item(2)}','individual',{arr([C])},2);")
create(3)
allow('adult reassigns before contribution',A,f"SELECT public.bb_planner_assign('{item(3)}','individual',{arr([C])},1);")
allow('adult completes on behalf of assigned child',A,f"SELECT public.bb_planner_complete('{item(3)}','{C}');")
create(4,mode='household',ids=[B,C])
create(5,mode='shared',ids=[B,C])
deny('unrelated household cannot list',D,f"SELECT * FROM public.bb_planner_list('{H}');")
deny('unrelated household cannot complete',D,f"SELECT public.bb_planner_complete('{item(4)}');")
assert allow('outsider direct SELECT is empty',D,'SELECT count(*) FROM public.bb_planner_items;')=='0'
assert allow('all household members see shared planner',C,'SELECT count(*) FROM public.bb_planner_items;')=='5'
for table in ['items','members','assignments','completions','events','households']:
    deny('direct write denied '+table,A,f'DELETE FROM public.bb_planner_{table};')
deny('immutable creator denied',B,f"UPDATE public.bb_planner_items SET created_by='{B}' WHERE id='{item(1)}';")
deny('role escalation denied',B,"UPDATE public.bb_planner_members SET member_role='adult';")
deny('executor role cannot be assumed',B,'SET ROLE bb_planner_executor;')
deny('private helper not callable',B,f"SELECT bb_planner_private.item_state('{item(1)}');")
p=sql(f"SET SESSION AUTHORIZATION anon; SELECT * FROM public.bb_planner_list('{H}');",False)
assert p.returncode and '42501' in p.stderr
checks.append('anonymous list denied')
deny('missing identity denied','',f"SELECT * FROM public.bb_planner_list('{H}');")
deny('cross-household assignment rejected',A,f"SELECT public.bb_planner_assign('{item(2)}','individual',{arr([D])},2);",'22023')
deny('empty assignment rejected',A,f"SELECT public.bb_planner_assign('{item(2)}','shared',ARRAY[]::uuid[],2);",'22023')
deny('duplicate assignment rejected',A,f"SELECT public.bb_planner_assign('{item(2)}','shared',{arr([B,B])},2);",'22023')

# Independent connections: first completion holds its row lock while competitor starts.
def competing(n, first, second):
    with concurrent.futures.ThreadPoolExecutor() as pool:
        f=pool.submit(sql,as_user(first,f"BEGIN; SELECT public.bb_planner_complete('{item(n)}'); SELECT pg_sleep(2); COMMIT;"))
        # Wait for the first transaction to hold the item lock, not a timing guess.
        for attempt in range(100):
            if sql("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event='PgSleep';").stdout.strip() == '1': break
            time.sleep(0.01)
        else: raise AssertionError('First completion did not reach lock-holding sleep')
        g=pool.submit(sql,as_user(second,f"SELECT public.bb_planner_complete('{item(n)}');"))
        f.result(); g.result()
competing(4,B,C)
assert sql(f"SELECT count(*)=1 AND min(actor_id::text)='{B}' FROM public.bb_planner_completions WHERE item_id='{item(4)}';").stdout.strip()=='t'
checks.append('concurrent Household completion once preserves first actor')
competing(5,B,C)
assert sql(f"SELECT count(*)=2 FROM public.bb_planner_completions WHERE item_id='{item(5)}';").stdout.strip()=='t'
assert json.loads(allow('Shared complete after both contributions',B,f"SELECT public.bb_planner_complete('{item(5)}');"))['complete'] is True
checks.append('concurrent Shared contributions preserved')
assert sql(f"SELECT count(*)=1 FROM public.bb_planner_events WHERE item_id='{item(4)}' AND action='completed';").stdout.strip()=='t'
assert sql(f"SELECT actor_id='{A}' AND assignee_id='{C}' FROM public.bb_planner_completions WHERE item_id='{item(3)}';").stdout.strip()=='t'
checks.append('adult on-behalf attribution preserved')
create(6,mode='household',ids=[B,C])
allow('adult can finish Household once',A,f"SELECT public.bb_planner_complete('{item(6)}');")
allow('duplicate household request leaves state unchanged',C,f"SELECT public.bb_planner_complete('{item(6)}');")
assert sql(f"SELECT count(*)=1 FROM public.bb_planner_completions WHERE item_id='{item(6)}';").stdout.strip()=='t'
assert sql("SELECT payload='preserve' AND relrowsecurity FROM public.bb_test_canary JOIN pg_class ON relname='bb_test_canary';").stdout.strip()=='t'
checks.append('existing canary data and RLS unchanged')
assert sql("SELECT count(*)=6 FROM pg_class WHERE relname LIKE 'bb_planner_%' AND relkind='r' AND relrowsecurity;").stdout.strip()=='t'
checks.append('all six new tables have RLS')
sql("INSERT INTO auth.users VALUES ('6fe4e705-a92f-44ea-9898-d0eebf1f95d5'),('fd9810b3-6190-4587-b33c-81de6564a5dc'),('bb0bed90-1037-419f-a385-90e543575864');")
sql("SET bb_planner.approved_bootstrap='fictional-v1';\n"+(ROOT/'fictional-bootstrap.sql').read_text())
assert sql("SELECT count(*) FROM public.bb_planner_members WHERE household_id='bba90000-0000-4000-8000-000000000001';").stdout.strip()=='3'
checks.append('fictional bootstrap creates only separate planner membership')
create(7,mode='shared',ids=[B,C])
partial=json.loads(allow('Shared first contribution remains incomplete',B,f"SELECT public.bb_planner_complete('{item(7)}');"))
assert partial['complete'] is False and len(partial['completions'])==1
create(8)
with concurrent.futures.ThreadPoolExecutor() as pool:
    f=pool.submit(sql,as_user(B,f"BEGIN; SELECT public.bb_planner_complete('{item(8)}'); SELECT pg_sleep(2); COMMIT;"))
    for attempt in range(100):
        if sql("SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event='PgSleep';").stdout.strip()=='1': break
        time.sleep(0.01)
    else: raise AssertionError('Completion lock not acquired')
    p=sql(as_user(A,f"SELECT public.bb_planner_assign('{item(8)}','individual',{arr([C])},2);"),False)
    f.result()
assert p.returncode and '55000' in p.stderr
checks.append('concurrent completion blocks reassignment without losing contribution')
# Verify modern JSON claim extraction without the legacy sub GUC.
assert sql(as_user('',f"SET request.jwt.claims='{{\"sub\":\"{B}\"}}'; SELECT count(*) FROM public.bb_planner_list('{H}');")).stdout.strip()=='8'
checks.append('modern verified JWT claim format supported')
# Rollback must refuse populated data, then remove only the empty planner namespace.
p=sql("SET bb_planner.approved_rollback='empty-planner-v1';\n"+(ROOT/'rollback-empty.sql').read_text(),False)
assert p.returncode and 'Planner contains data' in p.stderr
checks.append('rollback refuses populated planner')
sql('DELETE FROM public.bb_planner_events; DELETE FROM public.bb_planner_completions; DELETE FROM public.bb_planner_assignments; DELETE FROM public.bb_planner_items; DELETE FROM public.bb_planner_members; DELETE FROM public.bb_planner_households;')
sql("SET bb_planner.approved_rollback='empty-planner-v1';\n"+(ROOT/'rollback-empty.sql').read_text())
assert sql("SELECT to_regclass('public.bb_planner_items') IS NULL AND NOT EXISTS(SELECT FROM pg_roles WHERE rolname='bb_planner_executor');").stdout.strip()=='t'
assert sql("SELECT payload FROM public.bb_test_canary;").stdout.strip()=='preserve'
checks.append('empty rollback removes only new objects and role')
print(json.dumps({'status':'PASS','checks':len(checks),'passed':checks,'limitations':'Local auth.uid stub; hosted JWT/PostgREST and browser integration not yet tested.'},indent=2))

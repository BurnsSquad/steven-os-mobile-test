import {createHandler} from './handler.mjs';
function key(jsonName:string,legacyName:string){try{return JSON.parse(Deno.env.get(jsonName)||'{}').default||Deno.env.get(legacyName)||'';}catch{return '';}}
Deno.serve(createHandler({base:Deno.env.get('SUPABASE_URL'),publicKey:key('SUPABASE_PUBLISHABLE_KEYS','SUPABASE_ANON_KEY'),adminKey:key('SUPABASE_SECRET_KEYS','SUPABASE_SERVICE_ROLE_KEY')}));

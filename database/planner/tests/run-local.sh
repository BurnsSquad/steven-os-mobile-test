#!/usr/bin/env bash
set -euo pipefail
unset DOCKER_HOST DOCKER_CONTEXT DOCKER_TLS DOCKER_TLS_VERIFY DOCKER_CERT_PATH
docker_cmd=(docker --host=unix:///var/run/docker.sock)
export BB_PLANNER_TEST_CONTAINER="bb-planner-disposable-$$"
image='postgres@sha256:f3bd19c606e442c3d7bdfa8002e03fe260a1023351e0ea4598032022b68dd6e3'
"${docker_cmd[@]}" run --detach --name "$BB_PLANNER_TEST_CONTAINER" --network none --tmpfs /var/lib/postgresql/data --label bb-planner.disposable=true -e POSTGRES_HOST_AUTH_METHOD=trust "$image" >/dev/null
trap '"${docker_cmd[@]}" rm --force "$BB_PLANNER_TEST_CONTAINER" >/dev/null' EXIT
for attempt in {1..60}; do
  if "${docker_cmd[@]}" exec "$BB_PLANNER_TEST_CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 0.2
done
"${docker_cmd[@]}" exec "$BB_PLANNER_TEST_CONTAINER" createdb -U postgres bb_planner_disposable
python3 "$(dirname "$0")/run.py"

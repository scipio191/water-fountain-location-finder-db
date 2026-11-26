#!/bin/bash
set -e

# Only wrap the normal server start; pass anything else straight through
if [ "$1" != "postgres" ]; then
  exec docker-entrypoint.sh "$@"
fi

# Start the stock entrypoint (runs initdb + /docker-entrypoint-initdb.d on first boot)
docker-entrypoint.sh "$@" &
pid=$!

# Forward shutdown signals so Postgres stops cleanly
trap 'kill -TERM "$pid" 2>/dev/null' TERM INT

# Wait for the real server (the temporary init server doesn't listen on TCP)
until pg_isready -h localhost -U "${POSTGRES_USER:-postgres}" -q; do
  kill -0 "$pid" 2>/dev/null || exit 1
  sleep 1
done

export PGUSER="${POSTGRES_USER:-postgres}"
export PGPASSWORD="$POSTGRES_PASSWORD"
export PGDATABASE="${POSTGRES_DB:-$PGUSER}"

for f in /docker-entrypoint-startup.d/*; do
  [ -e "$f" ] || continue
  case "$f" in
    *.sh)  echo "startup: running $f"; bash "$f" ;;
    *.sql) echo "startup: running $f"; psql -h localhost -v ON_ERROR_STOP=1 -f "$f" ;;
  esac
done

# Keep the container alive for as long as Postgres runs
wait "$pid" || true
wait "$pid"
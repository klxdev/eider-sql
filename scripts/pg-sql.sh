#!/bin/sh
# Runs one SQL statement as the superuser in the container that scripts/pg-up.sh started (for the tests' set-up).
#
#   sh scripts/pg-sql.sh "DROP TABLE IF EXISTS t"
NAME=${EIDER_PG_NAME:-eider-sql-pg-test}
if command -v podman >/dev/null 2>&1; then
  podman exec "$NAME" psql -q -U eider -d eiderdb -c "$1"
elif command -v flatpak-spawn >/dev/null 2>&1; then
  flatpak-spawn --host podman exec "$NAME" psql -q -U eider -d eiderdb -c "$1"
else
  echo "pg-sql: no podman" >&2
  exit 3
fi

# Sourced by scripts/test.sh with EIDER_SQL (the built program), T (a scratch directory), here and fail set:
# the command line of eider-sql, end to end. cli_free needs no server; cli_server migrates a real database.

cli_expect() { # <label> <expected output> <command...>: the output (stdout and stderr) must equal the expected text
  label=$1; want=$2; shift 2
  got=$("$@" 2>&1 < /dev/null)
  if [ "$got" = "$want" ]; then echo "ok   cli: $label"; else echo "FAIL cli: $label"; printf '%s\n' "$got" | diff - "$T/want" | head -10; fail=1; fi
}

cli_free() {
  d=tests/data
  want=$(cat <<'EOF'
ok: 11 queries in 2 files checked against 2 migrations
tests/data/gen/orders.ei: up to date
tests/data/gen/users.ei: up to date
EOF
)
  printf '%s\n' "$want" > "$T/want"
  cli_expect "check is ok and the generated modules are current" "$want" "$EIDER_SQL" check --migrations $d/migrations --queries $d/queries --out $d/gen

  # gen into a scratch directory writes the same files, and a second run changes nothing
  "$EIDER_SQL" gen --migrations $d/migrations --queries $d/queries --out "$T/gen" > "$T/gen.log" 2>&1
  if cmp -s "$T/gen/users.ei" $d/gen/users.ei && cmp -s "$T/gen/orders.ei" $d/gen/orders.ei; then echo "ok   cli: gen writes the golden modules"; else echo "FAIL cli: gen output differs from tests/data/gen"; fail=1; fi
  second=$("$EIDER_SQL" gen --migrations $d/migrations --queries $d/queries --out "$T/gen" 2>&1)
  printf '%s\n%s\n' "$T/gen/orders.ei: unchanged" "$T/gen/users.ei: unchanged" > "$T/want"
  if [ "$second" = "$(cat "$T/want")" ]; then echo "ok   cli: a second gen changes nothing"; else echo "FAIL cli: second gen"; echo "$second"; fail=1; fi

  # a stale generated module is reported
  mkdir -p "$T/stale"; cp $d/gen/*.ei "$T/stale/"; printf '// edited\n' >> "$T/stale/users.ei"
  got=$("$EIDER_SQL" check --migrations $d/migrations --queries $d/queries --out "$T/stale" 2>&1)
  if echo "$got" | grep -qF "users.ei: out of date"; then echo "ok   cli: a stale module is reported"; else echo "FAIL cli: stale module"; echo "$got"; fail=1; fi

  # a bad query is reported with file:line:col, and the exit code is 1
  mkdir -p "$T/bad/migrations" "$T/bad/queries"
  cp $d/migrations/*.sql "$T/bad/migrations/"
  printf -- '-- name: Typo :one\nSELECT id, emial FROM users WHERE id = :id;\n' > "$T/bad/queries/q.sql"
  got=$("$EIDER_SQL" check --migrations "$T/bad/migrations" --queries "$T/bad/queries" --out "$T/bad/gen" 2>&1); code=$?
  if [ $code = 1 ] && echo "$got" | grep -qF 'q.sql:2:12: column "emial" does not exist; did you mean "email"? (in Typo)'; then echo "ok   cli: a bad query fails with its position"; else echo "FAIL cli: bad query ($code)"; echo "$got"; fail=1; fi

  # a broken migration
  printf 'CREATE TABLE t (id int,, x int);\n' > "$T/bad/migrations/003_broken.sql"
  got=$("$EIDER_SQL" schema --migrations "$T/bad/migrations" 2>&1); code=$?
  if [ $code = 1 ] && echo "$got" | grep -qF "003_broken.sql:1:24: expected a name"; then echo "ok   cli: a broken migration fails with its position"; else echo "FAIL cli: broken migration ($code)"; echo "$got"; fail=1; fi

  got=$("$EIDER_SQL" schema --migrations $d/migrations 2>&1 | head -3 | tr '\n' '|')
  if [ "$got" = "table users|  id int8 not null default pk|  email text not null|" ]; then echo "ok   cli: schema"; else echo "FAIL cli: schema: $got"; fail=1; fi

  got=$("$EIDER_SQL" bogus 2>&1); code=$?
  if [ $code != 0 ]; then echo "ok   cli: an unknown command fails"; else echo "FAIL cli: unknown command"; fail=1; fi
}

cli_server() {
  d=tests/data
  url="postgres://eider:eider_pw@127.0.0.1:${EIDER_PG_PORT:-55440}/eiderdb?sslmode=disable"
  flags="--migrations $d/migrations --url $url --table cli_hist"
  # start clean (a previous test may have used these tables)
  sh "$here/scripts/pg-sql.sh" "DROP TABLE IF EXISTS orders, users, cli_hist CASCADE" > /dev/null 2>&1
  got=$("$EIDER_SQL" status $flags 2>&1); code=$?
  printf 'pending 1 users\npending 2 orders\n' > "$T/want"
  if [ "$got" = "$(cat "$T/want")" ]; then echo "ok   cli: status before migrating"; else echo "FAIL cli: status: $got"; fail=1; fi
  got=$("$EIDER_SQL" migrate $flags --dry-run 2>&1)
  printf 'would apply 1 users\nwould apply 2 orders\n2 would apply, 0 already applied\n' > "$T/want"
  if [ "$got" = "$(cat "$T/want")" ]; then echo "ok   cli: migrate --dry-run"; else echo "FAIL cli: dry run: $got"; fail=1; fi
  got=$("$EIDER_SQL" migrate $flags 2>&1)
  printf 'applied 1 users\napplied 2 orders\n2 applied, 0 already applied\n' > "$T/want"
  if [ "$got" = "$(cat "$T/want")" ]; then echo "ok   cli: migrate"; else echo "FAIL cli: migrate: $got"; fail=1; fi
  got=$("$EIDER_SQL" migrate $flags 2>&1)
  printf '0 applied, 2 already applied\n' > "$T/want"
  if [ "$got" = "$(cat "$T/want")" ]; then echo "ok   cli: migrate again does nothing"; else echo "FAIL cli: second migrate: $got"; fail=1; fi
  got=$("$EIDER_SQL" status $flags 2>&1)
  printf 'applied 1 users\napplied 2 orders\n' > "$T/want"
  if [ "$got" = "$(cat "$T/want")" ]; then echo "ok   cli: status after migrating"; else echo "FAIL cli: status after: $got"; fail=1; fi
  # an edited migration is refused with exit code 1
  mkdir -p "$T/edited"; cp $d/migrations/*.sql "$T/edited/"; printf -- '-- edited\n' >> "$T/edited/001_users.sql"
  got=$("$EIDER_SQL" migrate --migrations "$T/edited" --url "$url" --table cli_hist 2>&1); code=$?
  if [ $code = 1 ] && echo "$got" | grep -qF "migration 1 (users): edited after it was applied"; then echo "ok   cli: an edited migration is refused"; else echo "FAIL cli: edited ($code): $got"; fail=1; fi
  got=$(EIDER_SQL_URL="$url" "$EIDER_SQL" status --migrations $d/migrations --table cli_hist 2>&1)
  if [ "$got" = "$(printf 'applied 1 users\napplied 2 orders')" ]; then echo "ok   cli: the URL from EIDER_SQL_URL"; else echo "FAIL cli: env url: $got"; fail=1; fi
  sh "$here/scripts/pg-sql.sh" "DROP TABLE IF EXISTS orders, users, cli_hist CASCADE" > /dev/null 2>&1
}

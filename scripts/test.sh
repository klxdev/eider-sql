#!/bin/sh
# eider-sql's tests.
#
#   sh scripts/test.sh             scripts/build.sh, then every test
#   NOBUILD=1 sh scripts/test.sh   skip scripts/build.sh (the locks are already fetched)
#   NODB=1 sh scripts/test.sh      only the tests that need no server
#   PG_VERSIONS="16 17" sh scripts/test.sh   run the server tests against each (default 17)
#   ASAN=1 sh scripts/test.sh      also run the server-free tests under AddressSanitizer and UBSan
#
# Every tests/*_test.ei is run with the toolchain's compiler (`eider run`) and its output compared with the .out
# next to it. Kinds:
#
#   no server:   lex_test, ddl_test, check_test, build_test, gen_test (golden output of `eider-sql gen`),
#                hostile_test (hostile input never traps), comptime_test (the checker as a compile-time check)
#   compile-fail: tests/fail/*.ei must not compile, and the compiler's message must contain the line of the .expect
#   cli:         the eider-sql program (check, gen, schema; with a server also migrate and status), tests/cli.sh
#   a server:    pg_*_test, against a real PostgreSQL in a container that scripts/pg-up.sh starts (podman;
#                docker.io/library/postgres:$VERSION) and scripts/pg-down.sh removes, also when a test fails or this
#                script is interrupted: pg_corpus_test (the checker against the server's own Describe),
#                pg_gen_test (generated code, transactions, load_many, the builder), pg_migrate_test (the migration
#                runner, including runners racing on the advisory lock). With no podman or no image they are
#                `skip`ped with the reason and the exit code is still 0.
#
# Prints `ok   <test>`, `skip <test>: why` or `FAIL <test>` with a diff, then `ALL OK`; exits 1 on a failure, 2 when
# there is no usable toolchain (scripts/env.sh).
NOSERVER="tests/lex_test.ei tests/ddl_test.ei tests/check_test.ei tests/build_test.ei tests/gen_test.ei tests/hostile_test.ei tests/comptime_test.ei"
SERVER="tests/pg_corpus_test.ei tests/pg_gen_test.ei tests/pg_migrate_test.ei"
TSAN_SERVER="tests/pg_migrate_test.ei"
here=$(cd "$(dirname "$0")/.." && pwd -P)
if [ -z "$NOBUILD" ]; then
  sh "$here/scripts/build.sh" || exit $?
fi
. "$here/scripts/env.sh"
cd "$here" || exit 1
fail=0
T=$(mktemp -d)
cleanup() { sh "$here/scripts/pg-down.sh"; rm -rf "$T"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

run() { # <test>: run with eider and compare
  f=$1
  got=$(ei run "$f" 2>&1 < /dev/null)
  if [ "$got" = "$(cat "${f%.ei}.out")" ]; then echo "ok   $f"; else echo "FAIL $f"; echo "$got" | diff "${f%.ei}.out" - | head -10; fail=1; fi
}

tsan_ok=
tsan_probe() {
  if [ -z "$tsan_ok" ]; then
    printf 'int main(void) { return 0; }\n' > "$T/probe.c"
    if ${CC:-cc} -fsanitize=thread -o "$T/probe" "$T/probe.c" 2>/dev/null && "$T/probe"; then tsan_ok=yes; else tsan_ok=no; fi
  fi
  [ "$tsan_ok" = yes ]
}

tsan() { # <tests>
  if tsan_probe; then
    for f in "$@"; do
      if ! (EIDER_CACHE=off EIDER_CFLAGS="-fsanitize=thread -g"; export EIDER_CACHE EIDER_CFLAGS; ei build "$f" -o "$T/t") > "$T/log" 2>&1; then
        echo "FAIL $f (tsan): build"; cat "$T/log"; fail=1; continue
      fi
      got=$(TSAN_OPTIONS="halt_on_error=1 exitcode=66" "$T/t" < /dev/null 2>&1)
      if [ "$got" = "$(cat "${f%.ei}.out")" ]; then echo "ok   $f (tsan)"; else echo "FAIL $f (tsan)"; echo "$got" | diff "${f%.ei}.out" - | head -20; fail=1; fi
    done
  else
    echo "skip tsan runs ($*): ${CC:-cc} cannot build a -fsanitize=thread program"
  fi
}

for f in $NOSERVER; do run "$f"; done

# a query that does not fit the schema must not compile
for f in tests/fail/*.ei; do
  [ -f "$f" ] || continue
  if got=$(ei check "$f" 2>&1 < /dev/null); then
    echo "FAIL $f: it compiled"; fail=1
  elif echo "$got" | grep -qF "$(cat "${f%.ei}.expect")"; then
    echo "ok   $f (does not compile)"
  else
    echo "FAIL $f: the message lacks: $(cat "${f%.ei}.expect")"; echo "$got" | head -10; fail=1
  fi
done

# the eider-sql program, built once
if ei build bin/main.ei -o "$T/eider-sql" > "$T/build.log" 2>&1; then
  EIDER_SQL="$T/eider-sql"
  . "$here/tests/cli.sh"
  cli_free
else
  echo "FAIL bin/main.ei: build"; cat "$T/build.log"; fail=1
fi
tsan tests/hostile_test.ei

if [ -n "$NODB" ]; then
  echo "skip the server tests: NODB is set"
else
  for v in ${PG_VERSIONS:-17}; do
    echo "-- PostgreSQL $v"
    sh "$here/scripts/pg-up.sh" --version "$v" > "$T/up.log" 2>&1
    rc=$?
    if [ $rc = 0 ]; then
      cat "$T/up.log"
      for f in $SERVER; do run "$f"; done
      tsan $TSAN_SERVER
      if [ -x "$T/eider-sql" ]; then cli_server; fi
      sh "$here/scripts/pg-down.sh"
    elif [ $rc = 3 ]; then
      for f in $SERVER tests/cli.sh; do echo "skip $f: $(tail -1 "$T/up.log")"; done
    else
      echo "FAIL pg-up (exit $rc)"; cat "$T/up.log"; fail=1
    fi
  done
fi

if [ -n "$ASAN" ]; then
  for f in $NOSERVER; do
    if ! (EIDER_CACHE=off EIDER_CRYPTO_SAN=1 EIDER_CFLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g"; export EIDER_CACHE EIDER_CRYPTO_SAN EIDER_CFLAGS; ei build "$f" -o "$T/a") > "$T/log" 2>&1; then
      echo "FAIL $f (asan): build"; cat "$T/log"; fail=1; continue
    fi
    got=$(ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 "$T/a" < /dev/null 2>&1)
    if [ "$got" = "$(cat "${f%.ei}.out")" ]; then echo "ok   $f (asan+ubsan)"; else echo "FAIL $f (asan+ubsan)"; echo "$got" | diff "${f%.ei}.out" - | head -20; fail=1; fi
  done
fi
[ $fail = 0 ] && echo "ALL OK"
exit $fail

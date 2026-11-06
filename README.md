# eider-sql

Checked SQL for [Eider](https://github.com/klxdev/eider-lang) on [eider-postgres](https://github.com/klxdev/eider-postgres) (package `sql`). sqlc-style: queries live in `.sql` files, are checked against the schema the migrations build, **with no database**, and become typed Eider functions. No ORM.

```sql
-- queries/users.sql
-- name: GetUser :one
SELECT id, email, name FROM users WHERE id = :id;
```

```sh
eider-sql check          # migrations + queries, no database; fails with file:line:col
eider-sql gen            # writes gen/users.ei: GetUserRow, GET_USER_SQL, get_user(inout c, id: i64, dl)
eider-sql migrate --url postgres://...   # forward-only, advisory lock, checksums; --dry-run
eider-sql status  --url postgres://...
```

```eider
import myapp.gen.users          // generated, committed, compiled like any module
let u = users.get_user(inout c, 42, dl)?      // GetUserRow { id: i64, email: String, name: Option[String] }
```

What is in it (docs/design.md says what the language allows today and what is left for it):

- **A checker with no database** (`sql.lex`, `sql.ddl`, `sql.parse`, `sql.check`): reads the DDL of the migrations (CREATE/ALTER/DROP TABLE, indexes, enums) and checks SELECT, INSERT, UPDATE and DELETE (joins, aliases, `RETURNING`, `ON CONFLICT`, aggregates, `CASE`, casts, `= ANY($1)`, about 100 functions): tables, columns, operand types, and it infers the type of every parameter and the name, type and nullability of every result column. Anything it cannot analyze is `unsupported: <what>`, never a guess. Checked against PostgreSQL's own Describe on a corpus of 165 queries: 276 of 276 result columns and 91 of 91 parameter types agree (docs/checker.md).
- **Compile-time checking** (`sql.compiletime`): `const OK: i32 = comptime sqlc.check_all(List[embed("migrations/001.sql")], List[embed("queries/users.sql")])` runs the checker while the program is compiled and fails the build with the problems.
- **`eider-sql gen`** writes the typed module (records for rows, a function per query with typed parameters, `Option[T]` for nullable ones), the way sqlc does; `check` also says when a generated module is stale.
- **Migrations** (`sql.migrate`, `sql.migration`): forward-only, from a directory or embedded strings, ordered by version, recorded in `eider_migrations` with a checksum, run under `pg_advisory_lock` (replicas starting together take turns), each in its own transaction with its history row, edited or missing or out-of-order migrations refused before anything runs, `plan` (dry run) and `status`.
- **Transactions and N+1** (`sql.tx`, `sql.load`): `tx.run`, isolation levels, `tx.retry` on serialization failures and deadlocks, the pool; `load_many` runs one `= ANY($1)` query for a list of keys, in chunks.
- **A typed builder for dynamic SQL** (`sql.build`): select/where/order/limit/offset, batch insert, update, delete; every value a bound parameter, every identifier validated and quoted, sort columns from an allowed list, optionally checked against the schema.

Limits: PostgreSQL only; the subset in docs/checker.md (no CTEs, subqueries, set operations or window functions yet: they are `unsupported`, so write those queries with `postgres.typed` by hand); `gen` refuses column types `postgres.typed` cannot decode (interval, inet, time, ...: cast to text); the checker trusts literals (`'x'` into an integer column is not rejected); nullability of expressions is inferred conservatively. Compile-time embedding exists but item generation does not, so typed functions come from `gen`, not from `embed` alone. eider-postgres, eider-tls and crypto are path dependencies (see below), so this package is not yet consumable through git.

## Using it

`eider.toml` needs eider-postgres (a path dependency until it is consumable through git: `scripts/env.sh` links `../eider-postgres`, or `$EIDER_POSTGRES`, and the links eider-postgres itself needs) and, for the program, eider-command. The generated modules need `postgres`, `postgres.client`, `postgres.typed` and `std.serial`.

## Development

`sh scripts/test.sh` (it needs an eider-lang checkout as the toolchain until crypto is published: `EIDER_TOOLCHAIN=...`). The checker, parser, generator, builder and compile-time tests need nothing else; the server tests (the corpus against Describe, generated code, migrations and runners racing on the lock) start PostgreSQL in podman (`scripts/pg-up.sh`, port 55440, skipped with a message without podman). `sh scripts/regen-out.sh` rewrites the expected outputs; `sh scripts/version.sh` checks the version files.

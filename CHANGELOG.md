# Changelog

eider-sql's versions (semver). Before 1.0 the MAJOR.MINOR is the Eider toolchain's it goes
with (`eider` in eider.toml), the PATCH its own.

## 0.7.1

- Use `let mut` instead of the removed `var` (eider-lang#2).

## 0.7.0

First version, for Eider 0.7 (eider-lang issue 104): checked SQL on eider-postgres.

- A lexer, a DDL reader (CREATE/ALTER/DROP TABLE, CREATE/DROP INDEX, enums), a query parser and a checker for
  SELECT, INSERT, UPDATE and DELETE that infer parameter types and result columns (names, types, nullability) with no
  database; `unsupported:` for what they cannot analyze. Agrees with PostgreSQL's Describe on a corpus of 165 queries.
- `sql.compiletime`: the checker as a `comptime` constant over `embed`ded migrations and query files; a problem fails the
  build.
- `eider-sql check | gen | schema | migrate | status`: typed Eider modules from annotated `.sql` files, stale-module
  detection, positions as file:line:col.
- Migrations: forward-only, ordered, checksummed, under an advisory lock, one transaction each, dry run and status.
- Transaction helpers (isolation, retry), `load_many`, and a typed builder for dynamic SQL.
- Not done: CTEs, subqueries, set operations, window functions, lateral and set-returning functions in the checker;
  a way to make the typed functions from `embed` alone (needs comptime item generation); MySQL and SQLite.

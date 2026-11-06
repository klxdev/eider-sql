# sql

Modules: `sql` (Error, positions), `sql.lex`, `sql.cursor`, `sql.schema`, `sql.ddl` (migrations to a schema),
`sql.parse`, `sql.check` (types, no database), `sql.queryfile` (annotated `.sql` files), `sql.gen` (typed modules),
`sql.compiletime` (the checker as a constant), `sql.migration` and `sql.migrate` (the runner), `sql.tx`, `sql.load`,
`sql.build` (dynamic SQL), `sql.project` and `sql.dburl` (what the program uses). The program is `bin/main.ei`.

## Query files

```sql
-- name: GetUser :one            :one  exactly one row (Result[Row, Error]); none is a Decode error
-- Comment lines here document the function.   :opt  at most one (Result[Option[Row], Error])
SELECT id, email FROM users WHERE id = :id;     :many Result[List[Row], Error]   :exec Result[u64, Error] (rows changed)
```

Parameters are `$1`... or `:name` (numbered by first appearance); a query uses one form. A `RETURNING` statement is
`:one`, `:opt` or `:many`; a statement without rows is `:exec`. Column names must be valid field names (alias
`id + 1 AS next_id`); two columns with one name need an alias; keyword names get `@[serial(name = ...)]`.
Types: bool, int2/4/8, float4/8 (as f64), numeric, uuid, json, jsonb and text as String, bytea as `serial.Bytes`
(`List[u8]` as a parameter), date, timestamp, timestamptz as `time.DateTime`, enums as String, arrays as `List`. Others
(interval, time, inet, money, ...) are refused with a hint to cast to text.

## Migrations

```eider
let ms = List[migration.make(1, String.from("users"), String.from("CREATE TABLE ...")), ...]   // or project.load_migrations(dir)
let report = migrate.up(inout c, ms, migrate.options(), dl)?       // migrate.plan: a dry run; migrate.status: applied/pending/changed/missing
```

`migrate.options()` names the history table (`eider_migrations`). See docs/design.md for the rules.

## Transactions, load_many, builder

```eider
tx.run(inout c, dl, |inout t| -> Result[i64, postgres.Error] { ... })
tx.retry(inout c, 3, tx.Serializable, dl, |inout t| -> Result[i64, postgres.Error] { ... })
load.load_many_by[OrderRow, i64, str](inout c, ORDERS_BY_USERS_SQL, load.ints(ids), |o| -> i64 { o.user_id }, dl)?
build.select(String.from("users"), build.names(List["id"])).where_eq(String.from("active"), postgres.Bool(true)).limit(10).build()?
```

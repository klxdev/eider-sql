# The checker

`sql.check` reads a parsed statement (`sql.parse`) and the schema the migrations build (`sql.ddl`, `sql.schema`) and
answers, with no database: does every table and column exist, do the operand types fit, what is the type of each
parameter, and what are the name, type and nullability of each result column. It never traps on any input
(tests/hostile_test.ei), and refuses what it cannot analyze with `unsupported: <what>` and a position.

## What it reads

DDL (migrations): CREATE TABLE (columns, `NOT NULL`, `DEFAULT`, `PRIMARY KEY`, `UNIQUE`, `REFERENCES`, `CHECK` skipped,
identity and generated columns, serial types), ALTER TABLE (ADD/DROP COLUMN, ALTER COLUMN SET/DROP NOT NULL,
TYPE, DEFAULT, ADD/DROP CONSTRAINT, RENAME), DROP TABLE, CREATE/DROP INDEX (plain column items must exist),
CREATE/ALTER/DROP TYPE for enums. Skipped without a word: INSERT/UPDATE/DELETE, GRANT, COMMENT, SET, CREATE EXTENSION,
functions, triggers. Skipped with a note (`Schema.notes`, shown in the error of a query that needs the object):
views, `CREATE TABLE ... AS`, `LIKE`, partitions.

Queries: SELECT with `*`, `t.*`, aliases, joins (inner, left, right, full, cross, comma, USING), WHERE, GROUP BY,
HAVING, ORDER BY (names, ordinals, aliases), LIMIT, OFFSET, DISTINCT, FOR UPDATE; INSERT ... VALUES (several
rows, DEFAULT, ON CONFLICT DO NOTHING / DO UPDATE with `excluded`, RETURNING); UPDATE ... SET ... WHERE
RETURNING; DELETE ... WHERE RETURNING. Expressions: literals, parameters (`$n`, or `:name` in query files),
casts (`::` and CAST), arithmetic, comparison, AND/OR/NOT, IS [NOT] NULL/TRUE/FALSE/DISTINCT FROM, IN, BETWEEN, LIKE,
ILIKE, SIMILAR TO, regular expression operators, `= ANY(...)`, CASE, ARRAY[...], subscripts, JSON operators,
`AT TIME ZONE`, typed literals (`date '...'`, `interval '...'`), EXTRACT, and about 100 functions (aggregates, text,
numeric, date/time, JSON, array functions; see `functions()` in check.ei).

Parameters get their type from the column they are compared with or assigned to, the other operand, a cast
(`$1::int8`), or the function argument they fill. A parameter whose type cannot be known is an error asking for a cast
(PostgreSQL would call it text). A parameter assigned to a nullable column is nullable (`Option[T]` in generated code).

## What it refuses as unsupported

WITH, UNION/INTERSECT/EXCEPT, subqueries (select list, FROM, IN, ANY, EXISTS), INSERT ... SELECT, UPDATE ... FROM,
DELETE ... USING, window functions (OVER), FILTER, WITHIN GROUP, NATURAL JOIN, LATERAL, DISTINCT ON, FETCH FIRST,
row values, array slices, set-returning functions (unnest, generate_series, ...), the keyword forms of SUBSTRING
and TRIM, unknown functions and operators, columns of types it does not model (the type is kept, the error says so).

## Stricter than PostgreSQL, on purpose

A parameter with no inferable type; a NOT NULL column without a default that an INSERT does not give (PostgreSQL finds
that out when the statement runs); a `NULL` literal for a NOT NULL column.

## Against the server

`tests/pg_corpus_test.ei` runs a corpus (tests/data/corpus: 110 valid queries, 31 invalid ones, 20 valid ones outside the
subset, 4 that are stricter) through the checker and through PostgreSQL's Parse/Describe on the same schema and compares
them. Result with PostgreSQL 17:

| | |
|---|---|
| queries | 165 |
| accepted by both | 109 |
| refused by both | 32 |
| valid for the server but `unsupported` by the checker | 20 (all of tests/data/corpus/unsupported.sql) |
| refused on purpose (stricter) | 4 |
| accepted by the checker, refused by the server | 0 |
| refused by the checker, accepted by the server (not by design) | 0 |
| parameter types that agree | 91 of 91 |
| result column names that agree | 276 of 276 |
| result column types that agree | 276 of 276 |
| nullability: checker says NOT NULL, the table column allows NULL | 0 of 137 columns that are table columns |

The server's RowDescription says nothing about nullability, so it is compared on the 137 result columns that are table
columns, through `pg_attribute.attnotnull`: the checker is never less cautious (it is more cautious on 6, the outer-join
sides). Nullability of expressions (`coalesce`, `CASE`, aggregates, operators) is inferred by the rules in check.ei and
tested by the golden output of check_test.ei, not by the server.

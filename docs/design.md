# eider-sql: design

Status: first version for Eider 0.7.4 (eider-lang issue 104, from docs/research/metaprogramming-data.md,
"Ranked proposed features" 8, 9 and 12). This document says what the language can do **today** for each part of the
proposal, so that what the package promises is what it does. Where a part needs a language feature that does not
exist, it says `needs: <feature>` with the precise description, and the package delivers the part the language allows.
Everything marked "built" is tested (scripts/test.sh).

## What the language has today (Eider 0.7.3)

| Feature | State | Consequence for eider-sql |
|---|---|---|
| `comptime embed("path")` | **Exists** (docs/site/reference/comptime.md): inside a `comptime` constant, replaced by the text of a file inside the declaring package, as a string literal. The path is a literal (no glob, no directory), the file is UTF-8 text, no capability. | Migrations and `.sql` files can be read while compiling. |
| `comptime` evaluation | **Exists**: any capability-free Eider runs in the compiler's IR interpreter. A constant's value is an integer, a `bool` or a `str` (E0807 otherwise); a trap is a compile error (E0807) that prints the trap's message. | The whole checker runs at compile time. Its result can be a number, and its failure a trap with a good message: **a compile error**. Measured: the sample project (2 migrations, 11 queries) checks in 0.6 s including compiling the program. |
| Comptime reflection (`fields(T)`, `attr[A](f)`, `comptime for`) and `@[derive(Trait)]` of traits with reflective default methods | **Exists** (reflection.md, traits.md). Read-only: reflection reads types, it does not create them. | Rows are read into records by `postgres.typed` (`serial.Deserialize`, derived). |
| Declared attributes (`pub attr serial { ... }`) | **Exists** | Generated rows use `@[serial(name = "type")]` for columns named like keywords. |
| Creating items (types, functions) from a `comptime` computation | **Does not exist**; no macro system is proposed. | A query file cannot, by itself, *become* a typed function or a record type. See "needs" below. |
| A build step before compilation | **Does not exist** | Code generation is a command, `eider-sql gen` (the sqlc design). |
| `String` to `str` | **Does not exist** | A `comptime` constant of text cannot be computed (only returned from literals), so a checked signature cannot be exported as a `str`; eider-postgres's `parse_url(str)` cannot take a URL read at run time (`sql.dburl` does it). |

## The proposal, part by part

### (a) Queries in `.sql` files, checked at compile time against the migration DDL, no database

Two halves, because the language gives one and not the other.

1. **Checking at compile time: built (`sql.compiletime`).** Because `embed` and the interpreter exist:

   ```eider
   import sql.compiletime as sqlc

   const CHECKED: i32 = comptime sqlc.check_all(
       List[embed("migrations/001_users.sql"), embed("migrations/002_orders.sql")],
       List[embed("queries/users.sql")])

   const SIG: bool = comptime sqlc.expect_signature(<same lists>, "FindByEmail",
       "params: $1 text; columns: id int8; email text; name text?;")
   ```

   `check_all` parses the DDL in order, parses and checks every query of the files, and **traps with every problem**
   (`queries #1:5:12: column "emial" does not exist; did you mean "email"? (in Typo)`): the build fails with that
   text (E0807), no database involved (tests/fail/bad_query.ei). `expect_signature` pins the inferred types of one
   query in the source, so a migration that changes them breaks the build until the code is updated (a `str` result
   cannot be exported, see the table, so it is a comparison). The limits are the language's: every migration is named in
   the list (`needs: embed of a directory`), and a constant cannot hold the parsed schema, so each constant re-parses it
   (`needs: structured comptime values`).

2. **Typed functions from the checked queries: built as generation (`eider-sql gen`).** The generator runs the same
   checker and writes an Eider module: a record per result row (`GetUserRow`, `@[derive(Deserialize)]`), a constant
   with the SQL, and a function per query with typed parameters (`Option[T]` where NULL is allowed) calling
   `postgres.typed.query_one | query_opt | query | exec`. The module is committed (or generated in CI) and compiled
   like any other; `eider-sql check --out` says when it is stale (the header carries a hash of the inputs). This is sqlc's
   design and needs no language feature. tests/data/gen is the golden output, compiled and run by tests/pg_gen_test.ei.

3. **Not possible today:**
   - `needs: comptime item generation`: a `comptime` computation usable at item level whose result is a set of
     declarations (a record type with given fields; a function with a given signature whose body is built from
     reflective pieces) that the compiler then checks as if written in the file. With it, `embed("queries/users.sql")`
     could produce `get_user` directly and `gen` would be unnecessary. Reflection is read-only by design
     (reflection.md, "Cost and limits") and no macro system is proposed, so this is a language proposal, not a small
     addition.
   - `needs: structured comptime values`: a record or list as the type of a `comptime` constant (today integers,
     `bool`, `str`; E0807), so that the parsed schema is computed once and shared by all constants.
   - `needs: embed of a directory` (`embed_dir("migrations")`: the names and texts of the files in lexical order):
     without it a new migration file must also be added to the constant's list. (The runner at run time can read a
     directory, so a mismatch between files and list is found by `eider-sql check`, not by the compiler.)
   - `needs: String to str` (a runtime text as a `str`): for eider-postgres's `parse_url`, `config` and for any
     `comptime` constant that computes text.

Nullability follows sqlc: a column is `Option[T]` when it is not `NOT NULL` (and not a primary key), or comes from
the nullable side of an outer join, or is an expression that can be NULL.

### (b) The checker

`sql.lex`, `sql.ddl`, `sql.parse`, `sql.check` are plain Eider with no capability, so the same code runs in the
generator, in tests and in `comptime`. They never trap on any input (tests/hostile_test.ei: every prefix of valid
statements, random edits, token soup, 3000 nested parentheses, 5000-term sums, odd bytes); depth and expression
height are bounded so nothing overflows the stack. Unsupported constructs are `unsupported: <what>` with a position,
never a guess. The subset, the rules for parameter types, the numbers against the server: docs/checker.md.

### (c) Migrations (built, `sql.migrate`, `sql.migration`)

Forward-only. A migration is `<version>_<name>.sql` (version a positive integer; 1 and 001 are the same) or an
embedded `(version, name, text)`. The runner sorts by version and rejects duplicates; takes `pg_advisory_lock` on a key
derived from the history table name for the whole run (so concurrent runners serialize and the later ones find nothing
to do: tests/pg_migrate_test.ei races six); creates `eider_migrations` (version, name, checksum, applied_at); refuses to
run when an applied migration's checksum no longer matches (edited after being applied; CRLF is normalized), an
applied version is missing from the list, a name differs, or a pending version is below an applied one; applies each
pending migration in its own transaction together with its history row (a failing migration leaves nothing behind); and
offers `plan` (dry run: nothing executed, the history table not even created) and `status`. A migration whose first
line is `-- eider-sql: no-transaction` runs outside a transaction. The checksum is FNV-1a 64 plus the length: it detects
an edit, it is not a cryptographic hash.

### (d) Pool and transactions (built, `sql.tx`, `sql.load`)

The pool is eider-postgres's (`postgres.pool`); eider-sql does not duplicate it. `tx.run` is `client.transaction`
(commit on Ok, roll back on Err or trap); `tx.run_isolated` sets the isolation level (and read-only) as the first
statement; `tx.retry` re-runs the transaction on `40001` and `40P01`, up to a count, with a growing pause;
`tx.with_pool` takes a pooled connection first. `load.load_many` runs one query with `= ANY($1)` for a whole key list
(in chunks) and `load.load_many_by` groups the rows by key: no N+1.

### (e) Typed builder for dynamic SQL (built, `sql.build`)

`select`, `insert_into` (batch), `update`, `delete_from`, with `where_eq | where_cmp | where_in | where_null`, `order_by`,
`order_by_allowed`, `limit`, `offset`, `returning`, ending in `build()` (`sql` and `params`). Values are always bound
(`$n`); identifiers are validated (letters, digits, `_`) and quoted; operators and directions are enum values; the sort
column comes from a list the program wrote; `with_schema` checks tables and columns against the migrations' schema; an
UPDATE or DELETE without a condition is refused unless `all_rows()`. No relations, no entity state.

## Decisions

- **Same code at three times**: the checker is one library used by `eider-sql`, by a user's `comptime` constant, and by
  tests. Nothing in it may use a capability.
- **Generation, not magic**: `gen` writes ordinary Eider that can be read, reviewed and diffed. Output is
  deterministic.
- **No guesses**: what the checker cannot analyze is `unsupported`, and the query can still be written by hand against
  `postgres.typed`. A wrong inference would be worse than none.
- **Validated against the server**: tests/pg_corpus_test.ei compares the inferred columns and parameter types with
  PostgreSQL's own Describe for a corpus of 165 queries (docs/checker.md has the numbers).
- **Stricter where it helps**: a parameter with no inferable type and an INSERT that omits a NOT NULL column without a
  default are errors at check time (PostgreSQL finds the second out at run time and accepts the first as text).

## Language notes from writing it

Things that cost time and that other libraries will meet (none needs filing for this package):

- `let x = place` makes `x` an alias of the place (so does `let mut j = i`), including for integers: a loop that
  writes `let start = i` and then changes `i` changes `start`. Write `.copy()` (the compiler catches the mutable case,
  E0307, and not the read-only one).
- A module cannot be called `comptime` (keyword); this one is `sql.compiletime`.
- A `str` and a `String` do not mix: `==`, `push_str` and every signature care; there is no conversion from `String`.
- Generic bodies need `Copy` bounds to use `.copy()` (E0605).
- A string literal's `{...}` cannot contain a quote: bind the value first.

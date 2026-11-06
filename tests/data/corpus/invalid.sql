-- name: X001_no_column :many
SELECT nope FROM users;

-- name: X002_typo_column :many
SELECT emial FROM users;

-- name: X003_no_table :many
SELECT id FROM usrs;

-- name: X004_ambiguous :many
SELECT id FROM users, orders;

-- name: X005_bad_qualifier :many
SELECT x.id FROM users;

-- name: X006_int_vs_text :many
SELECT id FROM users WHERE age = email;

-- name: X007_text_vs_int_literal :many
SELECT id FROM users WHERE email = 5;

-- name: X008_where_not_bool :many
SELECT id FROM users WHERE name;

-- name: X009_conflicting_param :many
SELECT id FROM users WHERE id = $1 AND email = $1;

-- name: X012_gap_param :many
SELECT id FROM users WHERE id = $2;

-- name: X014_insert_bad_column :exec
INSERT INTO users (email, nope) VALUES ($1, $2);

-- name: X015_insert_arity :exec
INSERT INTO users (email, name) VALUES ($1);

-- name: X017_insert_type :exec
INSERT INTO users (email, age) VALUES ('a', 'x'::text);

-- name: X018_update_bad_column :exec
UPDATE users SET nope = 1;

-- name: X019_update_type :exec
UPDATE users SET age = email;

-- name: X020_func_arg_type :many
SELECT lower(age) FROM users;

-- name: X021_bad_cast :many
SELECT born::int FROM users;

-- name: X022_unknown_function :many
SELECT nosuchfn(id) FROM users;

-- name: X023_string_minus_text :many
SELECT email - name FROM users;

-- name: X024_limit_text :many
SELECT id FROM users LIMIT email;

-- name: X025_order_ordinal_range :many
SELECT id FROM users ORDER BY 5;

-- name: X026_using_missing :many
SELECT * FROM users u JOIN orders o USING (email);

-- name: X027_duplicate_alias :many
SELECT 1 FROM users u, orders u;

-- name: X028_delete_bad_column :exec
DELETE FROM users WHERE nope = 1;

-- name: X029_sum_text :many
SELECT sum(email) FROM users;

-- name: X030_syntax :many
SELECT FROM WHERE;

-- name: X031_missing_from_table_column :many
SELECT o.nope FROM orders o;

-- name: X032_unknown_type_cast :many
SELECT 1::nosuchtype;

-- name: X033_json_eq :many
SELECT id FROM users WHERE raw = raw;

-- name: X034_bool_plus :many
SELECT active + 1 FROM users;

-- name: X035_array_vs_scalar :many
SELECT id FROM users WHERE tags = email;

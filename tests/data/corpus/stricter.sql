-- name: X010_unresolved_param :many
SELECT $1;

-- name: X011_two_unknowns :many
SELECT id FROM users WHERE $1 = $2;

-- name: X013_insert_missing_notnull :exec
INSERT INTO users (name) VALUES ($1);

-- name: X016_insert_null_notnull :exec
INSERT INTO users (email) VALUES (NULL);

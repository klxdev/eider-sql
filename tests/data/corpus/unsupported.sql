-- name: U001_cte :many
WITH x AS (SELECT 1 AS a) SELECT a FROM x;

-- name: U002_union :many
SELECT id FROM users UNION SELECT user_id FROM orders;

-- name: U003_scalar_subquery :many
SELECT id, (SELECT count(*) FROM orders) AS n FROM users;

-- name: U004_in_subquery :many
SELECT id FROM users WHERE id IN (SELECT user_id FROM orders);

-- name: U005_exists :many
SELECT id FROM users u WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- name: U006_from_subquery :many
SELECT t.id FROM (SELECT id FROM users) t;

-- name: U007_window :many
SELECT id, row_number() OVER (ORDER BY id) AS rn FROM users;

-- name: U008_unnest :many
SELECT unnest(tags) AS t FROM users;

-- name: U009_insert_select :exec
INSERT INTO tags (label) SELECT email FROM users;

-- name: U010_natural :many
SELECT * FROM orders NATURAL JOIN items;

-- name: U011_distinct_on :many
SELECT DISTINCT ON (user_id) user_id, id FROM orders ORDER BY user_id, id;

-- name: U012_generate_series :many
SELECT generate_series(1, 3) AS n;

-- name: U013_lateral :many
SELECT u.id FROM users u, LATERAL (SELECT 1) t;

-- name: U014_update_from :exec
UPDATE orders o SET note = u.email FROM users u WHERE u.id = o.user_id;

-- name: U015_delete_using :exec
DELETE FROM orders o USING users u WHERE u.id = o.user_id;

-- name: U016_filter :many
SELECT count(*) FILTER (WHERE active) AS n FROM users;

-- name: U017_row_value :many
SELECT id FROM users WHERE (id, age) = ($1, $2);

-- name: U018_json_array_elements :many
SELECT jsonb_array_elements(meta) AS e FROM users;

-- name: U019_substring_keyword_form :many
SELECT substring(email from 2 for 3) AS s FROM users;

-- name: U020_fetch_first :many
SELECT id FROM users FETCH FIRST 3 ROWS ONLY;

-- name: Q001_all_columns :many
SELECT * FROM users;

-- name: Q002_by_id :many
SELECT id, email, name FROM users WHERE id = $1;

-- name: Q003_two_params :many
SELECT id FROM users WHERE email = $1 AND age > $2;

-- name: Q004_alias :many
SELECT id AS user_id, email AS mail FROM users u WHERE u.id = $1;

-- name: Q005_qualified_star :many
SELECT u.*, o.id AS order_id FROM users u JOIN orders o ON o.user_id = u.id;

-- name: Q006_left_join :many
SELECT u.id, o.id AS oid, o.total, o.note FROM users u LEFT JOIN orders o ON o.user_id = u.id;

-- name: Q007_right_join :many
SELECT u.id, o.id AS oid FROM orders o RIGHT JOIN users u ON o.user_id = u.id;

-- name: Q008_full_join :many
SELECT u.id AS uid, o.id AS oid FROM users u FULL JOIN orders o ON o.user_id = u.id;

-- name: Q009_cross_join :many
SELECT u.id AS a, t.id AS b FROM users u CROSS JOIN tags t;

-- name: Q010_comma_join :many
SELECT u.id AS a, o.id AS b FROM users u, orders o WHERE o.user_id = u.id;

-- name: Q011_three_way :many
SELECT u.email, o.total, i.sku FROM users u JOIN orders o ON o.user_id = u.id JOIN items i ON i.order_id = o.id;

-- name: Q012_self_join :many
SELECT c.label, p.label AS parent_label FROM tags c LEFT JOIN tags p ON p.id = c.parent_id;

-- name: Q013_using :many
SELECT o.id, i.sku FROM orders o JOIN items i USING (order_id) ;

-- name: Q014_count_star :many
SELECT count(*) FROM users;

-- name: Q015_count_col :many
SELECT count(name) AS n, count(DISTINCT email) AS e FROM users;

-- name: Q016_sum_int :many
SELECT sum(age) AS a, sum(short) AS s, sum(score) AS f, sum(balance) AS n, sum(ratio) AS r FROM users;

-- name: Q017_avg :many
SELECT avg(age) AS a, avg(score) AS f, avg(balance) AS n FROM users;

-- name: Q018_min_max :many
SELECT min(email) AS a, max(created_at) AS b, min(born) AS c, max(age) AS d FROM users;

-- name: Q019_group_by :many
SELECT user_id, count(*) AS n, sum(total) AS t FROM orders GROUP BY user_id;

-- name: Q020_having :many
SELECT user_id, count(*) AS n FROM orders GROUP BY user_id HAVING count(*) > $1;

-- name: Q021_order_limit_offset :many
SELECT id, email FROM users ORDER BY created_at DESC, id LIMIT $1 OFFSET $2;

-- name: Q022_order_ordinal :many
SELECT email, age FROM users ORDER BY 2 DESC, 1;

-- name: Q023_distinct :many
SELECT DISTINCT user_id FROM orders;

-- name: Q024_where_null :many
SELECT id FROM users WHERE name IS NULL OR born IS NOT NULL;

-- name: Q025_in_list :many
SELECT id FROM users WHERE id IN (1, 2, 3) AND age NOT IN ($1, $2);

-- name: Q026_any_array :many
SELECT id, email FROM users WHERE id = ANY($1);

-- name: Q027_any_text :many
SELECT id FROM users WHERE email = ANY($1) AND mood <> ALL($2);

-- name: Q028_between :many
SELECT id FROM users WHERE created_at BETWEEN $1 AND $2 AND age NOT BETWEEN 1 AND $3;

-- name: Q029_like :many
SELECT id FROM users WHERE email LIKE $1 OR name ILIKE $2 OR email NOT LIKE '%x';

-- name: Q030_regex :many
SELECT id FROM users WHERE email ~ $1 AND name !~* $2;

-- name: Q031_case :many
SELECT CASE WHEN age > 18 THEN 'adult' ELSE 'minor' END AS kind, CASE WHEN score > 1 THEN score END AS s FROM users;

-- name: Q032_case_operand :many
SELECT CASE mood WHEN 'sad' THEN 1 WHEN 'ok' THEN 2 ELSE 3 END AS m FROM users;

-- name: Q033_coalesce :many
SELECT coalesce(name, 'anon') AS who, coalesce(score, 0) AS sc, coalesce(born, current_date) AS b FROM users;

-- name: Q034_nullif :many
SELECT nullif(age, 0) AS a, nullif(email, '') AS e FROM users;

-- name: Q035_greatest_least :many
SELECT greatest(age, 3) AS g, least(score, 2.5) AS l FROM users;

-- name: Q036_casts :many
SELECT id::text AS t, age::int8 AS i, score::numeric AS n, $1::int4 AS p, email::varchar AS v FROM users;

-- name: Q037_cast_names :many
SELECT age::bigint, id::int, score::float4, balance::text FROM users;

-- name: Q038_arith_int :many
SELECT age + 1 AS a, age * 2 AS b, age - short AS c, id / 2 AS d, age % 3 AS e FROM users;

-- name: Q039_arith_mixed :many
SELECT age * 2.5 AS a, score + age AS b, balance * 2 AS c, ratio + 1 AS d, short + id AS e FROM users;

-- name: Q040_arith_param :many
SELECT age + $1 AS a FROM users WHERE id * $2 > 5;

-- name: Q041_unary :many
SELECT -age AS a, +score AS b, NOT active AS c FROM users;

-- name: Q042_concat :many
SELECT email || '@' || name AS a, tags || ARRAY['x'] AS b, 'a' || age AS c FROM users;

-- name: Q043_string_functions :many
SELECT lower(email) AS a, upper(name) AS b, length(email) AS c, substr(email, 1, 3) AS d, replace(email, 'a', 'b') AS e, trim(name) AS f, left(email, 2) AS g, repeat('x', 3) AS h, md5(email) AS i FROM users;

-- name: Q044_math_functions :many
SELECT abs(age) AS a, round(score) AS b, round(balance, 1) AS c, ceil(score) AS d, floor(balance) AS e, mod(age, 3) AS f FROM users;

-- name: Q045_time_functions :many
SELECT now() AS a, current_date AS b, current_timestamp AS c, date_trunc('day', created_at) AS d, extract(year FROM born) AS e, date_part('month', created_at) AS f FROM users;

-- name: Q046_time_arith :many
SELECT created_at - interval '1 day' AS a, created_at - created_at AS b, born + 7 AS c, born - born AS d, local_at + interval '1 hour' AS e FROM users;

-- name: Q047_json :many
SELECT meta->'a' AS a, meta->>'b' AS b, meta @> $1::jsonb AS c, raw->'x' AS d FROM users;

-- name: Q048_arrays :many
SELECT tags, tags[1] AS first, array_length(tags, 1) AS n, cardinality(scores) AS c, scores FROM users;

-- name: Q049_array_agg :many
SELECT array_agg(email) AS emails, array_agg(id) AS ids, string_agg(email, ',') AS joined FROM users;

-- name: Q050_bool_aggs :many
SELECT bool_and(active) AS a, bool_or(active) AS b FROM users;

-- name: Q051_enum :many
SELECT mood, count(*) AS n FROM users WHERE mood = 'happy' GROUP BY mood;

-- name: Q052_enum_param :many
SELECT id FROM users WHERE mood = $1::mood;

-- name: Q053_uuid_bytea :many
SELECT uid, avatar, uid::text AS t FROM users WHERE uid = $1;

-- name: Q054_literals :many
SELECT 1 AS one, 'x' AS lit, 1.5 AS f, true AS b, NULL AS n, 10000000000 AS big;

-- name: Q055_no_from :many
SELECT 1 + 1 AS two, now() AS ts, 'a' || 'b' AS ab;

-- name: Q056_typed_literals :many
SELECT date '2020-01-01' AS d, interval '1 day' AS i, timestamp '2020-01-01 00:00:00' AS t;

-- name: Q057_numeric_funcs :many
SELECT sqrt(score) AS s, power(score, 2) AS p, sign(age) AS g FROM users;

-- name: Q058_text_agg_funcs :many
SELECT concat(email, name) AS c, concat_ws(',', email, name) AS w, split_part(email, '@', 2) AS p, strpos(email, '@') AS s FROM users;

-- name: Q059_to_char :many
SELECT to_char(created_at, 'YYYY') AS y, to_char(balance, '999') AS b FROM users;

-- name: Q060_jsonb_build :many
SELECT jsonb_build_object('a', age) AS o, to_jsonb(email) AS e, jsonb_typeof(meta) AS t FROM users;

-- name: Q061_is_bool :many
SELECT active IS TRUE AS a, age IS DISTINCT FROM $1 AS b, name IS NOT DISTINCT FROM email AS c FROM users;

-- name: Q062_exists_like_bool_ops :many
SELECT id FROM users WHERE (active AND age > 3) OR NOT (score < 1);

-- name: Q063_for_update :many
SELECT id FROM users WHERE id = $1 FOR UPDATE;

-- name: Q064_gen_uuid :many
SELECT gen_random_uuid() AS u, random() AS r;

-- name: Q065_limit_only :many
SELECT label FROM tags ORDER BY weight LIMIT 5;

-- name: Q066_composite_pk :many
SELECT order_id, line, price * 2 AS double FROM items WHERE order_id = $1 AND line = $2;

-- name: Q067_discount :many
SELECT price - discount AS net, price * (1 - discount) AS net2 FROM items;

-- name: Q068_alias_reuse_names :many
SELECT label, label AS again FROM tags;

-- name: Q069_ambiguous_ok :many
SELECT users.id, orders.user_id FROM users, orders;

-- name: Q070_ordering_by_alias :many
SELECT age + 1 AS next_age FROM users ORDER BY next_age;

-- name: Q071_insert_simple :exec
INSERT INTO users (email, name, age) VALUES ($1, $2, $3);

-- name: Q072_insert_returning :many
INSERT INTO users (email) VALUES ($1) RETURNING id, created_at, mood;

-- name: Q073_insert_multi :many
INSERT INTO tags (label, parent_id) VALUES ($1, $2), ($3, NULL) RETURNING *;

-- name: Q074_insert_default :many
INSERT INTO tags (label, weight) VALUES ('x', DEFAULT) RETURNING id, weight;

-- name: Q075_insert_conflict_nothing :exec
INSERT INTO users (email) VALUES ($1) ON CONFLICT (email) DO NOTHING;

-- name: Q076_insert_conflict_update :many
INSERT INTO users (email, name) VALUES ($1, $2) ON CONFLICT (email) DO UPDATE SET name = excluded.name, age = users.age + 1 RETURNING id, name;

-- name: Q077_insert_cast_values :exec
INSERT INTO orders (user_id, total, shipped_at) VALUES ($1, $2, $3);

-- name: Q078_insert_all_columns :exec
INSERT INTO items VALUES ($1, $2, $3, $4, $5);

-- name: Q079_insert_array_json :exec
INSERT INTO users (email, tags, scores, meta, uid, avatar) VALUES ($1, $2, $3, $4, $5, $6);

-- name: Q080_update_simple :exec
UPDATE users SET name = $1, score = $2 WHERE id = $3;

-- name: Q081_update_expr :many
UPDATE users SET age = age + 1, balance = balance * $1 WHERE email = $2 RETURNING age, balance;

-- name: Q082_update_alias :exec
UPDATE orders o SET note = NULL, shipped_at = now() WHERE o.id = $1;

-- name: Q083_update_returning_star :many
UPDATE tags SET weight = $1 WHERE id = $2 RETURNING *;

-- name: Q084_update_enum :exec
UPDATE users SET mood = $1 WHERE id = $2;

-- name: Q085_delete_simple :exec
DELETE FROM orders WHERE user_id = $1 AND total > $2;

-- name: Q086_delete_returning :many
DELETE FROM users WHERE id = $1 RETURNING id, email;

-- name: Q087_delete_all :exec
DELETE FROM tags;

-- name: Q088_delete_alias :exec
DELETE FROM tags t WHERE t.parent_id IS NULL;

-- name: Q089_select_param_in_func :many
SELECT lower($1::text) AS l, coalesce($2::int8, 0) AS c;

-- name: Q090_param_in_case :many
SELECT CASE WHEN age > $1 THEN 'a' ELSE 'b' END AS k FROM users;

-- name: Q091_params_arith_cmp :many
SELECT id FROM users WHERE age * 2 + $1 > score;

-- name: Q092_in_param :many
SELECT id FROM users WHERE id IN ($1, $2);

-- name: Q093_limit_param :many
SELECT id FROM users LIMIT $1;

-- name: Q094_between_params_date :many
SELECT id FROM users WHERE born BETWEEN $1 AND $2;

-- name: Q095_like_concat :many
SELECT id FROM users WHERE email LIKE '%' || $1 || '%';

-- name: Q096_interval_param :many
SELECT id FROM users WHERE created_at > now() - $1::interval;

-- name: Q097_time_param :many
SELECT id FROM users WHERE created_at > $1 AND local_at < $2 AND born >= $3;

-- name: Q098_json_param :many
SELECT id FROM users WHERE meta @> $1 OR meta ? $2;

-- name: Q099_array_param_cmp :many
SELECT id FROM users WHERE tags && $1 AND tags @> $2;

-- name: Q100_scalar_subscript :many
SELECT scores[1] AS a, scores[2] + 1 AS b FROM users;

-- name: Q101_bool_param :many
SELECT id FROM users WHERE active = $1;

-- name: Q102_float_param :many
SELECT id FROM users WHERE score > $1 AND ratio < $2;

-- name: Q103_numeric_param :many
SELECT id FROM users WHERE balance > $1;

-- name: Q104_bytea_param :many
SELECT id FROM users WHERE avatar = $1;

-- name: Q105_smallint_param :many
SELECT id FROM users WHERE short = $1;

-- name: Q106_text_array_agg_group :many
SELECT user_id, array_agg(id) AS order_ids FROM orders GROUP BY user_id;

-- name: Q107_count_distinct_group :many
SELECT user_id, count(DISTINCT qty) AS q FROM orders GROUP BY user_id ORDER BY user_id;

-- name: Q108_sum_group_join :many
SELECT u.id, sum(i.price) AS spent FROM users u JOIN orders o ON o.user_id = u.id JOIN items i ON i.order_id = o.id GROUP BY u.id;

-- name: Q109_left_join_coalesce :many
SELECT u.id, coalesce(sum(o.total), 0) AS spent FROM users u LEFT JOIN orders o ON o.user_id = u.id GROUP BY u.id;

-- name: Q110_cast_array :many
SELECT $1::int8[] AS ids, ARRAY[1, 2, 3] AS lits, ARRAY[email] AS emails FROM users;

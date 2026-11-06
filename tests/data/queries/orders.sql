-- name: OrdersOf :many
SELECT o.id, o.total, o.note, o.placed_on FROM orders o WHERE o.user_id = :user_id ORDER BY o.id;

-- name: OrdersByUsers :many
SELECT user_id, id, total FROM orders WHERE user_id = ANY(:user_ids) ORDER BY id;

-- name: AddOrder :one
INSERT INTO orders (user_id, total, note) VALUES (:user_id, :total, :note) RETURNING id;

-- name: UserTotals :many
SELECT u.id AS user_id, u.email, count(o.id) AS orders, sum(o.total) AS total
FROM users u LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.email
ORDER BY u.id;

-- name: Good :one
SELECT id, email FROM users WHERE id = :id;

-- name: Typo :one
SELECT id, emial FROM users WHERE id = :id;

-- name: WrongType :many
SELECT id FROM users WHERE email = :n AND id = 'x'::text;

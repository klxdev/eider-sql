-- name: GetUser :one
-- The user with this id; an error when there is none.
SELECT id, email, name, nickname, created_at FROM users WHERE id = :id;

-- name: FindByEmail :opt
SELECT id, email, name FROM users WHERE email = :email;

-- name: ListActive :many
SELECT id, email, age, score, tags FROM users WHERE active AND age >= :min_age ORDER BY id LIMIT :limit;

-- name: CreateUser :one
INSERT INTO users (email, name, age) VALUES (:email, :name, :age) RETURNING id, created_at;

-- name: RenameUser :exec
UPDATE users SET name = :name, nickname = :nickname WHERE id = :id;

-- name: UsersByIds :many
SELECT id, email FROM users WHERE id = ANY(:ids) ORDER BY id;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;

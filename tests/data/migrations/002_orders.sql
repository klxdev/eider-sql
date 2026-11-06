CREATE TABLE orders (
    id bigserial PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    total numeric(12, 2) NOT NULL,
    note text,
    placed_on date NOT NULL DEFAULT current_date
);
ALTER TABLE users ADD COLUMN nickname text;

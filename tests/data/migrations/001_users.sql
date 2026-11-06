CREATE TABLE users (
    id bigserial PRIMARY KEY,
    email text NOT NULL UNIQUE,
    name text,
    age integer NOT NULL DEFAULT 18,
    score double precision,
    active boolean NOT NULL DEFAULT true,
    tags text[] NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX users_created_at_idx ON users (created_at);

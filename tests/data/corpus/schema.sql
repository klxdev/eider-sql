DROP SCHEMA IF EXISTS corpus CASCADE;
CREATE SCHEMA corpus;
SET search_path TO corpus;

CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');

CREATE TABLE users (
    id bigserial PRIMARY KEY,
    email text NOT NULL UNIQUE,
    name varchar(100),
    nick character(8),
    age integer NOT NULL DEFAULT 18,
    short smallint,
    score double precision,
    ratio real,
    balance numeric(12, 2) NOT NULL DEFAULT 0,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    local_at timestamp,
    born date,
    at_time time,
    tags text[] NOT NULL DEFAULT '{}',
    scores integer[],
    meta jsonb,
    raw json,
    mood mood NOT NULL DEFAULT 'ok',
    uid uuid NOT NULL DEFAULT gen_random_uuid(),
    avatar bytea,
    span interval
);

CREATE TABLE orders (
    id bigserial PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    total numeric NOT NULL,
    note text,
    shipped_at timestamp,
    qty smallint NOT NULL DEFAULT 1,
    placed_on date NOT NULL DEFAULT current_date
);

CREATE TABLE items (
    order_id bigint NOT NULL REFERENCES orders (id),
    line integer NOT NULL,
    sku text NOT NULL,
    price numeric(10, 2) NOT NULL,
    discount real,
    PRIMARY KEY (order_id, line)
);

CREATE TABLE tags (
    id serial PRIMARY KEY,
    label text NOT NULL,
    parent_id integer REFERENCES tags (id)
);

ALTER TABLE tags ADD COLUMN weight double precision NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN nickname text;

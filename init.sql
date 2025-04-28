
DROP TABLE IF EXISTS items;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE items (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

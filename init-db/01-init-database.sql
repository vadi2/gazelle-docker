-- Initialize Gazelle XDStar-Client Database
-- This script runs automatically when PostgreSQL container starts for the first time

-- Ensure the database encoding is UTF-8
-- (already set via POSTGRES_ENCODING environment variable)

-- Create any additional schemas or extensions if needed
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant all privileges to gazelle user (already owner via POSTGRES_USER)
GRANT ALL PRIVILEGES ON DATABASE "xdstar-client" TO gazelle;

-- Log initialization
DO $$
BEGIN
    RAISE NOTICE 'Gazelle XDStar-Client database initialized successfully';
END
$$;

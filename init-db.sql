-- Database initialization script for Gazelle XDStarClient
-- This script is executed when the PostgreSQL container is first created

-- The database 'xdstar-client' and user 'gazelle' are already created by environment variables
-- This script can be used for additional initialization if needed

-- Grant all privileges to gazelle user
GRANT ALL PRIVILEGES ON DATABASE "xdstar-client" TO gazelle;

-- Create schema if needed (XDStarClient will create tables on first deployment)
\c xdstar-client;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO gazelle;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO gazelle;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO gazelle;

-- Log completion
SELECT 'Database initialization completed successfully' AS status;

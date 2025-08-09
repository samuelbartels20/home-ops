-- Create the Citus extension in the default database at first init
BEGIN;
CREATE EXTENSION IF NOT EXISTS citus;
COMMIT;
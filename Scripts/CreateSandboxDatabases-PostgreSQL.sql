/* =============================================================================
   Flyway sandbox: create the sandbox databases from your own database (PostgreSQL)

   First, make a dataless backup (structure only, no data) of your database:
     pg_dump -h <server> -p 5432 -U <login> --schema-only --no-owner --no-privileges -f backups/<name>_schema.sql <your database>

   Your AI assistant fills in the values below. Then run this in PowerShell in
   the project folder (psql asks for your password, and may ask again when it
   switches database):
     psql -h <server> -p 5432 -U <login> -d postgres -f Scripts/CreateSandboxDatabases-PostgreSQL.sql

   What it does:
     1. Creates <name>_dev and restores the dataless backup into it.
     2. Copies <name>_dev as <name>_test and <name>_prod, so all three start
        identical.
     3. Creates empty <name>_shadow, <name>_check and <name>_build for
        Flyway's own use.

   The backup file is only read. If any of these databases already exists, it
   stops before changing anything. It also stops at the first error.
   Needs an admin login (for example postgres) and psql 10 or later.
   ========================================================================== */

-- The name of your sandbox, lowercase (for example sales):
\set name '<name>'
-- The dataless backup to restore:
\set dump 'backups/' :name '_schema.sql'

\set ON_ERROR_STOP on
\set dev    :name '_dev'
\set test   :name '_test'
\set prod   :name '_prod'
\set shadow :name '_shadow'
\set check  :name '_check'
\set build  :name '_build'

SELECT :'name' LIKE '<%' AS unfilled \gset
\if :unfilled
  \echo 'Stopped: fill in the name at the top of this script first.'
  \quit
\endif

SELECT count(*) > 0 AS already FROM pg_database
 WHERE datname IN (:'dev', :'test', :'prod', :'shadow', :'check', :'build') \gset
\if :already
  \echo 'Stopped: one or more of the sandbox databases already exist. Nothing was changed.'
  \quit
\endif

\echo 'Restoring the dataless backup as' :dev '...'
CREATE DATABASE :"dev";
\c :dev
BEGIN;
\i :dump
COMMIT;

\echo 'Copying' :dev 'as' :test 'and' :prod '...'
\c postgres
CREATE DATABASE :"test" TEMPLATE :"dev";
CREATE DATABASE :"prod" TEMPLATE :"dev";

\echo 'Creating empty Shadow, Check and Build...'
CREATE DATABASE :"shadow";
CREATE DATABASE :"check";
CREATE DATABASE :"build";

\echo
\echo 'Done. Tell your AI assistant.'

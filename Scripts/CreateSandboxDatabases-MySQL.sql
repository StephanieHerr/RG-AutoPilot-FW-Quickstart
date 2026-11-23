/* =============================================================================
   Flyway sandbox: create the sandbox databases from your own database (MySQL)

   First, make a dataless backup (structure only, no data) of your database:
     mysqldump -h <server> -P 3306 -u <login> -p --no-data --routines --events --triggers --set-gtid-purged=OFF -r backups/<name>_schema.sql <your database>
   (MariaDB: leave out --set-gtid-purged=OFF.)

   Your AI assistant replaces every <name> below. Then run this in PowerShell
   in the project folder (mysql asks for your password):
     mysql -h <server> -P 3306 -u <login> -p -e "source Scripts/CreateSandboxDatabases-MySQL.sql"

   What it does:
     1. Creates <name>_dev, <name>_test, <name>_prod, <name>_shadow,
        <name>_check and <name>_build.
     2. Restores the dataless backup into <name>_dev, <name>_test and
        <name>_prod, so all three start identical. Shadow, Check and Build
        stay empty, for Flyway's own use.

   The backup file is only read. If one of these databases already exists,
   it stops there, so an existing database is never changed.
   Needs an admin login (for example root).
   ========================================================================== */

CREATE DATABASE <name>_dev;
CREATE DATABASE <name>_test;
CREATE DATABASE <name>_prod;
CREATE DATABASE <name>_shadow;
CREATE DATABASE <name>_check;
CREATE DATABASE <name>_build;

SELECT 'Restoring the dataless backup as <name>_dev, <name>_test and <name>_prod...' AS '';
USE <name>_dev;
source backups/<name>_schema.sql
USE <name>_test;
source backups/<name>_schema.sql
USE <name>_prod;
source backups/<name>_schema.sql

SELECT 'Done. Tell your AI assistant.' AS '';

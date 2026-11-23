# PostgreSQL and MySQL notes for the setup

Read this alongside `SKILL.md` when the user is on PostgreSQL or MySQL. The flow is the same, with two differences:
- They bring in their database as a **dataless backup**: a schema-only dump made with `pg_dump` or `mysqldump`, restored as Dev, Test and Prod.
- Backup as Baseline is SQL Server and Oracle only, so the **baseline is a script Flyway writes** from Dev (`B001…`). Shadow, Check and Build stay empty, and Flyway rebuilds them from the migrations whenever it needs to (`provisioner = "clean"`).

This is how Redgate's own Flyway AutoPilot projects for these platforms are built (https://github.com/red-gate/Flyway-AutoPilot-PG and https://github.com/red-gate/Flyway-AutoPilot-MySQL). The library in `Documentation/FlywayAIDump/` covers SQL Server only. Here, rely on these pages and say plainly when something isn't covered:
- PostgreSQL schema-only backup: https://documentation.red-gate.com/flyway/learn-more-about-flyway/schema-only-backups/postgresql-schema-only-backup
- Drivers and URLs: https://documentation.red-gate.com/fd/postgresql-database-277579325.html and https://documentation.red-gate.com/flyway/reference/database-driver-reference/mysql (MySQL and MariaDB)

Cloud versions, EnterpriseDB, YugabyteDB and TimescaleDB follow the PostgreSQL notes. MariaDB, Percona and SkySQL follow the MySQL notes. A managed cloud database is fine as the source; for the sandbox, a free local install is easiest.

## About your database (SKILL.md step 3)

- **Sandbox server**, instead of SKILL.md's question: "Which PostgreSQL (or MySQL) server should the sandbox databases go on? Pick one where you can create and drop databases. A free local install on your own machine is ideal; a dev/test server is fine too. Never production. What's its host name and port, and which login will you use?" Default ports: 5432 (PostgreSQL), 3306 (MySQL). An admin login (`postgres` or `root`) keeps the restore simple.
- **Your database:** the same four options, with a dump file in place of a `.bak`. Samples: Pagila's `pagila-schema.sql` is already a dataless backup for PostgreSQL. For MySQL, they install Sakila on the sandbox server with its own scripts, then use option 1.
- **Size:** in the question, use "thousands of objects, or references to other databases" as the examples.
- **Names:** lowercase with underscores, `<name>_dev`, `_test`, `_prod`, `_shadow`, `_check` and `_build`. PostgreSQL folds unquoted names to lowercase, and lowercase avoids case trouble on MySQL too.

## Create the sandbox databases (they run it; SKILL.md step 4)

They need the command-line tools on the machine they run them from: `pg_dump` and `psql` come with PostgreSQL, and `mysqldump` and `mysql` with MySQL. If PowerShell doesn't recognise one, ask them for the folder it's installed in (for example `C:\Program Files\PostgreSQL\17\bin`) and give the command with the full path, starting `& "…\psql.exe"`. Don't search the machine. The tools ask for the password; never put it in a command or a file.

Commands write to `backups/` in this folder, which is git-ignored. Use `-f` or `-r` for output files, never `>`: Windows PowerShell's `>` writes UTF-16, which the restore can't read.

1. **The dataless backup.** "No data" means the dump holds table definitions, views and code, but no rows.
   - PostgreSQL: `pg_dump -h <source host> -p <port> -U <login> --schema-only --no-owner --no-privileges -f backups/<name>_schema.sql <source database>`
   - MySQL: `mysqldump -h <source host> -P <port> -u <login> -p --no-data --routines --events --triggers --set-gtid-purged=OFF -r backups/<name>_schema.sql <source database>` (MariaDB: leave out `--set-gtid-purged=OFF`)
   - `--no-owner --no-privileges` leave out the source's logins and grants, which the sandbox server won't have.
   - **They already have a dump:** a schema-only `.sql` file goes straight into `backups/`. A PostgreSQL custom-format dump (`.dump`, `.backup`) becomes a dataless script with `pg_restore --schema-only --no-owner --no-privileges -f backups/<name>_schema.sql <file>`. A plain dump with data: they restore it on the sandbox server their usual way first, then use option 1.
2. **The script.** Fill in the values at the top of `Scripts/CreateSandboxDatabases-PostgreSQL.sql` or `Scripts/CreateSandboxDatabases-MySQL.sql` and tell them you did. Then ask them to run it in PowerShell in this folder:
   - PostgreSQL: `psql -h <host> -p <port> -U <login> -d postgres -f Scripts/CreateSandboxDatabases-PostgreSQL.sql` (it may ask for the password again when it switches database)
   - MySQL: `mysql -h <host> -P <port> -u <login> -p -e "source Scripts/CreateSandboxDatabases-MySQL.sql"`

   Explain in a few lines: it restores the dataless backup as Dev, Test and Prod, and creates empty Shadow, Check and Build. It only reads the dump. It stops at the first error, and never touches a database that already exists.

Ask them to say *done*, or paste the error. Simplest cause first:
- **Not recognised:** use the tool's full path.
- **Password or connection refused:** check the host, port and login.
- **Already exists:** a leftover from an earlier try, or a name clash. Pick another name, or they drop the leftover sandbox databases themselves; give them the `DROP DATABASE` lines and check the names with them first. The same applies after any failure partway through.
- **`must be owner of …` (PostgreSQL), or `Access denied; you need … SUPER` or a `DEFINER` error (MySQL):** run it as an admin login (`postgres` or `root`).
- **`could not open extension control file` (PostgreSQL):** the database uses an extension the sandbox server doesn't have, such as PostGIS. They install it there, or ask their SE.
- **`Unknown table 'COLUMN_STATISTICS'` (MySQL)** when dumping an older server with a newer `mysqldump`: add `--column-statistics=0`.

## Connect Flyway (SKILL.md step 5)

The shipped `flyway.toml` is for SQL Server. With the user's agreement, replace everything above the environments section with this. Keep the existing `id`, and drop the `[flyway.sqlserver…]` and `[redgateCompare.sqlserver…]` sections:
```toml
databaseType = "PostgreSql"   # MySQL: "MySql"
id = "<keep the existing id>"
name = "Flyway Setup Sandbox"

[flyway]
locations = [ "filesystem:migrations" ]
mixed = true
outOfOrder = false
schemaModelLocation = "schema-model"
validateMigrationNaming = true

  [flyway.check]
  rulesLocation = "Rules"
  rulesConfig = "sqlfluff.cfg"
  buildEnvironment = "Check"

[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"

  [flywayDesktop.generate]
  undoScripts = true

[redgateCompare]
filterFile = "filter.rgf"

# PostgreSQL only, as in Redgate's AutoPilot for PostgreSQL:
[redgateCompare.postgresql.options.ignores]
ignoreNewlinesInTextObjects = "all"
```

Then add the six environments. Shadow, Check and Build get `provisioner = "clean"` and no resolver block. Development, Test and Prod get no provisioner, ever.
- **PostgreSQL:** one database per environment, with the same schemas in each.
  ```toml
  [environments.development]
  url = "jdbc:postgresql://<host>:5432/<name>_dev"
  schemas = [ "public" ]
  ```
  For `schemas`, read the dump in `backups/`: list each schema it creates (`CREATE SCHEMA` lines), plus `public` if it has objects there. Flyway keeps its history table in the first one.
- **MySQL:** a schema is a database. So the URL names no database, and `schemas` names it, as in Redgate's AutoPilot for MySQL. The migrations Flyway writes don't name the schema, so the same script runs on each environment.
  ```toml
  [environments.development]
  url = "jdbc:mysql://<host>:3306"
  schemas = [ "<name>_dev" ]
  ```

Logins always go through Flyway Desktop: use the SQL login steps in `SKILL.md` step 5. Then run `flyway info -environment=development` to check the connection before going on. MySQL 8 sign-in errors:
- `RSA public key is not available client side` or `Public Key Retrieval is not allowed`: add `?allowPublicKeyRetrieval=true` to each MySQL URL (from Redgate's Flyway Docker page).
- On an older Flyway, a message that the URL isn't accepted: add `permitMysqlScheme=true` (from Redgate's MySQL driver page). Join two settings with `&`.

## Set the baseline (SKILL.md step 7)

Item 1 changes. Say: "Your platform doesn't support Backup as Baseline, so Flyway will write your starting point as a SQL script. It only reads Dev." Run the baseline command in "If a backup isn't possible" at the end of `SKILL.md`, then show the `B001…` file and summarise it.

Then prove Flyway can rebuild Dev from it. Say: "I'll have Flyway build the Shadow database from that script and compare it with Dev. It only changes Shadow." Run:
```powershell
flyway diff "-diff.source=development" "-diff.target=migrations" "-diff.buildEnvironment=shadow"
```
It should find no differences. If it lists some, show them; usually they're objects to leave out with a filter, or objects that depend on another database.

Item 2 (the user marks Test and Prod at 001) is unchanged.

## Differences in the later steps

- **Filters:** there's no `Filter.scpf`. To leave objects out, use Flyway Desktop's filter, which writes `filter.rgf`.
- **Code review (`-code`):** works as it is, because `sqlfluff.cfg` uses the generic `ansi` dialect. If it reports parsing errors on valid code, set `dialect = postgres` or `dialect = mysql` there.
- **Drift check (POC workflow):** the manual change is an `ALTER TABLE … ADD` run in psql or pgAdmin, or in mysql or MySQL Workbench.
- **Pipeline:** set the `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD` secrets, because these logins always have passwords. The check report empties Check (the clean provisioner), then runs the `B001` script and the migrations on it.

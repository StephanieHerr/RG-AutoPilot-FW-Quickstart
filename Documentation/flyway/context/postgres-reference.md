<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# PostgreSQL reference for Flyway

Setup guidance and gotchas. Version tags like "(11.7.2+)" are Flyway engine versions.

## Support status

| Platform | Foundational | Advanced (schema model, generate, prepare/deploy, check, snapshot) |
|---|---|---|
| PostgreSQL 12, 13, 14, 15, 16, 17, 18 | Supported | Supported |
| PostgreSQL 9.0 to 11 | Supported | No |
| Amazon RDS, Aurora PostgreSQL, Google Cloud, Azure Flexible Server, Azure Single Server | Supported (latest) | Supported |
| Aurora DSQL | Compatible | No |
| EnterpriseDB Advanced Server 16 (PostgreSQL driver) | Supported | Supported |
| EnterpriseDB Extended Server | Supported | Preview |
| YugabyteDB 2.7 / 2.4-2.6 | Supported | 2.7 only |
| CockroachDB 21.1 | Supported | No (standalone module for Java API users, 13.2+) |
| TimescaleDB 2.13-2.16 | Supported | Supported |
| Databricks Lakebase, Snowflake Postgres | Supported | Preview (see databricks-snowflake-reference.md) |
| Babelfish for Aurora PostgreSQL | Foundational (12.1+) | No |

The PostgreSQL driver page lists object types with "basic support" for `check`: aggregates, domains, enumerations, foreign keys, functions, indexes, materialized views, procedures, schemas, sequences, tables, triggers, views. Treat anything else (for example policies, publications) as needing a test before promising it (unverified beyond that list).

## Driver and URL

| Item | Value |
|---|---|
| Driver | `org.postgresql:postgresql` (pgjdbc), ships with the CLI, class `org.postgresql.Driver` |
| URL | `jdbc:postgresql://host:5432/database` |
| TLS | `?sslmode=require` (or `verify-full` with `sslrootcert` in `jdbcProperties`); `?ssl=true` also works |
| Auth | Username/password, SCRAM (transparent), pgpass (no `passfile`/`hostaddr` support) |
| Connection identity | `application_name` reported as Flyway (13.8+); Flyway sets `assumeMinServerVersion=9.1` (13.8+) |

```toml
[environments.prod]
url = "jdbc:postgresql://prod-pg01.corp.example:5432/billing"
user = "${env.PG_PROD_USER}"
password = "${env.PG_PROD_PASSWORD}"
schemas = ["billing"]
[environments.prod.jdbcProperties]
sslmode = "verify-full"
sslrootcert = "/etc/ssl/certs/corp-ca.pem"
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

## AWS Advanced JDBC Wrapper (RDS / Aurora)

| Item | Detail |
|---|---|
| Flyway support | PostgreSQL wrapper support added 11.7.2 (Issue 4033). MySQL wrapper support added 11.0 |
| Support level | The Aurora MySQL driver page says wrapper support "is a community addition and not maintained by Redgate". The Aurora PostgreSQL page does not mention the wrapper at all. Position as community-supported |
| URL | `jdbc:aws-wrapper:postgresql://cluster-endpoint:5432/db` (AWS wrapper convention; Flyway docs only show the MySQL form) |
| Driver class | `software.amazon.jdbc.Driver` (from the Aurora MySQL page) |
| Bundled? | Not stated. If `No suitable driver`, add the wrapper jar to the CLI `drivers/` folder (unverified) |
| Why customers want it | Faster failover handling and IAM authentication plugins on Aurora |

Plain pgjdbc against the cluster endpoint works and is the Redgate-supported path.

## PostgreSQL 15+ public schema privilege change

PostgreSQL 15 removed the default `CREATE` privilege on the `public` schema for all users (PUBLIC) and made `pg_database_owner` its owner. Consequences for Flyway:
- A deploy user that is not the database owner can no longer create objects (or the schema history table) in `public` on PG15+ unless granted.
- Recommended: manage your own schema (`schemas = ["billing"]`), owned by or granted to the deploy role:
```sql
CREATE SCHEMA billing AUTHORIZATION flyway_deployer;       -- or let Flyway create it
GRANT CREATE ON DATABASE billing TO flyway_deployer;       -- needed if Flyway creates schemas
```
- If you must use `public`: `GRANT CREATE ON SCHEMA public TO flyway_deployer;`
- Databases upgraded from older versions keep their old `public` privileges; new PG15+ databases do not. This is why "it works on the old server" is common.

## Parsing: functions, BEGIN ATOMIC, COPY

- Standard `;` delimiter. Dollar-quoted bodies (`$$`, `$_$`) as produced by `pg_dump` are handled; `pg_dump` DDL runs unchanged.
- SQL-standard function bodies (`BEGIN ATOMIC ... END`, PostgreSQL 14+) parse correctly (9.18+); `CASE` inside `BEGIN ATOMIC` fixed in 11.8.
- `COPY ... FROM STDIN` blocks (pg_dump format) supported.
- psql meta-commands with no JDBC equivalent (`\set`, `\connect`, `\i`) are not supported.

## CONCURRENTLY and other non-transactional statements

| Statement | Handling |
|---|---|
| `CREATE INDEX CONCURRENTLY`, `DROP INDEX CONCURRENTLY` | Flyway detects statements that cannot run in a transaction and runs that migration non-transactionally. Detection of other such statements (`VACUUM`, `CREATE DATABASE` and so on) is not itemised in the docs (unverified): test, or use the per-script override |
| Mixing with transactional statements in one script | Fails unless `mixed = true` (then the whole script runs without a transaction). Better: one non-transactional statement per migration |
| `CREATE INDEX CONCURRENTLY` locking | Default transactional advisory lock can deadlock/block it. Set `[flyway.postgresql] transactional.lock = false` to use session-level locks |
| Per-script override | `V7__idx.sql.conf` with `executeInTransaction=false` |

PostgreSQL supports transactional DDL, so a failed transactional migration rolls back completely. `group = true` (all pending migrations in one transaction) is realistic on PostgreSQL.

## Clean behaviour

| Object | Clean behaviour |
|---|---|
| Collations | Dropped (10.22+) |
| Extensions | Only those owned by the current user are dropped; superuser-installed ones are left (7.x). Objects created by extensions are not removed |
| Large objects in `pg_largeobject` | Not cleaned (Issue 1934) |
| Schemas | Dropped only if Flyway created them |

Create extensions with `CREATE EXTENSION IF NOT EXISTS` so clean-and-rebuild of build/shadow works repeatedly. Extensions usually need elevated rights (or trusted extensions on PG13+); pre-install them on shadow/build if the deploy role cannot.

## Comparison configuration (advanced)

| Setting | Notes |
|---|---|
| `[redgateCompare] filterFile = "filter.rgf"` | PostgreSQL/MySQL filter file; Desktop filter UI for PostgreSQL projects (Desktop 9.5.2+), multiple rules per type (9.5.4+), "All Objects" rule evaluated first (9.6.2+) |
| Property post-filters | Exclude by property name, e.g. `collation`, `owner`, `privileges` (examples in docs) |
| Partitions | RANGE partitions are ignored by default; include via a `postFilters` rule on `partitionInfo.partitionStrategy` |
| Tablespaces | TABLESPACE properties on tables/indexes/matviews supported (11.20+) but filtered out by default; enable with a `postFilters` include on property `tablespace`. Tablespace objects are not modelled; untested with non-`pg_default` defaults and on partitions |
| `[redgateCompare.postgresql.options.behavior] detectRenames` | Rename detection |
| `disableConstraintsForStaticData` (12.11+) | Wraps static data in `SET session_replication_role = 'replica'`; needs superuser and disables all triggers for the session |
| `[redgateCompare.postgresql.options.ignores] ignoreNewlinesInTextObjects` | Reduces false differences from line endings |

## Babelfish for Aurora PostgreSQL (12.1+)

- Connect with the **SQL Server** driver on port 1433: `jdbc:sqlserver://cluster-endpoint:1433;databaseName=master`. Flyway detects Babelfish via `SERVERPROPERTY('Babelfish')`.
- Console shows "SQL Server 2014 is outside of Redgate community support": expected, Babelfish reports an old version.
- Set `defaultSchema` to a non-`dbo` schema (Babelfish reserves `dbo`).
- T-SQL gaps hit in practice: no `CREATE OR ALTER VIEW` (use `DROP VIEW` + `GO` + `CREATE VIEW`), no Service Broker, no `CREATE ASSEMBLY`. `GO` required between batches.
- Foundational only: no schema model, generate, drift or change reports.

## Permissions

| Role | Needs |
|---|---|
| Deploy (`migrate`/`deploy`) | Ownership of, or `CREATE`/`USAGE` on, the managed schemas; rights for everything the scripts do; DML on the Flyway tables. `CREATE` on the database if Flyway creates schemas |
| Comparisons (Desktop, `check -changes`, `check -drift`, `snapshot`) | Read access to catalog metadata and `SELECT` on the Flyway history/snapshot tables. Docs link a PostgreSQL permissions page but give no role list (unverified detail) |
| Read-only drift user | Metadata read + `SELECT` on Flyway tables; keep it separate from the deploy role |
| Shadow / build | Full DDL, able to clean the schemas; superuser only if migrations need it (extensions, `session_replication_role`) |

## Gotchas

- **Build DB version drift:** build/shadow should run the same major version as production, or change reports show engine-default differences.
- **Owner differences:** different owners per environment produce noise; filter `owner` or standardise roles.
- **Search path:** Flyway's default schema is the first entry of `schemas`; unqualified names in scripts resolve through `search_path`. Qualify names in multi-schema projects.
- **Case:** unquoted identifiers fold to lower case; `schemas` entries are case-sensitive, so use lower-case names unless the schema was created quoted.
- **Aurora/RDS master user** is not a true superuser (`rds_superuser`): some extensions and `session_replication_role` may fail.
- **Azure Single Server** is listed but retired by Microsoft; steer to Flexible Server.
- **Exit codes (12.9+):** failures return a code derived from the Flyway error code, not always 1. Test for non-zero only.
- **JSON timestamps (13.2+)** include a UTC offset; update parsers.

## Sources
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/system-requirements/supported-databases-and-versions
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/postgresql-database
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/aurora-postgresql
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/aurora-mysql
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/babelfish
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/l4BUE (Migration transaction handling)
- https://documentation.red-gate.com/x/BIWLE (Mixed setting)
- https://documentation.red-gate.com/x/aoWLE (PostgreSQL transactional lock)
- https://documentation.red-gate.com/x/B4uLE (Connecting to environments)
- https://documentation.red-gate.com/x/eo0LCw (Update PostgreSQL or MySQL filters)
- https://documentation.red-gate.com/x/hpc8Ew (Tablespaces in PostgreSQL)
- https://documentation.red-gate.com/x/w4WLE (PostgreSQL behavior options)
- https://documentation.red-gate.com/x/Ug2iF (Disable constraints for static data)
- https://documentation.red-gate.com/x/xIWLE (PostgreSQL ignore options)
- https://documentation.red-gate.com/x/zAE-C (System requirements, permissions)
- https://documentation.red-gate.com/x/AwWoEw (Flyway Desktop 9 release notes)
- https://www.postgresql.org/docs/release/15.0/

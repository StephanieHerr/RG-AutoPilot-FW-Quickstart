<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# MySQL and MariaDB reference for Flyway

Setup guidance and gotchas. Version tags like "(10.7+)" are Flyway engine versions.

## Support status

| Platform | Foundational | Advanced (schema model, generate, prepare/deploy, check, snapshot) |
|---|---|---|
| MySQL 9.4, 8.3, 8.2, 8.1, 8.0, 5.7, 5.6 | Supported | Supported |
| Amazon RDS MySQL, Aurora MySQL, Azure MySQL, Google Cloud (latest) | Supported | Supported |
| Percona Server for MySQL 8 | Supported | Supported |
| Percona XtraDB Cluster 8 / 5.7 | Supported | 8 only |
| MariaDB 10.11 | Supported | Supported |
| MariaDB 10.10, 10.6, 10.5, 10.4, 10.3, 10.2, 10.1, 10, 5.5-5.1 | Supported | No |
| SkySQL, Amazon RDS for MariaDB (latest) | Supported | Supported |
| TiDB 5.0, SingleStoreDB | Supported | No |

MariaDB is advanced-capable only on 10.11 (and the managed "latest" services). Customers on MariaDB 10.6 or 11.x wanting state-based or drift: confirm with product before committing (11.x is not in the table; the driver page lists 12.3.2 as a verified version for foundational use).

## Drivers and fallback

| Item | MySQL Connector/J | MariaDB Connector/J |
|---|---|---|
| Ships with CLI | **No** (removed in 8.2 for licensing) | Yes (2.7.x line) |
| URL | `jdbc:mysql://host:3306/db` | `jdbc:mysql://...` or `jdbc:mariadb://host:3306/db` |
| Class | `com.mysql.jdbc.Driver` (per driver page) | `org.mariadb.jdbc.Driver` |

- No MySQL driver on the classpath: Flyway falls back to the MariaDB driver (fallback bug fixed 10.9.1).
- Since 10.7 the bundled MariaDB driver rejects `jdbc:mysql:` URLs unless you add `permitMysqlScheme=true`. Choose one:
  1. `jdbc:mysql://host:3306/db?permitMysqlScheme=true` (bundled MariaDB driver), or
  2. drop MySQL Connector/J into the CLI `drivers/` folder (for example `com.mysql:mysql-connector-j` from Maven Central; pin a tested version).
- Add `disableMariaDbDriver` to the URL to stop the fallback when you want Connector/J only.
- 10.8 downgraded the bundled MariaDB driver from 3.x back to 2.7.x to keep MySQL compatibility; do not replace it with MariaDB Connector/J 3.x unless you also use `permitMysqlScheme`.
- TLS: driver page shows `?useSsl=true`; the Connecting to environments page shows `useSSL=true&requireSSL=true`. Parameter names differ between drivers and Connector/J versions (Connector/J 8+ prefers `sslMode=REQUIRED`); check against the driver actually in use.

## AWS Advanced JDBC Wrapper (Aurora / RDS MySQL)

| Item | Detail |
|---|---|
| Flyway support | Added 11.0 |
| Support level | "a community addition and not maintained by Redgate" (Aurora MySQL driver page) |
| URL | `jdbc:aws-wrapper:mysql://instance.region.rds.amazonaws.com:3306/db?usePipelineAuth=false&useBatchMultiSend=false` |
| Class | `software.amazon.jdbc.Driver` |
| Aurora URL params | `usePipelineAuth=false&useBatchMultiSend=false` are shown for both plain and wrapper URLs (MariaDB Connector/J Aurora compatibility) |
| Driver page | Lists Connector/J 8.0.12+ and "Ships with Flyway Command-line: No", so expect to add jars to `drivers/` (unverified which jars) |

## DDL is non-transactional: effect on group and mixed

- MySQL/MariaDB commit implicitly before and after every DDL statement. A migration containing DDL cannot be rolled back.
- If a migration fails halfway, Flyway marks it **failed**; earlier statements stay applied. Clean up manually (or write idempotent scripts), then `flyway repair` to remove the failed row, then re-run.
- `group = true` gives no real protection for DDL; Flyway warns when `group` is enabled on databases without DDL transactions (10.18+).
- `mixed` only applies to PostgreSQL, Aurora PostgreSQL, SQL Server and SQLite (statements that cannot run in a transaction at all). It does not help on MySQL.
- Practical rule: one logical DDL change per migration, and pair DML data fixes in separate migrations so a failure leaves a known state.

## Schema history table storage engine

- Since 10.22 the history table is created with the server's **default storage engine** (previously forced to InnoDB).
- If `default_storage_engine` is not InnoDB (for example MyISAM on a legacy server), the history table will not be InnoDB. Galera, Group Replication and many managed services require InnoDB: check `default_storage_engine` before first deploy, or pre-create the table on InnoDB.
- MariaDB Galera: Flyway disables `GET_LOCK` when `wsrep_on=ON` (9.19+) so locking works on Galera clusters.
- Snapshot history table (Enterprise drift) is created on demand in the default schema; same engine consideration applies (inferred, unverified).

## Script syntax and DELIMITER

- `;` default delimiter. For routines/triggers with inner semicolons use `DELIMITER`:
```sql
DELIMITER //
CREATE PROCEDURE add_data()
BEGIN
  INSERT INTO test_data (value) VALUES ('Hello');
END //
DELIMITER ;
```
- `mysqldump` output runs unchanged, including `/*!40101 ... */` comment directives and `#` comments.
- Not supported: several comment directives on one line, e.g. `/*!50003 CREATE*/ /*!50017 DEFINER=...*/ /*!50003 TRIGGER ...` (Issue 558). Reformat dumps so each directive is on its own line or strip `DEFINER`.
- Backtick-quoted strings parse correctly (12.2+).

## Authentication

| Method | Edition | Notes |
|---|---|---|
| Username/password | All | `${env.VAR}` in TOML |
| MySQL option files | Teams+ | Reads only `user` and `password` from `my.cnf`/`my.ini`/`.mylogin.cnf` (search order per OS in docs); no `!include` support |
| AWS IAM | via AWS wrapper plugins | Community-supported path |

## Environments and shadow

- MySQL "schema" = database. Set `schemas = ["shop"]`; the first is the default schema and holds the history table.
- Single-schema shadow mode is supported for MySQL (and Oracle): shadow can be another schema on the dev server if scripts are not schema-qualified.
- Shadow/build options: a container (`docker run -d -e MYSQL_ROOT_PASSWORD=... -p 3307:3306 mysql`), a second instance on another port, or the Flyway `docker` provisioner (Preview, Enterprise; MySQL needs no EULA flag). The smart docker provisioner starts MySQL build containers with valid credentials and a usable default schema (12.10+).
- `check -changes` cleans the build environment. A bug where `check` could clean schemas unexpectedly on MySQL was fixed in 10.17: keep the build database dedicated regardless.

```toml
[environments.build]
provisioner = "docker"
schemas = ["shop"]
[environments.build.resolvers.docker]
databaseEngine = "mysql"
databaseEngineVersion = "8.4"
[environments.build.flyway]
cleanDisabled = false
outOfOrder = false
validateOnMigrate = true

[environments.prod]
url = "jdbc:mysql://prod-mysql01.corp.example:3306/shop?permitMysqlScheme=true&useSsl=true"
user = "${env.MYSQL_PROD_USER}"
password = "${env.MYSQL_PROD_PASSWORD}"
schemas = ["shop"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

## Comparisons (advanced)

- Filters: `[redgateCompare] filterFile = "filter.rgf"`; Desktop filter UI (Schema model > Configure comparison > Filters). Property post-filters work the same way as PostgreSQL (for example exclude `collation`).
- Desktop for MySQL/Aurora MySQL: object-level history, versioned and undo generation, check reports with Teams/Enterprise.

## Permissions

Flyway docs do not publish a MySQL privilege list (unverified detail); plan from what Flyway does:

| Activity | Typical privileges |
|---|---|
| Deploy | `CREATE`, `ALTER`, `DROP`, `INDEX`, `REFERENCES`, `CREATE VIEW`, `CREATE ROUTINE`, `ALTER ROUTINE`, `TRIGGER`, `EVENT` as the scripts need; `INSERT/UPDATE/DELETE/SELECT` on the Flyway tables; `CREATE` on the server if Flyway creates the schema |
| Routines with `DEFINER` other than the deploy user | MySQL 8 needs `SET_USER_ID` (deprecated in 8.2+ in favour of `SET_ANY_DEFINER`) or equivalent: MySQL rule, not Flyway. Stripping `DEFINER` avoids it |
| Comparisons / drift | Read access to `information_schema` for the managed schemas, `SHOW VIEW`, and `SELECT` on Flyway tables |
| Shadow / build | Full DDL on a dedicated schema/instance |

## Gotchas

- **Driver confusion** is the number one support issue: "No suitable driver" or MariaDB driver rejecting the URL. Fix with `permitMysqlScheme=true` or Connector/J in `drivers/`.
- **Failed migrations leave partial DDL.** Always check state before `repair` and re-run.
- **`lower_case_table_names`** differs between Windows/macOS and Linux servers; object name case then differs between dev and prod and shows up as differences. Align the setting across environments (MySQL behaviour).
- **`sql_mode` differences** between environments change how scripts behave (strict mode, zero dates). Keep them aligned.
- **Exit codes (12.9+):** derived from the Flyway error code, not always 1. Test for non-zero.
- **JSON timestamps (13.2+)** include a UTC offset.

## Sources
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/system-requirements/supported-databases-and-versions
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/mysql
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/mariadb
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/aurora-mysql
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/l4BUE (Migration transaction handling)
- https://documentation.red-gate.com/x/BIWLE (Mixed setting)
- https://documentation.red-gate.com/x/_YSLE (Group setting)
- https://documentation.red-gate.com/x/B4uLE (Connecting to environments)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/uoSLE (Docker provisioner)
- https://documentation.red-gate.com/x/eo0LCw (Update PostgreSQL or MySQL filters)
- https://documentation.red-gate.com/x/xogwCw (Flyway Desktop using MySQL and Aurora MySQL)
- https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/

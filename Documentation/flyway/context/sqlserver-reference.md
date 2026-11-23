<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# SQL Server (and Azure SQL, Fabric) reference for Flyway

Setup guidance and gotchas. Version tags like "(12.1+)" mean the Flyway engine version that introduced a behaviour.

## Support status

| Platform | Foundational (migrate, info, validate, repair, baseline, undo) | Advanced (schema model, generate, prepare/deploy, check changes/drift, snapshot) | Notes |
|---|---|---|---|
| SQL Server 2025, 2022, 2019, 2017, 2016 | Supported | Supported | 2025 added as latest (11.16) |
| SQL Server 2014, 2012, 2008 R2, 2008 | Supported | No | Migrations only |
| Azure SQL Database, Azure SQL Managed Instance, Amazon RDS for SQL Server | Supported (latest) | Supported | |
| SQL Server on Google Cloud 2017-2022 | Supported | Supported | |
| Fabric SQL Database | Supported | No | Foundational added 11.9.2. Driver page: "advanced capabilities ... will not currently work" |
| Fabric Data Warehouse | Supported (supported-databases page); driver page still says Status: Preview | No | 11.10.2 "available in Preview". The supported-databases page (checked 2026-10-26) lists Fabric SQL Database and Fabric Data Warehouse as Supported for foundational capabilities, and says Lakehouse, Eventhouse (KQL Database), Cosmos DB in Fabric and Mirrored Databases are not supported. The Fabric Data Warehouse driver page (updated 2026-10-21) still shows Status: Preview and foundational capabilities only, so confirm before committing |
| Babelfish for Aurora PostgreSQL | Foundational (12.1+) | No | Uses the SQL Server driver; see postgres-reference.md |

## Driver and URL

| Item | Value |
|---|---|
| Driver | Microsoft `mssql-jdbc`, ships with the CLI, class `com.microsoft.sqlserver.jdbc.SQLServerDriver` |
| URL | `jdbc:sqlserver://host:port;databaseName=db` |
| Named instance | `jdbc:sqlserver://server;instanceName=inst;databaseName=db`. If you also give `host:port`, the driver uses the port, not the instance name |
| LocalDB | MS driver does not support LocalDB named pipes. Use jTDS plus the Local DB resolver (instance pipe name changes on restart); jTDS does not accept `localhost` (use `.`) and Windows auth needs `ntlmauth.dll` |
| Java API | Redgate edition: `com.redgate.flyway:flyway-sqlserver` |

## Authentication options

| Method | Edition | URL / TOML | Best for | Notes |
|---|---|---|---|---|
| SQL authentication | All | `user = "${env.DB_USER}"`, `password = "${env.DB_PASSWORD}"` | Simple pipelines | Use a separate read-only login for drift checks |
| Windows integrated | All | `;integratedSecurity=true` | Windows agents on a domain | Uses the identity running Flyway: the agent service must run as a domain service account on a domain-joined machine |
| Kerberos (JavaKerberos) | Teams+ | `;authenticationScheme=JavaKerberos;integratedSecurity=true` plus `[flyway] kerberosConfigFile = "/etc/krb5.conf"` and `[flyway.sqlserver] kerberos.login.file = "/path/SQLJDBCDriver.conf"` | Linux agents against AD-joined SQL Server | Keytab, krb5.conf and KDC access needed on the agent; clock skew is a common failure. Desktop: settings only via TOML |
| Entra service principal | All | `;authentication=ActiveDirectoryServicePrincipal`, `user` = application (client) ID, `password = "${env.ENTRA_CLIENT_SECRET}"` | Pipelines | Docs recommend for pipelines. Client ID as `user` is per Microsoft JDBC docs |
| Entra managed identity | All | `;authentication=ActiveDirectoryMSI` (add `;msiClientId=<id>` for user-assigned) | Agents running on Azure | No secret at all; docs call it the most secure option |
| Entra interactive | All | `[environments.dev.jdbcProperties] accessToken = "${entraId.token}"` and `[environments.dev.resolvers.entraId] tenantId`, `clientId` | Flyway Desktop, local dev | Token cached; without the resolver you are prompted on every connection. Needs an app registration (redirect URIs `https://login.microsoftonline.com/common/oauth2/nativeclient` and `http://localhost`, delegated `user_impersonation` on Azure SQL Database). `entraId` alias for the older `azureAdInteractive` resolver (12.0.1+) |
| Entra access token | All | `[environments.x.jdbcProperties] accessToken = "${env.SQL_ACCESS_TOKEN}"` | Pipelines that already hold a token | e.g. `az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv` |

Database side for Entra principals:
```sql
CREATE USER [my-flyway-app] FROM EXTERNAL PROVIDER;
ALTER ROLE db_ddladmin ADD MEMBER [my-flyway-app];
```
The Azure SQL server must have an Entra admin assigned. Java API users must add MSAL4J / Azure Identity to the classpath (bundled with the CLI). Other Microsoft driver modes (for example `ActiveDirectoryDefault`) are driver features not covered in Flyway docs (unverified with Flyway).

**Example: service principal environment**
```toml
[environments.prod]
url = "jdbc:sqlserver://prod-sql.database.windows.net:1433;databaseName=SalesDb;encrypt=true;authentication=ActiveDirectoryServicePrincipal"
user = "${env.ENTRA_CLIENT_ID}"
password = "${env.ENTRA_CLIENT_SECRET}"
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

## Encryption and certificate noise

| Setting | Effect | Use |
|---|---|---|
| `encrypt=true` / `encrypt=mandatory` | TLS required; server certificate is validated | Production. Docs example uses `encrypt=mandatory` |
| `trustServerCertificate=true` | Skips certificate validation | Dev/shadow/build with self-signed certs only |
| `encrypt=false` | No TLS | Legacy only, not recommended |

- Newer Microsoft JDBC drivers encrypt by default, so connections that used to work unencrypted fail with "The driver could not establish a secure connection to SQL Server by using Secure Sockets Layer (SSL) encryption" when the server cert is self-signed or the name does not match. Fix properly with a CA-issued cert whose name matches the host in the URL. The quick fix (`trustServerCertificate=true` or the Desktop "trust server certificate" box) weakens security; do not ship it to production configs.
- Customer DBAs will ask: Flyway itself adds nothing here, it is the Microsoft driver's behaviour, so their existing JDBC/ODBC TLS guidance applies.

## PRINT statements and errorOverrides (Teams+)

- SQL Server `PRINT` output surfaces as warnings by default. Downgrade to info without SQL state noise:
```toml
[flyway]
errorOverrides = ["S0001:0:I-"]
```
- Format `STATE:CODE:BEHAVIOUR`; behaviours `D`, `I`, `W`, `E`, and the `-` suffix variants hide the original SQL state/code. `*` matches any state or code.
- New Desktop SQL Server projects include this override by default (11.10.1+). `deploy` honours errorOverrides (11.13+), so state-based deployments handle PRINT too.
- errorOverrides cannot be combined with `batch = true` (Flyway fails fast).
- Do not use errorOverrides to hide real errors in production; prefer fixing the script.

## GO batches and transactions

| Topic | Behaviour |
|---|---|
| Delimiter | `GO` on its own line. Scripts from SSMS/sqlcmd run unchanged (after placeholder replacement) |
| First-in-batch statements | `CREATE VIEW/PROCEDURE/FUNCTION/TRIGGER` must start a batch: put `GO` before them (SQL Server rule) |
| Transaction per migration | Each migration runs in its own transaction; `group = true` puts all pending migrations in one |
| Non-transactional statements | Flyway detects statements that cannot run in a transaction (for example some `ALTER DATABASE`) and runs that migration non-transactionally. Mixing both kinds in one script fails unless `mixed = true`, which runs the whole script without a transaction |
| Memory-optimized tables | Detection does NOT cover DDL on `MEMORY_OPTIMIZED = ON` tables: add a script config file `V5__inmem.sql.conf` with `executeInTransaction=false` |
| jTDS | `SET ANSI_NULLS` / `SET QUOTED_IDENTIFIER` in scripts error with jTDS; use the Microsoft driver |

## Schemas, schema history table and clean

- SQL Server cannot change a session's default schema, so `defaultSchema` only matters for placeholders and for where the history table goes; it must also be in `schemas`.
- History table goes in the connection's default schema unless `schemas`/`defaultSchema` say otherwise.
- For `diff`/`prepare`, `schemas` is ignored on SQL Server; Desktop says do not specify schemas for SQL Server connections.
- Clean modes (`[flyway.sqlserver.clean] mode`, TOML only): `default`; `schema` (all non-built-in schemas); `all` (everything including schemas, non-fixed roles, keys, fulltext stoplists, XML schema collections). `schemas.exclude` protects schemas. Error if `mode` is `schema`/`all` and `schemas` is set. Clean never drops users.
- `cleanDisabled` defaults to `true`. Enable only in `[environments.build.flyway]` / shadow.

## Dependency control (comparison engine)

| Setting | Default | Effect |
|---|---|---|
| `[redgateCompare.sqlserver.options.behavior] includeDependencies` | `true` | Pulls dependent objects into schema model saves, generated migrations and deployment scripts. Desktop shows a dependency review step; `false` disables it |
| `IgnoreSynonymDependencies` | removed (12.1) | Delete it from old configs |
| Filters | `[redgateCompare.sqlserver] filterFile = "Filter.scpf"` | Excludes objects from comparisons (also used by drift) |

## Drift, incorporate and revert scripts (Enterprise)

1. `migrate`/`deploy` with `saveSnapshot=true` embeds a snapshot in `flyway_snapshot_history` (default schema). Desktop 9.10+ saves a snapshot on deploy by default.
2. `flyway check -drift -environment=prod "-check.failOnDrift=true"` compares that snapshot to the live database. First run has no snapshot: warning, not failure. Drift raises `CHECK_DRIFT_DETECTED`.
3. Drift resolution scripts are written to `drift-resolution/` under the working directory (`check.driftResolutionFolder` to change, 12.9+; `check.generateDriftResolutionScripts` to control). Generation failures no longer fail the command (12.10+).
4. Options:
   - **Incorporate** (migrations): copy the generated incorporate migration (next version number) into `migrations/`. For SQL Server it is generated with object existence checks (11.20.1+), so it is idempotent out of the box. Apply to dev, update the schema model, commit. If not idempotent, mark applied in prod with `flyway migrate -environment=prod -cherryPick=1.3 -skipExecutingMigrations=true`.
   - **Revert**: run the generated revert script against the drifted target.
   - **Filter**: generated filter file (SQL Server and Oracle) to exclude drifted objects that belong to someone else.
   - **Re-snapshot**: `flyway snapshot -source=prod -filename="snapshotHistory:drift_correction"` (not recommended for prod).
5. State-based: a deploy reverts drift unless it is filtered out.

Snapshot storage on SQL Server is `VARBINARY(MAX)` (2 GB after compression). `snapshot.historyLimit` default changed to 5 in 12.1 (the Snapshots concept page still says 1).

## Required permissions

| Activity | Minimum | Recommended |
|---|---|---|
| `migrate` / `deploy` | Rights for whatever the scripts do, plus INSERT/UPDATE/DELETE on the history table and create rights for it on first run | `db_owner`, or `db_ddladmin` plus DML on Flyway tables |
| Comparisons: Desktop, `check -changes`, `check -drift`, `snapshot`, `prepare` | `VIEW DEFINITION` | `db_owner`; also `SELECT` on `sys.sql_expression_dependencies` (comparisons can be very slow without it) |
| Encrypted objects in comparisons | `sysadmin` | |
| Read-only drift credential | `VIEW DEFINITION` + `SELECT` on `flyway_schema_history` and `flyway_snapshot_history` | Separate login from the deploy login |
| Shadow / build | Full DDL and clean rights; with `mode = "all"` it drops roles and schemas | `db_owner` on a dedicated database |

Missing permissions silently hide objects (for example user-defined types in schemas you cannot see), which then look like drift or produce bad scripts.

## Pipeline exit code handling (12.9+)

Since 12.9 the CLI exits with a code derived from the Flyway error code, so it is not always 1. Check for non-zero, never for `1`. 35 = licensing.
```powershell
& flyway check -drift "-environment=prod" "-check.failOnDrift=true"
$code = $LASTEXITCODE
if ($code -ne 0) { throw "flyway check -drift failed (exit $code)" }
```
In Windows PowerShell 5.1, redirecting native stderr (`2>&1`) under `$ErrorActionPreference = 'Stop'` can throw before `$LASTEXITCODE` is read; either avoid the redirect or relax the preference around the call. Quote any argument containing a dot (`"-check.failOnDrift=true"`), because PowerShell can split it.

## Gotchas

- Build database is cleaned by `check -changes`; never share it between concurrent pipelines or point it at anything valuable.
- `failOnDrift` does not stop chained verbs (`flyway check -drift migrate`). Run drift as its own step.
- Cross-database references and linked servers must exist on shadow/build too, or migrations fail there. Placeholders help for linked server names.
- Filegroups/files used by tables must exist on shadow/build (or be created at the top of the baseline script).
- Flyway added `NOLOCK` to an internal SQL Server metadata query to reduce blocking (10.17.3). This does not change your scripts.
- `outOfOrder` defaults to `false`; if hotfix branches produce lower versions, decide per environment and document it.
- Existing databases with no history table: `baseline` (or `baselineOnMigrate` for one run). Docs warn baselineOnMigrate removes a safety net.
- 13.2 changed JSON timestamps to include a UTC offset: update any pipeline code that parses `-outputType=json` timestamps.

## Sources
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/system-requirements/supported-databases-and-versions
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/sql-server-database
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/fabric-database
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/fabric-data-warehouse
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/babelfish
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/B4uLE (Connecting to environments)
- https://documentation.red-gate.com/x/_QI8F (Tutorial: Connect using Microsoft Entra ID)
- https://documentation.red-gate.com/x/XgASEg (Microsoft Entra Interactive Resolver)
- https://documentation.red-gate.com/x/CwM8F (Tutorial: Connect using Kerberos authentication)
- https://documentation.red-gate.com/x/1YD7C (Could not establish a secure SQL Server connection using SSL encryption)
- https://documentation.red-gate.com/x/9ISLE (Error overrides setting)
- https://documentation.red-gate.com/x/l4BUE (Migration transaction handling)
- https://documentation.red-gate.com/x/eIWLE (SQL Server clean namespace)
- https://documentation.red-gate.com/x/loFlEw (SQL Server include dependencies setting)
- https://documentation.red-gate.com/x/lpGTEg (Checking production environments for drift)
- https://documentation.red-gate.com/x/LItlEw (Resolve drift by incorporating it, migrations)
- https://documentation.red-gate.com/x/l4SLE (Check drift)
- https://documentation.red-gate.com/x/3IBUE (Snapshots)
- https://documentation.red-gate.com/x/joSLE (Snapshot command)
- https://documentation.red-gate.com/x/zAE-C (System requirements, permissions)
- https://documentation.red-gate.com/x/45I8Ew (Permissions required to use SQL Compare)
- https://documentation.red-gate.com/x/AwWoEw (Flyway Desktop 9 release notes)
- https://learn.microsoft.com/en-us/sql/connect/jdbc/connecting-using-azure-active-directory-authentication
- https://documentation.red-gate.com/fd/supported-databases-and-versions-143754067.html (Fabric Data Warehouse status, checked 2026-10-26)

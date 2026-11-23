<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Oracle reference for Flyway

Setup guidance and gotchas. Version tags like "(12.0.1+)" are Flyway engine versions.

## Support status

| Platform | Foundational | Advanced (schema model, generate, prepare/deploy, check, snapshot) |
|---|---|---|
| Oracle 23ai, 21c, 19c | Supported | Supported |
| Oracle 18c or below | Compatible (limited testing, community support) | Compatible |
| Oracle Autonomous Database | Supported | Supported |
| RAC/Exadata 23ai | Supported | Supported (tested, but not on Exadata) |
| RAC/Exadata 19c or below | Compatible | Compatible |
| Amazon RDS for Oracle 21c, 19c | Supported | Supported |
| Oracle 26ai | Driver page lists 26ai as verified; supported-databases page says "Let us know if you're using Oracle 26ai" | Confirm before committing |

All editions including XE. JDBC URL: `jdbc:oracle:thin:@//host:port/service` or `jdbc:oracle:thin:@tns_entry` (with `TNS_ADMIN` pointing at the `tnsnames.ora` folder). Driver `ojdbc11` ships with the CLI.

### Oracle 11g end of support
Supported-databases page: Redgate is "dropping support for Oracle 11g in the next major release of our tools (Flyway Enterprise, Schema Compare for Oracle, Data Compare for Oracle, and Source Control for Oracle)", expected "at the end of 2026 or early 2027". Flyway Desktop shows an in-app warning (Desktop 9.10.0+). Flag this early with any customer still on 11g and agree an upgrade path before renewal.

## Native Connectors vs JDBC

| Aspect | JDBC mode (default) | Native Connectors (Preview on the driver page) |
|---|---|---|
| Executes migrations via | Flyway's Oracle parser + JDBC | Oracle SQLcl (`sql`); JDBC still used for schema history and some operations |
| Enable | Nothing | `FLYWAY_NATIVE_CONNECTORS=true` env var, SQLcl installed and on PATH. The 11.7 blog also required `oracle.sqlplus=true` (Teams+); current driver page does not mention it (unverified which is current) |
| Best for | Standard DDL/PLSQL, needs transaction handling | Large SQL*Plus-heavy scripts the parser rejects |
| SQL*Plus support | Flyway re-implementation of a documented command subset (`oracle.sqlplus`) | Real SQLcl behaviour |
| `&VAR` substitution | Populated from Flyway placeholders or `DEFINE` | Not populated from placeholders. Undefined variables make the tool **hang**: define every `&VAR` in the script |
| Placeholders | Everywhere, including `@`-referenced scripts | Not in scripts referenced from a Flyway script |
| `@@` | Supported (files only) | Does not behave as expected (scripts are copied to a temp location) |
| Checksums | Include referenced scripts and login.sql/glogin.sql (configurable) | Exclude them, so checksums differ from JDBC mode: run `repair` when switching |
| Transactions / `group` | Standard Flyway behaviour | No transactions; `group` has no effect. Enterprise can use Flashback restore points instead |
| Schema history locking | Yes | Not supported: do not run concurrent deployments |
| Script migrations (`.sh`/`.ps1`) | Yes | Not supported |
| Callbacks | All | Subset (non-statement callbacks for undo/info/baseline/repair added 12.1.1); `afterConnect` replaces `initSql` |
| Commands | All | migrate, clean (11.7.1+), testConnection (11.18+), deploy (12.6+) |
| Container | `redgate/flyway` | `redgate/flyway:<ver>-oracle` image contains SQLcl (13.2 notes); PATH inside the image unverified |

`testConnection` in NC mode fails early if SQLcl cannot connect (11.18+). Use it as the first pipeline step.

## Authentication

| Method | Edition | Config |
|---|---|---|
| Username/password | All | `user`/`password` via `${env.VAR}`; can also be embedded in the URL (avoid) |
| Oracle Wallet | Teams+ | `[flyway.oracle] walletLocation = "/secure/wallet"`; deploy wallet files, `tnsnames.ora`, `sqlnet.ora` as secure artifacts and set `TNS_ADMIN`. Desktop: TOML only |
| Kerberos | Teams+ | `[flyway] kerberosConfigFile = "/etc/krb5.conf"`, `[flyway.oracle] kerberosCacheFile = "/tmp/krb5cc_flyway"`, or JDBC properties `oracle.net.authentication_services = "(KERBEROS5)"` |
| Proxy authentication | All | Mentioned on the driver page; details in Oracle JDBC docs |

## Required grants

Flyway itself needs whatever the migrations do plus rights on its own tables. The comparison engine (Desktop, `check -changes`, `check -drift`, `snapshot`, `prepare`, `generate`) reads the data dictionary.

| Activity | Grants |
|---|---|
| Compare, as schema owner | Owner has everything needed for its own schema |
| Compare, not owner | `SELECT_CATALOG_ROLE` (Redgate's preferred: no data access) or `SELECT ANY DICTIONARY`; plus `SELECT` on non-PL/SQL objects and `EXECUTE` on PL/SQL objects being compared. System/SYSDBA gives full `DBA_` access |
| Dictionary fallback | Engine tries `DBA_*` views first, then falls back to `ALL_*`. Insufficient rights hide objects silently; `ORA-00942` during comparison usually means missing dictionary access |
| Deploy scripts | `CREATE/ALTER/DROP <type>` or the `ANY` variants for other schemas, `GRANT ANY OBJECT PRIVILEGE` if scripts grant. Redgate recommends running generated scripts as the schema owner |
| Shadow / build schema | Rights to clean and rebuild; creating schemas needs user-creation rights, otherwise pre-create the schemas with matching case |
| Flashback restore points (NC, Enterprise) | Flashback Database enabled and `CREATE ANY RESTORE POINT`, or SYSDBA / SYSOPER |
| Data Pump (Autopilot Oracle sample) | Export/import rights and a directory such as `DATA_PUMP_DIR` |

Recommended pattern: a dedicated deployment user with the `ANY` privileges it needs across the managed schemas, and a separate read-only user (`SELECT_CATALOG_ROLE` + `SELECT` on the Flyway tables) for drift checks.

## Multi-schema conventions

```toml
[flyway]
defaultSchema = "APP_OWNER"      # schema history + snapshot history live here
createSchemas = false            # schemas (users) pre-created by the DBA

[environments.prod]
url = "jdbc:oracle:thin:@//prod-ora01.corp.example:1521/PRODPDB"
user = "${env.ORA_PROD_USER}"
password = "${env.ORA_PROD_PASSWORD}"
schemas = ["APP_OWNER", "APP_API"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```
- `schemas` is case-sensitive: use the upper-case Oracle names. Flyway cleans in list order and drops schemas it created itself.
- First entry is the default schema if `defaultSchema` is unset. With `createSchemas = false`, the history table schema must already exist.
- Snapshots (and so drift checks) on Oracle need `schemas` set; since 12.0.2 `snapshot` without schemas uses `defaultSchema` if set.
- Scripts in multi-schema projects must be schema-qualified. Generated scripts include schema names unless `excludeSchemaNames = true`.
- **Single-schema shadow** (Oracle and MySQL only): dev `DEV1`, shadow `DEV1_SHADOW`, set `[redgateCompare.oracle.options.behavior] excludeSchemaNames = true`, and never schema-qualify managed objects (always qualify references to other schemas).
- **Multiple shadow schemas** (Oracle only): works only if the shadow schema names match the downstream schema names while dev schemas differ.
- Flyway sets the current schema to the default schema. Migrations that create database links expecting the user's own schema fail: create the link via a procedure owned by the right schema, or switch schema in `beforeEachMigrate`/`afterEachMigrate` callbacks.

## Schema history table naming and the synonym fix

| Version | Change |
|---|---|
| Default | Table name `flyway_schema_history` (lower case), so in Oracle it is a quoted, case-sensitive identifier |
| 12.0.1 | New schema history and snapshot history tables get synonyms so they can be queried unquoted |
| 12.0.3 | Those synonyms no longer show up as drift in check reports |
| 12.6.0 | Synonyms only created when the table name contains lower-case characters |

- Customer DBAs querying `SELECT * FROM flyway_schema_history` unquoted got ORA-00942 before 12.0.1. Existing tables created on older versions do not get synonyms retroactively (inferred from "new" tables; unverified).
- Changing `table` on an existing project makes Flyway look for a different table: do not rename without a plan.

## Tablespace configuration

| Setting | Scope |
|---|---|
| `[flyway] tablespace = "FLYWAY_TS"` | Where the schema history and snapshot history tables are created (ignored by databases without tablespaces) |
| `[redgateCompare.oracle.options.storage] includeStorageTablespace` | Whether table/index tablespaces are compared and scripted |
| `includeAllStorage`, `includeStoragePartitioning`, `includeStorageCompression`, `includeStorageLogging`, `includeStoragePctFree`, `includeStorageIniTrans`, `includeStorageExtents`, `includeStorageLobsAndVarrays`, `includeStorageDeferredSegments`, `includeStorageIlmPolicies` | Other physical properties |

Different tablespace names per environment is a common source of false differences: keep storage options off unless tablespaces match across environments.

## Dependency ordering and compilation

- `[redgateCompare.oracle.options.behavior] includeDependencies` pulls in dependent objects; the engine orders creation and adds `ALTER ... COMPILE` for dependents.
- `suppressDependentAlterCompile` (experimental) turns the dependent recompiles off.
- Other behaviour options worth knowing: `forceColumnOrder`, `useForwardSlash`, `includeSetDefineOff`, `includeSetBlankLinesOn`, `addPurgeClauseToAllTableDrops`, `detectRenamedColumns`, `includeCrossSchemaPermissions`, `includePermissionsUserCheck` (skip GRANT/REVOKE to the deploying user), `objectExistenceChecks` (Preview), `includeOnlineIndexCreation` (13.0+), `preserveIdentifierCase` (Preview, Flyway 13.9.0; Desktop 9.10.4 option): keeps schema names in deployment scripts in the capitalization Oracle stores them in instead of converting them to lowercase.
- PL/SQL compile errors surface as warnings by default. Make them fail: `errorOverrides = ["99999:17110:E"]` (Teams+).
- `[redgateCompare.oracle] edition = "MY_EDITION"` compares an Edition-Based Redefinition edition in addition to the base edition.

## Flashback

- **Native Connectors restore points (Enterprise):** Flyway creates `FLYWAY_RP_<timestamp>` at the start of a migration and drops it on success. On failure it logs the name; a DBA flashes back manually. Affects the whole database and needs downtime to restore.
- **Flashback for baselining shadows:** an `afterClean` callback that flashes the shadow back to a known good state avoids huge or unreplayable baseline scripts (tutorial in docs).

## GoldenGate

- The comparison engine automatically excludes GoldenGate columns.
- GoldenGate tables (`DT$_...`) are auto-filtered from 9.4.2. For older setups or extra certainty, filter rule: tables, Exclude when `^DT\$_` (Desktop filter UI), or in a filter file `{"filters": {"table": ["\!^DT\$_"]}}` (as written in the docs; `\!` is negation).

## Filters and ignore rules

- Desktop: Schema model page > Configure comparison > Filters tab. Rules per object type: exclude all, Exclude when, Include when (regex). Supports all Schema Compare for Oracle object types; some complex negation combinations become read-only.
- Files auto-detected in the project root: `Filter.scpf` and `IgnoreRules.scpf`. Override paths:
```toml
[redgateCompare.oracle]
filterFile = "Filter.scpf"
ignoreRulesFile = "IgnoreRules.scpf"
```
- Filter files from Schema Compare for Oracle / Source Control for Oracle can be reused (save to the project root).

## PL/SQL and SQL*Plus support

- `;` ends SQL statements. PL/SQL blocks (packages, bodies, types, functions, procedures, triggers, Java sources, views with functions) end with `/` on a new line.
- SQL*Plus commands (Teams+, `[flyway.oracle] sqlplus = true`): `@`, `@@`, `START` (files only), `DEFINE`, `UNDEFINE`, `EXECUTE`, `PROMPT`, `REMARK`, `SPOOL`, `SET DEFINE/ECHO/ESCAPE/FEEDBACK/HEADING/LINESIZE/NULL/SCAN/SERVEROUTPUT/SUFFIX/TERMOUT/TIME/TIMING/VERIFY`, `SHOW ...` (ERRORS, USER, RELEASE, EDITION and others), `WHENEVER SQLERROR CONTINUE/EXIT/EXIT FAILURE/EXIT SQL.SQLCODE`. Short forms supported.
- Unsupported commands are ignored with a warning; `sqlplusWarn = true` controls warning vs error for unsupported statements.
- `login.sql` (from migration locations) and `glogin.sql` (from `$ORACLE_HOME/sqlplus/admin`) load only when `sqlplus` is enabled; they count towards checksums unless `[flyway.oracle] checksumIncludeReferencedScripts = false` (12.4+, set once at project start; changing it later breaks validate).
- `SET SERVEROUTPUT ON` shows `DBMS_OUTPUT.PUT_LINE` output.
- `&VAR` in literals needs `SET DEFINE OFF` first. Flyway never prompts: missing values are errors (JDBC mode).
- Parity differences: abbreviations stricter (`SHO ERR` works, `SHOW ERROR` does not); Flyway preserves CRLF in literals where SQL*Plus converts to LF.
- Parser improvements: `DROP ... IF EXISTS` / `CREATE ... IF NOT EXISTS` (12.6), `EXEC` after a comment (12.8), package bodies referencing an object named `CASE` (13.4), `END CASE` / `END LOOP` / `END IF` split across two lines (13.9.0). If a script still fails to parse, Native Connectors is the escape hatch.

## Encoding

- `[flyway] encoding` default `UTF-8` (supported: US-ASCII, ISO-8859-1, UTF-8, UTF-16BE, UTF-16LE, UTF-16). Can also be set per script in a `.sql.conf` file.
- `detectEncoding = true` auto-detects per file (not supported in Desktop).
- `MalformedInputException` = inconsistent encodings. Standardise all scripts (UTF-8) rather than switching to ISO-8859-1.

## Gotchas

- Oracle DDL auto-commits. A failed migration cannot be rolled back cleanly: Flyway marks it failed, manual cleanup may be needed, then `repair`. Keep migrations small. Desktop hides "Execute in a transaction" for Oracle deployment scripts (Desktop 9.4.3).
- Oracle XE shadows: connect to the PDB service (`XEPDB1`), not `XE`. "Error running flyway clean" is usually this.
- Clean can only remove `sdo_geom_metadata` for the connected user.
- Docker provisioner for Oracle needs `iAgreeToTheDBVendorsEula = true`; Oracle 23+ containers failed with ORA-12514 before 13.2.
- Sessions identify as `Redgate_Flyway` (13.8+; previously "Flyway by Redgate"). Tell DBAs who filter sessions by program/module name.
- Oracle SQL error output no longer repeats SQL State / Error Code lines (12.11); log parsers keyed on those lines need updating.
- Driver debugging: swap `ojdbc11-*.jar` in `drivers/` for the `_g` debug jar and add `assets/logging.properties`. Logs may contain all SQL; revert afterwards.

## Sources
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/system-requirements/supported-databases-and-versions
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/oracle-database
- https://documentation.red-gate.com/x/epc6EQ (Oracle Database: Native Connectors)
- https://documentation.red-gate.com/x/AQCDEQ (Flyway Native Connectors: Oracle blog)
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/AwWoEw (Flyway Desktop 9 release notes)
- https://documentation.red-gate.com/x/BoWLE (Flyway Oracle namespace)
- https://documentation.red-gate.com/x/Z4WLE (Oracle SQLPlus setting)
- https://documentation.red-gate.com/x/LwE8F (Oracle checksumIncludeReferencedScripts)
- https://documentation.red-gate.com/x/goWLE (Redgate Compare Oracle namespace)
- https://documentation.red-gate.com/x/iIWLE (Oracle behavior options)
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/x/joWLE (Oracle storage options)
- https://documentation.red-gate.com/x/ioWLE (Oracle edition setting)
- https://documentation.red-gate.com/x/I4WLE (Tablespace setting)
- https://documentation.red-gate.com/x/IoWLE (Table setting)
- https://documentation.red-gate.com/x/tISLE (Environment schemas setting)
- https://documentation.red-gate.com/x/qYBUE (Flyway schema history table)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/ZYyLE (Configure shadow schema for Oracle)
- https://documentation.red-gate.com/x/XQI-C (Update Oracle filters and ignore rules)
- https://documentation.red-gate.com/x/ZALaEw (Oracle GoldenGate tables not automatically ignored)
- https://documentation.red-gate.com/x/AQGTD (Oracle Flashback for baselining)
- https://documentation.red-gate.com/x/B4uLE (Connecting to environments)
- https://documentation.red-gate.com/x/CwM8F (Kerberos tutorial)
- https://documentation.red-gate.com/x/9ISLE (Error overrides)
- https://documentation.red-gate.com/x/8oSLE (Encoding setting)
- https://documentation.red-gate.com/x/7YSLE (Detect encoding setting)
- https://documentation.red-gate.com/x/QYLTC (Permissions required to use Schema Compare for Oracle)
- https://documentation.red-gate.com/x/3aA6EQ (Oracle Autopilot prerequisites)

<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway troubleshooting: migrations, schema history and databases

Entry point and triage: `troubleshooting-patterns.md`. Message text in quotes is verbatim from the Flyway 13.8.0 open-source engine source or the docs unless marked "(field report)". `<v>`, `<schema>`, `<file>` are placeholders the engine fills in. Owner key: **Dev** (developer), **DBA**, **DevOps** (pipeline owner), **SE** (Laura), **Support** (Redgate support).

## Validate and schema history

### M1. Checksum mismatch
- **Symptom:** "Validate failed: Migrations have failed validation" then "Migration checksum mismatch for migration <v>" / "-> Applied to database : <n>" / "-> Resolved locally    : <n>" / "Either revert the changes to the migration, or run repair to update the schema history." Code `CHECKSUM_MISMATCH` (inside `VALIDATE_ERROR`).
- **Likely causes:** (1) applied script edited (including whitespace or a merge that touched it); (2) placeholder values changed for a repeatable or a script using placeholders; (3) switched Oracle JDBC to Native Connectors (NC excludes referenced scripts and login.sql from checksums); (4) upgrade from a very old Flyway (6.x) where repeatables used an older checksum (field report, https://github.com/flyway/flyway/issues/4063).
- **Ask:** Which file? Edited after deploying here? Placeholders or Flyway version changed?
- **Check:** `git log -p -- <file>`; `flyway info -environment=<env>`; compare the applied checksum across environments.
- **Fix:** Unintended edit: revert the file. Intended and the DB already matches: `flyway repair -environment=<env>` (realigns checksums). Never edit a migration that reached production; add a new one.
- **Owner:** Dev (file), DBA/DevOps (repair).
- **Escalate when, and collect:** checksums differ with no file change: `validate -X`, file from `git show`, Flyway versions.

### M2. Applied migration not resolved locally
- **Symptom:** "Detected applied migration not resolved locally: <v>." / "If you removed this migration intentionally, run repair to mark the migration as deleted." Code `APPLIED_VERSIONED_MIGRATION_NOT_RESOLVED` (or `APPLIED_REPEATABLE_...`).
- **Likely causes:** (1) wrong `locations` or `workingDirectory` in the pipeline (files not found); (2) running from a branch that lacks the file; (3) file intentionally deleted; (4) custom `ignoreMigrationPatterns` replaced the default `*:future`, so a version above the latest local one now errors (field report, https://github.com/flyway/flyway/issues/4130).
- **Ask:** Deleted on purpose? Which branch and folder does the job use?
- **Check:** `flyway info` (state `Missing` or `Future`); the log line "Skipping filesystem location" or "No migrations found".
- **Fix:** Fix paths/branch first. If deleted on purpose: `repair` marks it deleted. If you set `ignoreMigrationPatterns`, include `*:future`.
- **Owner:** DevOps / Dev.
- **Escalate when, and collect:** files present and paths right but still missing: `-X` log with resolved locations.

### M3. Resolved migration not applied (out of order, or pending)
- **Symptom:** "Detected resolved migration not applied to database: <v>." then either "To ignore this migration, set -ignoreMigrationPatterns='*:ignored'. To allow executing this migration, set -outOfOrder=true." (lower version behind a higher applied one, `RESOLVED_VERSIONED_MIGRATION_NOT_APPLIED`) or "To fix this error, either run migrate, or set -ignoreMigrationPatterns='*:pending'." (plain pending, seen when validating before migrate).
- **Likely causes:** (1) parallel branches merged with an older version number; (2) validate run in a step before migrate; (3) hotfix numbering.
- **Ask:** Did two branches create versions in parallel? Is this dev/test or production?
- **Check:** `flyway info` states `Ignored` vs `Pending`.
- **Fix:** dev/test: `outOfOrder = true` in that environment's `[environments.<env>.flyway]`. Production: prefer renumbering the unshipped migration above the latest applied; use `outOfOrder` only as a reviewed decision. Prevent with timestamped versions (Desktop default; `flyway add -timestamp=auto`; 13.7.0+ timestamps are UTC).
- **Owner:** Dev (numbering), DBA (policy).
- **Escalate when, and collect:** rarely needed.

### M4. Failed migration blocks everything
- **Symptom:** "Detected failed migration to version <v> (<description>)..." Codes `FAILED_VERSIONED_MIGRATION`, `FAILED_REPEATABLE_MIGRATION`, `FAILED_BASELINE_MIGRATION` (last one in engine source, not on the docs page). Docs fix: "Remove any incomplete changes then run repair to fix the schema history".
- **Likely causes:** (1) earlier migration failed on a database without transactional DDL (Oracle, MySQL) or with `executeInTransaction=false`/`mixed`; the row stays `success=0` (by design, staff confirmed: https://productsupport.red-gate.com/hc/en-us/community/posts/38101265553053, field report); (2) someone killed a run mid-migration.
- **Ask:** Which statements already ran?
- **Check:** `flyway info` (state `Failed`); inspect objects the script creates.
- **Fix:** Manually undo the partial changes (or finish them), `flyway repair`, fix the script, re-run `migrate`. On transactional databases (SQL Server, PostgreSQL) a failed migration normally rolls back and leaves no row.
- **Owner:** DBA.
- **Escalate when, and collect:** repair fails: `repair -X` output, schema history rows.

### M5. A migration's SQL fails
- **Symptom:** "Migration of <description> failed! Changes successfully rolled back." or "... failed! Please restore backups and roll back database and code!" with a block `SQL State  :` / `Error Code :` / `Message    :` / `Location   :` / `Line       :` / `Statement  :`. Without `-X` the statement reads "Run Flyway with -X option to see the actual statement causing the problem".
- **Likely causes:** (1) "already exists": change made in dev before the migration was generated (Desktop flow); (2) drift in the target; (3) permissions; (4) parser splitting a block (triggers, procedures, Snowflake/Databricks; see per-database).
- **Ask:** Full block? Ran in lower environments? Target changed by hand?
- **Check:** run with `-X` for the statement; `check -drift` against the target (Enterprise).
- **Fix:** "already exists" in a dev database: `flyway migrate -skipExecutingMigrations=true -cherryPick=<v>` marks it applied without running (dev only). Drift: resolve drift first (see `troubleshooting-enterprise.md` E14). Parser: use `batch`/delimiters or upgrade to the fixed version listed below.
- **Owner:** Dev / DBA.
- **Escalate when, and collect:** statement runs in SSMS/SQL*Plus but not Flyway: `-X` log, script, DB and Flyway versions.
- **Fixed in 13.9.0:** Flyway no longer reports "Changes successfully rolled back" when an exception occurred during the rollback itself. On older versions, do not trust that line alone: check `flyway info` and the target for partial changes. Also fixed in 13.9.0: Oracle parser failure when `END CASE`, `END LOOP` or `END IF` is split across two lines.

### M6. Existing database, no schema history table
- **Symptom:** "Found non-empty schema(s) <schema> but no schema history table. Use baseline() or set baselineOnMigrate to true to initialize the schema history table." Code `NON_EMPTY_SCHEMA_WITHOUT_SCHEMA_HISTORY_TABLE`.
- **Likely causes:** (1) first Flyway run against an existing database; (2) `table`, `defaultSchema` or `schemas` differ from the run that created the history table (Flyway looks in the wrong place); (3) Oracle: scheduler JOB objects make an "empty" schema look populated (field report, open: https://github.com/flyway/flyway/issues/3939).
- **Ask:** Has Flyway run here before? Which schema holds `flyway_schema_history`?
- **Check:** query for the history table in every schema; compare `defaultSchema`/`schemas`/`table` with the environment that worked.
- **Fix:** First run: `flyway baseline -baselineVersion=<n> -environment=<env>` once, or `-baselineOnMigrate=true` on the first deploy only (it removes a wrong-database safety net). Wrong location: fix config; do not baseline a second history table.
- **Owner:** DBA / DevOps.
- **Escalate when, and collect:** table exists and config matches: `-X` log, table rows.

### M7. Baseline conflicts
- **Symptom:** "Unable to baseline schema history table <table> with (<v>,<desc>) as it has already been baselined with (...)" or "... with version 0 as this version was used for schema creation"; warning "All configured schemas are empty; a baseline marker will not be added to Flyway's schema history table. A baseline or migration script with a lower version than the baseline version may execute if available. Check the Schemas parameter if this is not intended."
- **Likely causes:** (1) baseline already done; (2) `schemas` points at an empty schema so Flyway treats the DB as new; (3) baseline migration (`B__`) expected to run on a non-empty target (it runs only on empty targets).
- **Ask:** What does `info` show at the bottom? Which schemas are configured?
- **Check:** `flyway info`; `schemas` list.
- **Fix:** Correct `schemas`. Versions at or below `baselineVersion` are skipped by design. Note: edits to a `B__` script are not caught by validate (field report, open: https://github.com/flyway/flyway/issues/4106). In Native Connectors mode before Flyway 13.10.1, a `baseline` script could show as `Pending` instead of `Ignored` on a database with already-applied migrations (Issue 4292, fixed 13.10.1). From Flyway 13.11.0 `info` honours `baselineOnMigrate`, so migrations at or below `baselineVersion` show as `Below Baseline` or `Ignored` instead of `Pending`; before 13.11.0 `info` could list them as `Pending` even though `migrate` would skip them.
- **Owner:** DBA.
- **Escalate when, and collect:** history rows plus config.

### M8. Duplicate versions
- **Symptom:** "Found more than one migration with version <v>" / "Offenders:" with two paths. Code `DUPLICATE_VERSIONED_MIGRATION` (also `DUPLICATE_REPEATABLE_MIGRATION`, `DUPLICATE_UNDO_MIGRATION`, `DUPLICATE_DELETED_MIGRATION`).
- **Likely causes:** (1) two developers picked the same number (field report: https://productsupport.red-gate.com/hc/en-us/community/posts/24975030005021); (2) the same folder listed twice in `locations`; (3) copies in a build output folder.
- **Fix:** Renumber the unshipped file; switch to timestamped versions; de-duplicate `locations`. `DUPLICATE_DELETED_MIGRATION` means schema history tampering: stop and involve Support.
- **Owner:** Dev.

### M9. When to use repair (and when not)
- `repair` removes failed rows, realigns checksums, descriptions and types to local files, and marks missing applied migrations deleted; it needs the same `locations` as migrate. Never use it to hide unexplained production differences: find the cause first (M1, M2) and keep `info` output from before and after.

### M10. Hang or lock on the schema history table
- **Symptom:** "Waiting for lock on Flyway schema history table. Application may be deadlocked. Lock row may require manual removal from the schema history table." or "Unable to acquire SQL Server application lock" / "Unable to acquire PostgreSQL advisory lock" / "Unable to acquire MySQL named lock: <name>" / "Unable to lock table <table>".
- **Likely causes:** (1) two deployments at once (parallel jobs on one database); (2) a killed session still holding the lock; (3) PostgreSQL: a migration using `CONCURRENTLY` waiting on Flyway's own transactional lock; (4) long DDL blocked by application traffic.
- **Ask:** Is another pipeline or app instance migrating? Was a job cancelled?
- **Check:** blocking chains; sessions named "Redgate_Flyway" or "Flyway by Redgate" (13.8.0 notes are inconsistent).
- **Fix:** Serialise deployments (CI concurrency/resource group). Kill the orphaned session. PostgreSQL CONCURRENTLY: `[flyway.postgresql] transactional.lock = false` (see PG section). Oracle Native Connectors has no history-table locking: never run parallel deploys.
- **Owner:** DBA / DevOps.

### M11. Clean refused or incomplete
- **Symptom:** "Unable to execute clean as it has been disabled with the 'flyway.cleanDisabled' property." (engine text). For `check` see `troubleshooting-enterprise.md` E13.
- **Causes / fix:** `cleanDisabled` defaults to true. Enable only for disposable environments via `[environments.<env>.flyway] cleanDisabled = false` (env-level honoured from 12.0.2). Objects left behind (SQL Server users, complex dependencies, Oracle `sdo_geom_metadata` for other users, PostgreSQL extension objects): add an `afterClean` callback. Oracle: "Clean not supported on Oracle for system schema <schema>!"
- **Owner:** DevOps / DBA.

## Scripts and configuration

### M12. Placeholders
- **Symptom:** "No value provided for placeholder: ${<name>}.  Check your configuration!"
- **Likely causes:** (1) placeholder not defined for this environment; (2) SQL text that looks like `${...}` (for example in dynamic SQL or JSON); (3) SQLCMD `$(var)` from SCA/SoC scripts (not a Flyway placeholder).
- **Check:** `-X` shows effective config and where each value came from (13.5+).
- **Fix:** Define it in `[flyway.placeholders]` or `[environments.<env>.flyway.placeholders]`; escape by disabling replacement (`placeholderReplacement = false` or a per-script config) or change prefix/suffix. Native Connectors (Oracle) does not substitute into `@` referenced scripts, and undefined `&VAR` makes the script hang.
- **Owner:** Dev.

### M13. Callbacks
- **Symptom:** callback SQL not run, or fails every deploy.
- **Causes / fix:** file name must match an event (`beforeMigrate.sql`, `afterMigrate__desc.sql`, `afterClean.sql`, `beforeEachMigrate.sql`) and sit in `locations`; callbacks fire on every command raising the event, so make them idempotent. Native Connectors has its own event list. `prepare -source=migrations` ignores callbacks.
- **Owner:** Dev.

### M14. Encoding
- **Symptom:** garbled characters after deploy, or checksum changes after a file was re-saved.
- **Causes / fix:** set `encoding` (default UTF-8). With `detectEncoding=true` an undetectable encoding silently falls back to UTF-8, logged only with `-X` (KB field report: https://productsupport.red-gate.com/hc/en-us/articles/4415538816273). Re-saving with a BOM or new encoding changes the checksum (M1); enforce `.gitattributes`.
- **Owner:** Dev.

### M15. Transactions and mixed statements
- **Symptom:** "Detected both transactional and non-transactional statements within the same migration (even though mixed is false). Offending statement found at line <n>: <sql> [non-transactional]" or "Detected both transactional and non-transactional migrations within the same migration group" (with `group=true`).
- **Likely causes:** `CREATE INDEX CONCURRENTLY`, `ALTER TYPE ... ADD VALUE` (older PG), `CREATE DATABASE`, SQL Server memory-optimized DDL, full-text catalogs in the same script as normal DDL.
- **Fix:** Put the non-transactional statement in its own migration (preferred), or `mixed = true` (that whole script then runs without a transaction), or per-script `executeInTransaction=false` (script config file `<script>.sql.conf`). Script config files accept only some parameters: "Unknown configuration property: postgresqlTransactionalLock" (field report, https://github.com/flyway/flyway/issues/3840).
- **Owner:** Dev.

### M16. Migrations not found
- **Symptom:** "Skipping filesystem location: <path> (...)" (12.10+ adds the effective working directory), "No migrations found. Are your locations set up correctly?", "Unable to resolve location <location>.", or files silently ignored: "<n> SQL migrations were detected but not run because they did not follow the filename convention." (field report text, https://github.com/flyway/flyway/issues/4083).
- **Likely causes:** (1) relative `locations` resolved from the agent's working directory; (2) bad name (`V1_desc.sql`, single underscore); (3) Docker mount path differs.
- **Fix:** `-workingDirectory=<project>`; `locations = ["filesystem:migrations"]`; `validateMigrationNaming = true` to fail on bad names.
- **Owner:** DevOps / Dev.

### M17. Cannot connect or no driver
- **Symptom:** "Unable to obtain connection from database<url> for user '<user>': <driver message>"; "Unable to connect to the database. Configure the url, user and password!"; "No Flyway database plugin found to handle: jdbc:..." (docs wording); "No JDBC driver found to handle: jdbc:..."; "Unable to instantiate JDBC driver: <class> => Check whether the jar file is present" (`JDBC_DRIVER`); "Unsupported Database: <name> <version>".
- **Likely causes (ranked):** (1) network/firewall/DNS from the agent; (2) credentials not reaching Flyway (secret not mapped, env var typo); (3) no config loaded (wrong folder; with both `.conf` and `.toml` only TOML loads, field report: https://productsupport.red-gate.com/hc/en-us/community/posts/24974108407581); (4) URL typo, or community DB without `communityDBSupportEnabled = true`; (5) unshipped driver (BigQuery, MongoDB, community DBs) not in `drivers/`; (6) Java API/Maven/Gradle without the database module, giving "Unsupported Database" (field report: https://github.com/flyway/flyway/issues/4025).
- **Check:** `flyway testConnection -environment=<env>` (tests Flyway engine and comparison engine connections, prints "Connection successful" per engine); `-X` shows effective URL and config origin.
- **Owner:** DevOps / DBA.
- **Escalate when, and collect:** `testConnection -X` output (redact), URL shape, driver jars present.

## Per-database patterns

### SQL Server and Azure SQL
- **S1 Untrusted certificate.** Symptom: "Unable to obtain connection from database: ... The server certificate is not trusted. You can proceed to connect to this database by setting the "trustServerCertificate" flag to true, but this may be dangerous..." (sub-code `UNTRUSTED_CERTIFICATE`), or driver text "PKIX path building failed ... unable to find valid certification path to requested target". Cause: Microsoft JDBC driver encrypts by default and validates the certificate. Fix: trusted certificate on the server or truststore via `JAVA_ARGS`; `trustServerCertificate=true` only for dev/test. Owner: DBA.
- **S2 Integrated / Entra auth.** Symptom: "Unable to obtain connection from database: ... To setup integrated authentication see ..." (`INTEGRATED_AUTH_NOT_SUPPORTED`) or "... You need to install some extra drivers in order for interactive authentication to work." (`INTERACTIVE_AUTH_DRIVERS_MISSING`). Causes: integratedSecurity on a non-Windows agent or missing auth DLL; Entra libraries not present for the chosen method. Field reports: Managed Identity failures on 11.0.x, `ActiveDirectoryDefault` working by 11.7.2 (https://github.com/flyway/flyway/issues/3986); `jdbcProperties.accessToken` lost when placeholders set, use `-environments.<env>.jdbcProperties.accessToken=...` (https://github.com/flyway/flyway/issues/3884). Owner: DBA / DevOps. Escalate with auth method, agent OS, `-X`.
- **S3 PRINT noise.** PRINT surfaces as warnings (SQL state S0001, code 0). Fix: `errorOverrides = ["S0001:0:I-"]` (honoured by `deploy` from 11.13.0). Owner: Dev.
- **S4 Unsupported engine edition.** "java.lang.IllegalArgumentException: Unknown SQL Server engine edition: 11" on Synapse serverless SQL pool, which is not supported; dedicated pool is (field report, staff: https://productsupport.red-gate.com/hc/en-us/community/posts/24974993311901). Owner: SE (set expectations).
- **S5 Memory-optimized / full-text DDL** fails in a transaction: own migration with `executeInTransaction=false`.
- **S6 Named instance:** `jdbc:sqlserver://host;instanceName=inst;databaseName=db` (a port overrides it).

### Oracle
- **O1 History table queries fail (ORA-00942)** for unquoted `flyway_schema_history`: the default name is lowercase and quoted. Quote it. From 12.0.1 Flyway creates synonyms on new history and snapshot tables; from 12.6.0 only when the name has lowercase characters; synonyms no longer show as drift from 12.0.3.
- **O2 Native Connectors not used or failing early.** Needs `FLYWAY_NATIVE_CONNECTORS=true` and SQLcl reachable; Flyway fails at startup if SQLcl cannot connect (11.18.0+). "No Native Connectors database plugin found for the designated database" means the database is not NC-capable or the module is missing. In the `-oracle` Docker image SQLcl sits in `/opt/sqlcl`; PATH handling is (unverified), see `arch-oracle-native-multischema.md`.
- **O3 Script hangs under NC:** undefined `&VAR` substitution variable; define it or `SET DEFINE OFF`.
- **O4 "ORA-00900: invalid SQL statement"** on SQL*Plus commands: `oracle.sqlplus = true` not applied (Gradle users set it in `gradle.properties`; field report https://github.com/flyway/flyway/issues/3827).
- **O5 Compilation errors pass silently** (reported as warnings): `errorOverrides = ["99999:17110:E"]`.
- **O6 Failed migration needs repair** every time (M4): by design on Oracle.
- **O7 Clean fails on XE:** connected to the CDB `XE` instead of `XEPDB1` (docs, shadow page).
- **O8** DB links fail: Flyway sets the session schema to `defaultSchema`; create links in the right schema or via callbacks. **O9** TNS alias not found: set `TNS_ADMIN`.

### PostgreSQL
- **P-1 "permission denied for schema public"** on PG15+: CREATE on `public` no longer granted by default; grant it or use a dedicated schema.
- **P-2 CONCURRENTLY hangs or fails:** separate migration plus `[flyway.postgresql] transactional.lock = false` globally (maintainer advice, https://github.com/flyway/flyway/issues/3840); per-script setting still not supported as of 12.0.3 (https://github.com/flyway/flyway/issues/3961).
- **P-3 "Unable to determine current schema as search_path is empty. Set the current schema in currentSchema parameter of the JDBC URL or in Flyway's schemas property."** Set `schemas` or `currentSchema`.
- **P-4 ALTER TABLE blocks production:** PostgreSQL ACCESS EXCLUSIVE lock, not Flyway; use `lock_timeout` and expand/contract (staff, https://productsupport.red-gate.com/hc/en-us/community/posts/30583484768925).
- **P-5 Pool exhaustion (Java API):** "Connection is not available, request timed out after 30000ms" with a pool of 2 on 11.16 (needs 3), fixed after 11.17.0 (https://github.com/flyway/flyway/issues/4169).
- **P-6** BEGIN ATOMIC misparsed on old versions, RDS/Aurora IAM auth (AWS JDBC wrapper): see `postgres-reference.md`.

### MySQL and MariaDB
- **Y1 Partial changes after failure:** DDL auto-commits; clean up, `repair`, re-run. One DDL change per migration; `group` cannot roll back DDL.
- **Y2 jdbc:mysql URL rejected or driver fallback:** CLI ships the MariaDB driver; add `permitMysqlScheme=true` or MySQL Connector/J in `drivers/`.
- **Y3 "RSA public key is not available client side (option serverRsaPublicKeyFile not set)"** against MySQL 8 (`caching_sha2_password`): add `allowPublicKeyRetrieval=true` or use TLS (docs Docker page); field report still open with the MariaDB driver (https://github.com/flyway/flyway/issues/4034).
- **Y4 MySQL 8.4** needs Flyway 11.13.3 or later (staff, https://productsupport.red-gate.com/hc/en-us/community/posts/38029489360029).
- **Y5 "Illegal mix of collations"** after a 10.9 to 11.11 upgrade (field report, open: https://github.com/flyway/flyway/issues/4131); no confirmed fix.
- **Y6 Trigger BEGIN...END split** on MariaDB (syntax error "near '' at line 9", open: https://github.com/flyway/flyway/issues/3894): use `DELIMITER` handling or separate script.

### Databricks
- **K1 "[PARSE_SYNTAX_ERROR] Syntax error at or near end of input. SQLSTATE: 42601"** for procedures containing MERGE (split at `;`): fixed in CLI 12.6.0 (support-confirmed field report, https://productsupport.red-gate.com/hc/en-us/community/posts/34826715661597).
- **K2** Advanced (comparison) features are preview; see `databricks-snowflake-reference.md` for auth and GA status. Snapshot history supported from 13.1.0.

### Snowflake
- **F1 "SQL compilation error: syntax error line <n> at position <n> unexpected '<EOF>'."** for anonymous BEGIN...END blocks on 11.20.3 and 12.0.0 (field report, open: https://github.com/flyway/flyway/issues/4201); nested IF fixed by PR merged Jan 2026 (#4179).
- **F2 "No JDBC driver found to handle ********."** with snowflake-jdbc 3.x and Flyway 13.x: use snowflake-jdbc 4.0.2+ (bundled since 12.2.0) (https://github.com/flyway/flyway/issues/4282).
- **F3 Key-pair auth fails ("Private key provided is invalid or not supported"):** `private_key_file` is honoured only in the JDBC URL, not `jdbcProperties` (staff, https://productsupport.red-gate.com/hc/en-us/community/posts/33787044851101); in containers mount the key file.
- **F4 "Failed to execute operation in non-transactional context..." then "Unable to restore original schema"** on accounts without a PUBLIC schema, 12.2.0; fixed in 12.4.0 (https://github.com/flyway/flyway/issues/4221). Pin versions.

## Sources
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/validate-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/general-error-codes
- https://documentation.red-gate.com/flyway/reference/usage/database-troubleshooting
- https://documentation.red-gate.com/fd/reference/commands/test-connection
- https://github.com/flyway/flyway/tree/main/flyway-core (engine message text at 13.8.0)
- https://github.com/flyway/flyway/tree/main/flyway-database (SQL Server, PostgreSQL, MySQL, Oracle lock and connection messages)
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace (cleanDisabled, errorOverrides, outOfOrder, baselineOnMigrate, mixed, encoding settings)
- https://documentation.red-gate.com/fd/oracle-database-native-connectors-289052538.html
- https://documentation.red-gate.com/flyway/flyway-concepts/environments/shadow-and-build-environments
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- Field reports: GitHub issues 3827, 3840, 3884, 3894, 3939, 3961, 3986, 4025, 4034, 4063, 4083, 4106, 4130, 4131, 4169, 4201, 4221, 4282 at https://github.com/flyway/flyway/issues ; Redgate community posts and KB articles linked inline

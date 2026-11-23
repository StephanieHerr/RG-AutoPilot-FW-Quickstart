<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway troubleshooting: Enterprise features

Licensing and auth, comparison (diff, generate, model, prepare, snapshot), deploy, check reports and drift, shadow/build and provisioners, code analysis, MCP server, Flyway Insights. Entry point: `troubleshooting-patterns.md`. Quoted messages are verbatim from the 13.8.0 engine source or the docs unless marked "(field report)". Owner key: **Dev**, **DBA**, **DevOps**, **SE** (Laura), **Support** (Redgate support), **Licensing** (Redgate licensing/sales ops).

## Licensing and authentication

### E1. Running as Community (or Teams) when Enterprise is expected
- **Symptom:** banner shows "Flyway Community Edition <v> by Redgate" (or "Flyway OSS Edition"); Enterprise verbs fail with "Upgrade required: <feature> is not supported by <edition>." followed by "If you would like to start a free Enterprise trial, please run auth -startEnterpriseTrial -IAgreeToTheEula." Pre-10 wording was "Flyway Teams Edition upgrade required: ..." (field report). Exit code 35.
- **Likely causes (ranked):** (1) PAT secrets not reaching the process (secret not mapped into the step, wrong variable names); (2) Flyway 12.8.0 exactly: `FLYWAY_EMAIL`/`FLYWAY_TOKEN` env vars not recognised (fixed 12.8.1); (3) the account behind the PAT has no Enterprise entitlement; (4) expired offline permit, which reverts to Community features; (5) dev machine upgraded to 13.6.0 without re-running `auth` (E3).
- **Ask:** What does the first line of output say? Which licensing method: PAT, offline permit, `auth`, legacy key?
- **Check:** `flyway version` (the line after "Licensed via:" names the method, 12.6.0+); `flyway version -outputType=json` includes `edition` and `permitExpiry`; in CI echo whether `FLYWAY_EMAIL` is set (never the token).
- **Fix:** Map secrets into the step env; use a service account PAT; upgrade past 12.8.0; add a fail-fast edition check in pipelines (see `common-architectures.md`).
- **Owner:** DevOps; Licensing for entitlement.
- **Escalate when, and collect:** entitlement looks right but still Community: `flyway version -X` (redact token), account email, Flyway version.

### E2. Licence precedence surprises
- Order: offline permit, then PAT (email + token), then interactive `auth`, then legacy licence key. A stale offline permit on disk or in `FLYWAY_OFFLINE_PERMIT_PATH` wins over a good PAT.
- Legacy key messages: "An invalid Flyway license key was provided; fell back to Community Edition. Remove license key and run auth to authorize online..." and "Invalid license key. Ensure flyway.licenseKey is set to a valid Flyway license key ("FL01" followed by 512 hex chars)". Expired key (field report, KB): "WARNING: An expired Flyway license key was provided; fell back to Community Edition." (https://productsupport.red-gate.com/hc/en-us/articles/31709267181469). Fix: remove `licenseKey`, move to PAT or offline permit.
- **Owner:** DevOps.

### E3. 13.6 re-auth and "Please rerun auth"
- **Symptom:** "Flyway permit on disk is outdated and cannot be refreshed automatically because there is no refresh token on disk. Please rerun auth. For more information see: ..." or "Flyway permit on disk is expired and cannot be refreshed automatically because there is no refresh token on disk. Please rerun auth..."
- **Likely causes:** (1) upgraded a developer machine to 13.6.0 or later. Release note: "the cached credentials from `flyway auth` are no longer invalidated when Flyway is upgraded. Note that upgrading to this version requires running `flyway auth` once more."; (2) permit created without a refresh token; (3) `auth` used on a CI agent.
- **Fix:** `flyway auth -IAgreeToTheEula` once on the machine (browser sign-in; does not work on WSL or over SSH; use a PAT there). In CI use PAT or offline permit, never `auth`. `flyway auth -logout` clears the stored permit and refresh token (`%APPDATA%\Redgate\Flyway CLI` or `~/.config/Redgate/Flyway CLI`).
- **Owner:** Dev (own machine), DevOps (agents).

### E4. Expired licence or offline permit
- **Symptom:** "Your <tier> license has expired and is no longer valid. You must renew your license immediately to keep on using this software."; trial: "Your 30 day limited Flyway trial license has expired and is no longer valid..." (engine text; Desktop trials are 28 days per docs); from 12.8.0 a warning when an offline permit expires within 30 days.
- **Fix:** Offline permit: download a new one (CLI productCode=63 at https://permits.red-gate.com/offline?productCode=63, Desktop productCode=64), valid 365 days or to subscription end. Engine env var is `FLYWAY_OFFLINE_PERMIT_PATH` (12.0.0 replaced `REDGATE_LICENSING_PERMIT_PATH` for the engine; Desktop docs still use the old name). Renewal: Licensing.
- **Owner:** DevOps; Licensing.

### E5. Licensing blocked by network or TLS inspection
- **Symptom (field report):** "ERROR: Couldn't read app data Flyway permit" with `-X` showing "Failed to fetch permit from PAT token licensing: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target" (https://productsupport.red-gate.com/hc/en-us/community/posts/24975032057373).
- **Causes:** proxy doing TLS inspection with a corporate root CA the JVM does not trust; firewall blocking Redgate licensing hosts; unwritable app data folder.
- **Fix:** allowlist licensing hosts (KB: licensing.red-gate.com, productlogin.red-gate.com, permits.red-gate.com, identityprovider.red-gate.com and others; ports 443 and 80) per https://productsupport.red-gate.com/hc/en-us/articles/360002374673 ; import the corporate CA into a truststore and pass `JAVA_ARGS=-Djavax.net.ssl.trustStore=... -Djavax.net.ssl.trustStorePassword=...`; proxy: see `troubleshooting-desktop-and-pipelines.md` P9. Air-gapped: offline permit.
- **Owner:** Customer network team / DevOps.

## Comparison: diff, generate, model, prepare, snapshot

All comparison-backed commands (check changes/drift, diff, diffText, generate, model, prepare, snapshot) report `COMPARISON_*` codes.

### E6. Comparison cannot connect or read a source
- **Symptom:** `COMPARISON_DATABASE_CONNECTION_FAILED` (driver-specific underlying error) or `COMPARISON_REGISTRATION_FAILED` ("invalid schema model or an issue querying a database").
- **Likely causes:** (1) comparison engine uses its own connection: Entra/Kerberos or certificate settings that JDBC accepts may still fail there; (2) insufficient permissions to read metadata (SQL Server: VIEW DEFINITION; Oracle: Schema Compare for Oracle permissions; encrypted objects need sysadmin); (3) corrupted or hand-edited schema model file.
- **Check:** `flyway testConnection -environment=<env>` reports each engine ("Flyway" and the comparison engine) separately.
- **Fix:** grant metadata permissions; fix the offending schema model file named in the message.
- **Owner:** DBA / Dev.
- **Escalate when, and collect:** `testConnection -X`, the message, database version.

### E7. Diff artifact not found or unreadable
- **Symptom:** `COMPARISON_ARTIFACT_NOT_FOUND`, `COMPARISON_ARTIFACT_DESERIALIZE_FAILED`, `COMPARISON_ARTIFACT_SERIALIZE_FAILED`.
- **Causes:** `generate`/`model`/`diffText` run in a different step, container or working directory from `diff`; parallel jobs writing the same artifact; no write access.
- **Fix:** chain in one invocation (`flyway diff generate ...`) or pass the same `-artifactFilename`; one artifact path per job; re-run `diff` (artifacts are point in time).
- **Owner:** DevOps / Dev.

### E8. Comparison engine missing, outdated or cannot start
- **Symptom:** `COMPARISON_BINARY_MISSING` ("Reinstall Flyway"), `COMPARISON_ENGINE_UPDATE_REQUIRED` (project files written by a newer Flyway, "Update Flyway"), "ERROR: RGCompare exited with code 127" on Linux (field report, https://productsupport.red-gate.com/hc/en-us/community/posts/29795857715613).
- **Causes:** Desktop newer than the CLI on the agent; stripped or custom Docker image without .NET dependencies (`libicu`, `libssl3`, `libstdc++6`, `zlib1g`, `liblttng-ust1`, `libunwind8` per docs); unsupported OS (comparison uses .NET 8 from 10.1.0; RHEL 7 unsupported).
- **Fix:** align CLI version with the Desktop version that wrote the project (Desktop pins an engine build, see `release-status.md`); use the official `redgate/flyway` image or install the documented packages; supported distro.
- **Owner:** DevOps.

### E9. Database not supported by comparison
- **Symptom:** `COMPARISON_DATABASE_NOT_SUPPORTED` ("Supported databases include SQL Server, Oracle, PostgreSQL, and MySQL").
- **Fix:** migrations-only workflow for that engine; Snowflake and Databricks comparison are preview (check `databricks-snowflake-reference.md`). Owner: SE (expectations).

### E10. generate errors or unexpected output
- **Symptoms and fixes:** `-generate.types=baseline,versioned` or `baseline,undo` "is disallowed and will result in an error"; `generate.target` must match `diff.source` or `diff.target`; stale shadow gives wrong scripts (Desktop re-provisions on checksum change, version ahead, name mismatch, previous failure, or only repeatables); `COMPARISON_GENERATE_DEPLOYMENT_SCRIPT_FAILED` / `COMPARISON_GENERATE_UNDO_SCRIPT_FAILED` carry the detail in the message. Renames, splits, NOT NULL without default and data motion need hand-edited migrations.
- **Owner:** Dev. Escalate with the diff artifact (contains schema information: get customer consent) and `-X`.

### E11. prepare aborts or produces a dangerous script
- **Symptom:** `PREPARE_ABORT_ON_WARNINGS`: "Deployment warnings detected of a severity which exceed the configured abortOnWarnings threshold."
- **Fix:** read the warnings (data loss, table rebuilds); handle with a migration or adjust `[flyway.prepare] abortOnWarningSeverity` (`None` default, `Low`, `Medium`, `High`; the docs CLI example `=true` is wrong). Missing schema model folder fails clearly from 12.5.0: fix `schemaModelLocation`. Script drops a schema: set `schemaModelSchemas`. From migrations, prepare ignores Java migrations and callbacks.
- **Owner:** DBA reviews; Dev fixes source.

### E12. deploy and snapshot
- deploy: `-saveSnapshot=true` embeds a snapshot for drift checks (Desktop 9.10.0 saves by default). Native Connectors supported from 12.6. PRINT noise: `errorOverrides` honoured from 11.13.0.
- snapshot: `-filename` required; Oracle needs `schemas`; history table `flyway_snapshot_history` auto-created; history limit default 5 (12.1.0); size caps after compression SQL Server 2 GB, Oracle 4 GB, MySQL 2 GB, PostgreSQL 1 GB; `COMPARISON_SNAPSHOT_FAILED` carries detail. Snapshot history supported for Databricks (13.1.0) and Snowflake (13.8.0).
- **Owner:** DevOps.

## Check reports and drift

### E13. check -changes cannot build
- **Symptom:** `PLUGIN_CHECK_MISSING_BUILD_TARGET` ("check changes requires a buildEnvironment or deployedSnapshot... check drift requires a buildEnvironment or nextSnapshot"); `CHECK_BUILD_NO_PROVISIONER`; docs message "ERROR: Clean is disabled - unable to configure clean provisioner".
- **Causes:** since 11.0.0 the build environment needs a provisioner or clean enabled; env-level `cleanDisabled` honoured from 12.0.2; inline `check.buildUrl` supports only the cleanDisabled route; shared build DB used by parallel runs.
- **Fix:** `provisioner = "clean"` (existing DB) or `"create-database"` (preview; creates it) on the build environment, plus `[environments.build.flyway] cleanDisabled = false`; serialise pipelines.
- **Owner:** DevOps.

### E14. Drift detected, or drift check behaves oddly
- **Symptom:** `CHECK_DRIFT_DETECTED` (with `failOnDrift=true`); report shows unexpected differences; first run warns and succeeds.
- **Likely causes:** (1) real hotfix in the target; (2) no embedded snapshot yet (first run succeeds with a warning); (3) snapshot taken with different filters or comparison options; (4) known noise fixed in upgrades (Oracle history synonyms 12.0.3; drift script generation failures no longer fail the command 12.10.0; 11.19.0 fix for targets without snapshot history table).
- **Ask:** Who changed prod and when? Was the last deploy made with `saveSnapshot`?
- **Check:** HTML/JSON report (`reportFilename`, default `report.html` plus `.json`); `drift-resolution/` folder (or `check.driftResolutionFolder`, 12.9+; replaced each run) with revert, incorporate and (SQL Server, Oracle) filter scripts.
- **Fix:** incorporate (migration or schema model), revert (run revert script with `deploy` from the CLI), or filter. Drift gates do not stop chained verbs: separate step.
- **Owner:** DBA decides; Dev incorporates.

## Shadow, build and provisioners

### E15. Provisioner errors
| Provisioner | Symptom / requirement | Fix |
|---|---|---|
| `clean` | Only re-provisions an existing database | Create the DB first, or use `create-database` |
| `create-database` (preview) | Without CREATE DATABASE rights "Flyway will exit with an error"; DB name must be in the URL | Grant; `reprovisionMethod` CLEAN (default), DROP, NONE |
| `backup` (preview) | SQL Server needs dbcreator, ##MS_DatabaseManager## or sysadmin, URL `databaseName`; Oracle needs `impdp` on PATH, IMP_FULL_DATABASE, READ on directory, schemas pre-created; `backupVersion` required if no history table | Grant; set `backupVersion` |
| `snapshot` (preview) | `filename` and `snapshotVersion` required; `cleanOnReprovision` for snapshots that cannot apply | Set both |
| `docker` (preview) | `DOCKER_NOT_INSTALLED`, `DOCKER_NOT_RUNNING` (Linux: add user to `docker` group), `DOCKER_EULA_NOT_ACCEPTED` (`iAgreeToTheDBVendorsEula = true` for SQL Server, Oracle); `url`/`user`/`password` rejected (13.6.0+); mixing compose and smart keys errors; from 13.11.0 it builds SQL Server and PostgreSQL environments in a dedicated `flyway` database and Oracle in a dedicated `FLYWAY` schema (previously `master`, `postgres`, `SYSTEM`) | Fix per code; upgrade for 13.2.0 ORA-12514 on Oracle 23+ and 13.8.0 localhost URL fix; after upgrading to 13.11.0 check anything that assumed the old database or schema |
| `docker-compose` (preview) | `composeFile`, `services`, `waitTimeout` required; old `docker` compose-style config forwards with a warning | Rename to `docker-compose` |
| `clone` (Redgate Clone) | Deprecated | Move to backup, snapshot or docker |

Shadow in general: never point at data you need (it is cleaned); cross-database dependencies, linked servers and filegroups must exist on the shadow server; the shadow user needs create-schema rights and matching schema casing. Oracle XE: connect to `XEPDB1`, not `XE`, or clean errors.

## Code analysis

### E16. check -code problems
- Bundled SQLFluff fails on old Linux: "GLIBC_2.35 not found" (Ubuntu 22.04+, Debian 12+, RHEL 9.1+, or your own SQLFluff).
- Desktop 9.1.0: "WARNING: Could not find Redgate Bundle SqlFluff engine: ..." packaging slip fixed in 9.1.1 (field report, https://productsupport.red-gate.com/hc/en-us/community/posts/34536483953821).
- `majorRules`/`minorTolerance` removed in 12.0.0: use severities and `check.code.failOnError`. Default regex ruleset not shipped from 12.0.0: commit your rules and set `rulesLocation`.
- `failOnError` does not stop chained verbs. Scope values: DEFAULT, ALL, PENDING, SCRIPT (default is PENDING when a URL is set, otherwise ALL). 13.6.0 adds `check.code.profile(s)` (the 13.6.0 notes say a built-in `schemaModel` profile is included; the profiles setting page now says Flyway ships no profiles, so define `schemaModel` yourself; naming an undefined profile fails the command and lists the available ones). Profiles can exclude regex rules by code from 13.11.0.
- **Owner:** Dev / DevOps. Details: `code-analysis.md`.

## MCP server (preview, Enterprise, 13.0+)

### E17. MCP server issues (from the docs troubleshooting page)
| Symptom | Fix |
|---|---|
| `flyway` isn't recognized as a command | Put the install `bin` on PATH or use the full path in `.mcp.json` `command`; on Windows name `flyway.cmd` explicitly for GUI-launched tools |
| AI tool doesn't detect the server | File must be exactly `.mcp.json` (not `mcp.json` or `.mcp.json.txt`), in the folder the tool launched from (or passed via e.g. `--mcp-config`); restart the tool |
| Nothing happens | Each session must `load_project` first and return a workspace ID |
| Can't find `flyway.toml` | The install folder is not the project folder; Desktop may have created the project in a subfolder; check for `flyway.user.toml` |
| "error: No such environment" or missing `[flywayDesktop]` environments | Add `[flywayDesktop] developmentEnvironment` and `shadowEnvironment` and define both environments (can be in `flyway.user.toml`). Single-target, hand-written-migration projects cannot use `develop_migrations` / `develop_state` |
| Credentials in plaintext | Desktop's connection dialog writes credentials to TOML; use `${env.X}`, `${localSecret.X}` or a secrets manager |

MCP logs: `%localappdata%\Red Gate\Logs\Flyway` (Windows), `~/.local/share/Red Gate/Logs/Flyway` (Linux); retention `mcp.maxLogs`. 13.5.0 renamed tool `create_before_pull_snapshot` to `create_schema_model_checkpoint`. Owner: Dev; SE for setup.

## Flyway Insights (formerly Flyway Pipelines, preview)

### E18. Results not appearing in Insights
- **Likely causes (ranked):** (1) `publishResult` not true (default false; env `FLYWAY_PUBLISH_RESULT=true`); (2) TOML lacks `databaseType`, `id` (GUID) or `name`, or the project still uses `.conf` ("The service does not work with older flyway.conf files."); (3) Community edition (OSS ignores `publishResult` and `checkDriftOnMigrate` from 13.2.0); (4) expecting dry runs (not published from 13.7.0) or drift (published for any drift check only from 13.8.0; deploy results from 13.6.0); (5) `checkDriftOnMigrate` needs online auth (PAT or `auth`), not an offline permit, and needs `publishResult` (deprecated from Flyway 13.10.0, logs a warning); (6) PAT plus offline permit failed before 10.22.0.
- **Check:** dashboard at https://flyway.redgate.com (docs also cite flyway.red-gate.com); `-X` output of the migrate/deploy step.
- **Fix:** set the three TOML keys, `publishResult`, online licensing; allow outbound HTTPS to the dashboard host (specific endpoints unpublished, unverified).
- **Owner:** DevOps; Support if configured correctly and still missing.

## Sources
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/comparison-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/prepare-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/docker-error-codes
- https://documentation.red-gate.com/fd/licensing-164167730.html
- https://documentation.red-gate.com/fd/reference/commands/auth
- https://documentation.red-gate.com/fd/tutorial-personal-access-tokens-277579351.html
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://github.com/flyway/flyway/tree/main/flyway-core/src/main/java/org/flywaydb/core/internal/license (licensing message text, 13.8.0)
- https://documentation.red-gate.com/fd/reference/usage/network-troubleshooting
- https://productsupport.red-gate.com/hc/en-us/articles/360002374673-Licensing-update-URLs-to-add-to-your-AllowList-in-firewall
- https://documentation.red-gate.com/fd/reference/commands/generate
- https://documentation.red-gate.com/fd/reference/commands/prepare
- https://documentation.red-gate.com/fd/flyway-prepare-abort-on-warning-severity-277579115.html
- https://documentation.red-gate.com/fd/reference/commands/snapshot
- https://documentation.red-gate.com/fd/reference/commands/check/check-drift
- https://documentation.red-gate.com/fd/reference/commands/check/check-changes
- https://documentation.red-gate.com/fd/reference/commands/check/check-code
- https://documentation.red-gate.com/flyway/flyway-concepts/environments/shadow-and-build-environments
- https://documentation.red-gate.com/fd/create-database-provisioner-291931544.html
- https://documentation.red-gate.com/fd/backup-provisioner-277578935.html
- https://documentation.red-gate.com/fd/snapshot-provisioner-277578940.html
- https://documentation.red-gate.com/fd/docker-provisioner-277578938.html
- https://documentation.red-gate.com/fd/docker-compose-provisioner-346163424.html
- https://documentation.red-gate.com/fd/reference/usage/flyway-docker (custom image dependencies)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html
- https://documentation.red-gate.com/spaces/FD/pages/138347155 (MCP server troubleshooting)
- https://documentation.red-gate.com/fd/flyway-publish-result-setting-277579025.html
- https://documentation.red-gate.com/spaces/FD/pages/252281654 (Pipelines quickstart, CLI: databaseType/id/name, no .conf)
- https://documentation.red-gate.com/spaces/FD/pages/249987468 (Flyway Pipelines, renamed Insights)
- Field reports linked inline (Redgate community and KB)

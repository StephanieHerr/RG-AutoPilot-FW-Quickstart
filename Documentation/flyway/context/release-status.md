<!-- last-verified: 2026-10-26 | refreshed-by: weekly refresh routine -->

# Flyway release status

Single source for "latest/current" versions. Other files tag features inline, e.g. "(12.9+)". Re-check the two release-notes pages before quoting versions to a customer; engine releases land roughly weekly.

## Current

| Component | Latest | Released | Notes |
|---|---|---|---|
| Flyway Engine (CLI, Docker `redgate/flyway`, API, Maven/Gradle) | 13.11.1 | 2026-10-21 | Latest in the release notes when checked 2026-10-26 (13.11.0 and 13.11.1 both dated 2026-10-21). Redgate Maven repo metadata (`flyway-commandline` release) shows 13.11.1; Docker Hub `redgate/flyway:13.11.1` pushed 2026-10-22. The release notes no longer list 13.10.2 (listed on 2026-10-19) and never listed 13.10.3, although both are in the Maven metadata: the notes go from 13.10.1 straight to 13.11.0. CLI bundles its own JRE (Java 25 since 11.19.0). Docker images on JRE 25 since 13.6.0. |
| Flyway Desktop | 9.10.9 | 2026-10-22 | Bundles engine 13.11.1-rc3055 (checked 2026-10-26). |
| Previous engine major, last release | 12.11.0 | 2026-07-09 | 13.0.0 shipped 2026-07-20. |
| Engine 13.0.0 | 13.0.0 | 2026-07-20 | First 13.x. |
| Desktop 9.0.0 | 9.0.0 | 2026-02-03 | First Desktop 9 (bundled engine 12.0.1). |

Supported/patched major lines: **not stated** in the release notes or docs checked. Pattern observed: no 12.x release after 13.0.0 in the engine notes (Desktop 9.6.1 bundled a `12.12.0-rc` build that never appears as a public engine release). Treat only the latest 13.x as patched unless Redgate support says otherwise.

Verify edition at runtime: `flyway --version` prints e.g. `Flyway Enterprise Edition 12.4.0 by Redgate`; `flyway --version -outputType=json` returns `"edition" : "ENTERPRISE"`.

## Breaking and behaviour changes by version

Everything after 12.0.0 that could bite a customer upgrading. "API" = Java API / Maven / Gradle users only; CLI and Docker users can usually ignore those.

### 11 to 12 (12.0.0, 2026-01-28)

Official guide: "Flyway V12 - updating from V11" (see Sources).

| Change | Who is affected | Action |
|---|---|---|
| MongoDB JDBC driver removed; MongoDB only via Native Connectors (mongosh). Script migrations and custom regex `check -code` not yet supported there. | MongoDB users | Test on Native Connectors before upgrading. |
| `REDGATE_LICENSING_PERMIT_PATH` env var removed for the engine; use `FLYWAY_OFFLINE_PERMIT_PATH` / `offlinePermitPath`. | Offline-permit (air-gapped) CI | Rename the variable. Same file contents. Note: the Desktop licensing doc still mentions `REDGATE_LICENSING_PERMIT_PATH` for Flyway Desktop offline licensing. |
| `plugin` / `flyway.plugins` config namespace removed. | Old configs | Move settings to current namespaces. |
| `cleanOnValidationError` removed. | Old configs | Remove; see deprecation page. |
| Code analysis: `check.majorRules`, `minorRules`, `majorTolerance`, `minorTolerance` removed; `passOnRegexMatch` regex field removed; default Redgate regex ruleset no longer shipped (replaced by SQLFluff rules); SQLFluff < 1.3 unsupported. | `check -code` users | Move severity config into SQLFluff config. Community users on self-installed SQLFluff must upgrade it; Enterprise has a built-in SQLFluff. |
| Reports no longer keep a chronological history (no timestamp dropdown). | Anyone relying on report history | Archive reports per run. |
| Redgate Compare now uses .NET 10. | Custom Docker images with Enterprise features | Ensure .NET 10 OS dependencies. |
| `CommandExtension` signature changed; `CompositeResult` is now a record. | API / plugin authors | Rebuild extensions. |

### 12.x point releases

| Version | Change | Impact |
|---|---|---|
| 12.0.2 | `check` honours environment-specific `cleanDisabled` override when build env has no provisioner. | Build env needs `provisioner` or `cleanDisabled = false`. |
| 12.0.2 | Oracle `snapshot` without `schemas` uses the default schema if set. | Set `schemas` explicitly for Oracle snapshots. |
| 12.1.0 | Snapshot history limit default changed to 5. | More rows kept in `flyway_snapshot_history`. |
| 12.1.0 | SQL Server comparison option `IgnoreSynonymDependencies` removed (also removed in Desktop 9.1.1). | Remove from TOML if present. |
| 12.2.0 | "Code Analysis" renamed "Code Review" in check output; regex engine no longer converts line endings before applying rules. `check -code` also writes SARIF 2.1.0. | Pipelines parsing output text; regex rules sensitive to CRLF. |
| 12.5.0 | `initSql` deprecated; use `afterConnect` callback. | Plan migration off `initSql`. |
| 12.5.0 | Flyway Secret Manager feature no longer available under Teams license. | Teams customers using secrets managers. |
| 12.5.0 | Cassandra JDBC approach deprecated; Native Connectors added (default from 12.10.0). | Cassandra users. |
| 12.6.0 | `auth` defers to existing license providers; license output reports acquisition method. Obsolete-only config errors now `ObsoleteConfigurationParametersException`. Mixing scoped and unscoped namespaces on the CLI now allowed. | Minor. |
| 12.6.2 | `${env.VAR}` resolver works in all config parameters, not just environment connection properties. | Enables env vars anywhere in TOML. |
| 12.7.0 | API: `flyway-proprietary` module required for Redgate proprietary features. | API users. |
| 12.8.0 | API: a Flyway Licensing module dependency required to be recognised as Redgate edition. Offline permit expiry warning within 30 days. | API users; air-gapped CI. |
| 12.8.1 | Fix: `FLYWAY_TOKEN` / `FLYWAY_EMAIL` not recognised for PAT auth. | Avoid 12.8.0 for PAT-licensed CI. |
| 12.9.0 | CLI exits with a distinct exit code derived from the error code when a FlywayException is thrown. `check.driftResolutionFolder` added. | CI scripts that test `exit code == 1`. Test for non-zero instead. |
| 12.10.0 | Preview `docker` provisioner renamed `docker-compose` (compose-file configs auto-forwarded). New "smart" `docker` provisioner with `keepAlive`. Missing callback locations now skipped. `outOfOrder` reported at info level. | Rename compose-based provisioners. |
| 12.11.0 | `auth` without `-IAgreeToTheEula` starts an interactive EULA flow (non-CI). Legacy compose-file config of `docker` provisioner deprecated (warning). | Always pass `-IAgreeToTheEula` in scripts. |

### 12 to 13 (13.0.0, 2026-07-20)

The 13.0.0 release notes list **no "Breaking changes" section**. Items in 13.0.0: Oracle comparison option `IncludeOnlineIndexCreation` (new feature, not breaking; TOML `[redgateCompare.oracle.options.behavior] includeOnlineIndexCreation`, default false); `id` per difference in check drift/changes JSON; Flyway MCP server; dedicated docker EULA error code.

Announced for V13 in the blog "Looking forward to Flyway V13" (2026-04-28), status as of 2026-09-25:

| Announced | Current doc status |
|---|---|
| Minimum Java 21 (from 17). Affects API, Maven/Gradle, plugin authors, own-JRE CLI users. | Not mentioned in 13.x release notes (unverified whether enforced). Treat Java 21+ as required for API/plugin use on 13.x. |
| `initSql` removed. | Still documented as **deprecated, not removed**. |
| `createSchema` callback renamed `beforeCreateSchema`. | Callback reference lists `createSchema` as deprecated alongside `beforeCreateSchema` (rename landed in 11.x as a deprecation). |

### 13.x point releases

| Version | Change | Impact |
|---|---|---|
| 13.1.0 | `environments_<name>_<setting>` and `flyway_<setting>` env var prefixes accept any casing. Fix: `afterConnect` not firing on the migration connection; several `after*OperationFinish` SQL callbacks never ran. | If relying on `afterConnect`, use 13.1.0+. |
| 13.2.0 | **Breaking:** JSON results with timestamps include a UTC offset; reports not compatible with earlier versions; API `getTimestamp/setTimestamp` use `OffsetDateTime`. | Pipelines parsing JSON timestamps. |
| 13.2.0 | OSS/Community no longer recognises `publishResult` / `checkDriftOnMigrate`. CockroachDB is its own module (API). Fix: environment-level settings (custom history table, default schema) lost when switching environment. | Community configs with those keys. |
| 13.4.0 | CLI and Docker automatically use the OS proxy. Disable with `FLYWAY_USE_SYSTEM_PROXIES=false`. (Default reversed in 13.9.0: now opt-in.) TOML support moved to `flyway-core-utilities` (API). | Proxy-restricted networks. |
| 13.5.0 | Debug logs (`-X`) show final config values and their origin. API: `jackson-databind` optional, JSON in `flyway-core-utilities`. MCP tool `create_before_pull_snapshot` renamed `create_schema_model_checkpoint`. | Useful for config debugging. |
| 13.6.0 | `docker` provisioner rejects `url`/`user`/`password` on its environment. Cached `flyway auth` credentials survive future upgrades, but **upgrading to 13.6.0 requires running `flyway auth` once more**. Docker images on JRE 25. JSON report has top-level `schemaVersion`. | Re-auth dev machines after upgrade. |
| 13.7.0 | Generated migration filename timestamps are UTC. Dry runs no longer publish migrate events as deployments. | Minor. |
| 13.8.1 | Fix: Cassandra operations could hang when using Native Connectors mode. RgCompare upgraded to 1.66.2.5896. | Cassandra users on Native Connectors (the default since 12.10.0): use 13.8.1+. |
| 13.8.0 | Connections report application name "Redgate_Flyway" instead of "Flyway by Redgate" where supported (note: the same notes also say PostgreSQL/CockroachDB now report "Flyway by Redgate"; contradictory, check actual value). pgjdbc `assumeMinServerVersion=9.1` set. Drift results published to Flyway Pipelines for any drift check when `publishResult` is on. | DBAs filtering sessions by program/application name. |
| 13.9.0 | **Behaviour change:** `FLYWAY_USE_SYSTEM_PROXIES` now defaults to `false`, so OS proxy inheritance is opt-in (reverses the 13.4.0 default). Flyway Report moved to a new implementation, on by default; set env var `FLYWAY_NEW_REPORTS=false` for the legacy one. `init` no longer writes the root `redgateCompare.filterFile` setting for SQL Server and Oracle projects. Oracle comparison option `preserveIdentifierCase` (Preview). Fixes: no longer reports "successfully rolled back" when the rollback itself threw; Oracle parser handles `END CASE` / `END LOOP` / `END IF` split across two lines. | Networks that relied on 13.4.0 to 13.8.x picking up the OS proxy: set `FLYWAY_USE_SYSTEM_PROXIES=true` or explicit `JAVA_ARGS` proxy properties. Anything parsing report output: test the new report. |
| 13.10.0 | `checkDriftOnMigrate` and `flywayServicePublish.publishReport` deprecated (log a warning). Plugin parameters such as `undoSqlMigrationPrefix` and `check.buildEnvironment` can be set per environment under `[environments.<name>.flyway]` (the environment Flyway namespace page still lists `undoSqlMigrationPrefix` as excluded when checked 2026-10-12 and 2026-10-19). New `lakebase` resolver (interactive Databricks sign-in for Lakebase). MCP `generate_migrations` accepts `generateUndoScripts`. Fix: SQL Server clean mode configuration could fail operations on databases without clean mode support. RgCompare 1.66.4.5964. | Flyway Insights users with `checkDriftOnMigrate`: plan to remove it (replacement not stated in the notes). |
| 13.10.1 | Flyway prints the name of the environment it is working on, and warns when environment names differ only by case. New `databricks` resolver (`${databricks.tokenCachePassPhrase}`) for browser-based OAuth to Databricks. Snowflake connections identify as `Redgate_Flyway` unless `application` is set, and URL-based Snowflake connections no longer fail on Java 16+ without `JDBC_QUERY_RESULT_FORMAT=JSON`. Fixes: Native Connectors `baseline` script shown as `Pending` instead of `Ignored` (Issue 4292); Redshift and Databricks connections no longer modify (or fail on immutable) `jdbcProperties`; `init` in the OSS edition reports that Redgate Edition is required instead of "Invalid flag: init". | Check for environment names that differ only by case. |
| 13.10.2 | RgCompare upgraded to 1.67.0.6161 (only change listed when checked 2026-10-19). The 13.10.2 entry is no longer in the release notes (checked 2026-10-26). | None stated. |
| 13.11.0 | **Behaviour change:** `info` honours `baselineOnMigrate`, so migrations at or below `baselineVersion` show as `Below Baseline` or `Ignored` instead of `Pending`. **Behaviour change:** the `docker` provisioner builds SQL Server and PostgreSQL environments in a dedicated `flyway` database and Oracle environments in a dedicated `FLYWAY` schema, instead of `master`, `postgres` and `SYSTEM`. Code review profiles can exclude individual regex rules by rule code; Code Review reports show the line that has a violation. Command-line errors suggest running with `-X`. Docker images upgrade ca-certificates at build time. Fix: PostgreSQL session role changes made in an `afterConnect` callback (e.g. `SET ROLE`) now persist into migrations, matching `initSql` (Issue 4286). RgCompare 1.68.1.6299. | Scripts or dashboards that count `Pending` in `info` output. Anything that assumed the docker provisioner used `master`, `postgres` or `SYSTEM`. PostgreSQL users moving from `initSql` to `afterConnect` with `SET ROLE`: use 13.11.0+. |
| 13.11.1 | **Security:** distrusted CA certificates are now blocked in the Java trust store of the bundled JREs and Docker images. | Connections or licensing calls that rely on a certificate chaining to a CA the JRE now distrusts could start failing TLS validation (inferred; not stated in the notes). |

### Flyway Desktop 9

| Version | Change |
|---|---|
| 9.0.0 | **Breaking:** preview Redgate Clone provisioner and resolver removed from connection dialogs. Dedicated Deploy page for migrations projects. `check.major/minor*` removed from advanced params. |
| 9.5.0 | State vs migrations deployment choice moved from project creation to the Deployment page. |
| 9.6.3 | New Databricks Lakebase type; existing Databricks type renamed "Databricks Lakehouse (Unity Catalog)". |
| 9.10.0 | Deploying now saves a snapshot by default (Desktop). In-app warning that Oracle 11g support will be removed in a future major release. |
| 9.10.2 | Publishing to Flyway Insights configurable from project settings. AI-generated migration descriptions capped at 50 characters (avoids Windows "path too long"). |
| 9.10.3 | Desktop log files older than a month are deleted when Desktop starts (change under Settings > Log retention). |
| 9.10.4 | Preview Oracle option to preserve the case of schema names in deployment scripts. Schema model page badges objects with uncommitted changes. |
| 9.10.5 | Surrounding double quotes removed from JDBC URLs pasted into connection dialogs (for example from the Snowflake website). Progress logs shown when a Flyway command completes on the Migrations page. Bundles engine 13.10.1-rc2971. |
| 9.10.6 | Databricks Lakebase and Lakehouse connections can sign in interactively through the browser (Lakehouse: "OAuth Interactive Sign-In" in the new Authentication dropdown). Bundles engine 13.10.1-rc2997. |
| 9.10.7 | Object level history out of preview and GA (released 2026-10-14; the entry had no version number when checked 2026-10-19). Bundles engine 13.10.1-rc2997. The roadmap still labels it Preview (checked 2026-10-26). |
| 9.10.8 | Schema model history (preview): recent commits across the whole schema model, filterable to individual objects. Snowflake connection dialog has dedicated fields for server hostname, warehouse, database, role and authentication. Development and target connections ask for "Ok to erase and rebuild" when using a provisioner that erases the database (Backup, Snapshot or Create Database). Bundles engine 13.11.0-rc3035. |
| 9.10.9 | Library update only: bundles engine 13.11.1-rc3055. |

## Announced / not yet released

From the Flyway roadmap page ("What's next", checked 2026-10-26) unless noted.

| Item | Status |
|---|---|
| Advanced capabilities for Databricks (Lakehouse Unity Catalog and Lakebase) | Moved off "What's next" by 2026-10-12; roadmap now lists it under "What's new" 2026 as Preview (Desktop 9.6.0 public preview) |
| Advanced capabilities for Snowflake (Snowflake and Snowflake Postgres) | Moved off "What's next" by 2026-10-12; roadmap now lists it under "What's new" 2026 as Preview (Desktop 9.9.0 public preview) |
| Object existence checks for Oracle | Moved off "What's next" by 2026-10-12; listed under "What's new" Oracle "2025/2026, in continuous development" (Desktop 9.5.3 preview option) |
| Native Connectors for Oracle | In development, currently Preview |
| MongoDB support | In development, currently Preview |
| Flyway Insights: Key DORA metrics and Business value (ROI) dashboard | Roadmap "What's new" 2026, Preview (was "Flyway Key Metrics Dashboard, private preview" on 2026-09-29) |
| Flyway Insights: Operational Deployment Dashboard improvements (better estate views; v1 in Preview) and compliance view | In development ("and compliance view" new on the roadmap 2026-10-26) |
| AI integrations (md files and skills) | In development |
| Automate deployment page improvements | No longer on the roadmap page (checked 2026-10-12); status not stated |
| Researching: run code reviews when saving to the schema model (new 2026-10-12), additional AI capabilities, pre-deployment impact analysis, multi-target drift reporting and resolution, deeper Redgate Monitor integration, enhanced audit, full comparison for Microsoft Fabric and other DBs | Researching, no dates |
| Flyway MCP Server | Roadmap "What's new" 2026 labels it Preview; engine ships `mcp` command since 13.0.0 |
| Flyway Pipelines (`publishResult`, `checkDriftOnMigrate`, `pipelineId`) | Docs label Preview |
| Provisioners: docker, docker-compose, backup, snapshot, create-database | Docs label Preview (Desktop 9.6.5 dropped "preview" label for Backup and Create empty in the UI) |

Oracle roadmap: Oracle 11g support to be dropped in the **next major release** of Flyway Enterprise, Schema Compare/Data Compare/Source Control for Oracle, expected **end of 2026 or early 2027** (supported databases page). An older blog said "tentatively September 2025"; the docs page supersedes it.

## Deprecations and end of support

| Item | Status | Replacement |
|---|---|---|
| `initSql` (environment setting) | Deprecated 12.5.0; removal announced for V13, not yet removed | `afterConnect` callback (`afterConnect.sql`) |
| `createSchema` callback | Deprecated | `beforeCreateSchema` |
| `licenseKey` (legacy FL01... keys) | Deprecated, "will be removed in a future release" | PAT (`email`+`token`), `auth`, offline permit |
| `docker` provisioner configured with compose keys | Deprecated 12.11.0, forwarding "will be removed in a future release" | `docker-compose` provisioner |
| `check.filterFile` | Supported for backwards compatibility, "will be deprecated" | `[redgateCompare] filterFile` / per-DB `filterFile` |
| Global secrets namespaces `[flyway.vault]`, `[flyway.dapr]`, `[flyway.gcsm]` | Per-environment resolvers "preferred" | `[environments.X.resolvers.*]` |
| `[flywayDesktop] schemaModel` | Deprecated | `[flyway] schemaModelLocation` |
| Cassandra via JDBC | Deprecated 12.5.0 | Native Connectors (default 12.10.0+) |
| `checkDriftOnMigrate` | Deprecated 13.10.0, logs a warning. Flyway namespace page lists it under "Deprecated settings" | Not stated |
| `flywayServicePublish.publishReport` | Deprecated 13.10.0, logs a warning | Not stated |
| Redgate Clone provisioner/resolver | Removed from Desktop 9.0; Clone docs marked deprecated (12.0.1) | Docker / backup / snapshot provisioners |
| Flyway Teams edition | Closed to new customers since 14 May 2025; existing customers can renew | Enterprise |
| Oracle 11g | Ends next major, expected end-2026/early-2027 | Upgrade Oracle |
| Removed in 12.0 | `plugin` namespace, `cleanOnValidationError`, `REDGATE_LICENSING_PERMIT_PATH`, `check.major/minor*`, `passOnRegexMatch`, MongoDB JDBC | See 11 to 12 table |

## Recent releases (last 6 months, SE-relevant only)

| Date | Release | SE-relevant items |
|---|---|---|
| 2026-10-22 | Desktop 9.10.9 | Bundles engine 13.11.1-rc3055 (no other changes listed). |
| 2026-10-21 | Engine 13.11.0, 13.11.1 | `info` shows `Below Baseline`/`Ignored` with `baselineOnMigrate`; docker provisioner uses a dedicated `flyway` database / `FLYWAY` schema; profiles can exclude regex rules; report shows the violating line; PostgreSQL `SET ROLE` in `afterConnect` persists; 13.11.1 blocks distrusted CA certificates in bundled JREs and Docker images. |
| 2026-10-20 | Desktop 9.10.8 | Schema model history (preview); Snowflake connection dialog fields; "Ok to erase and rebuild" prompt for erasing provisioners. |
| 2026-10-15 | Engine 13.10.1, 13.10.2 | `databricks` resolver for browser OAuth; environment name printed and case-only name clash warning; Snowflake `Redgate_Flyway` application name and Java 16+ URL fix; Native Connectors baseline `Ignored` fix. 13.10.2 was an RgCompare upgrade only (entry since removed from the notes). |
| 2026-10-14 | Desktop 9.10.6, 9.10.7 | Interactive browser sign-in for Databricks Lakehouse and Lakebase connections. 9.10.7: object level history GA. |
| 2026-10-12 | Desktop 9.10.5 | Quotes stripped from pasted JDBC URLs; Migrations page progress logs. |
| 2026-10-08 | Engine 13.10.0 | `checkDriftOnMigrate` deprecated; `lakebase` resolver; per-environment plugin parameters; MCP `generateUndoScripts`. |
| 2026-10-06 | Desktop 9.10.4 | Oracle preserve schema name case (preview); uncommitted-changes badge on schema model. |
| 2026-10-01 | Engine 13.9.0, Desktop 9.10.3 | OS proxy inheritance now opt-in (`FLYWAY_USE_SYSTEM_PROXIES=true`); new Flyway Report implementation; Oracle `preserveIdentifierCase` (Preview); Desktop log retention (one month default). |
| 2026-09-29 | Desktop 9.10.2 | Configure Flyway Insights publishing in project settings; shorter AI migration descriptions. |
| 2026-09-29 | Engine 13.8.1 | Fix for Cassandra operations hanging with Native Connectors. |
| 2026-09-24 | Engine 13.8.0, Desktop 9.10.1 | App name "Redgate_Flyway"; Snowflake snapshot history; docker provisioner localhost fix; object-level history diff settings. |
| 2026-09-22 | Desktop 9.10.0 | Deploy saves snapshot by default; Oracle 11g removal warning. |
| 2026-09-15 | Engine 13.7.0, Desktop 9.9.0 | MCP Test Migrate tool and 3-sided diff; Snowflake advanced capabilities public preview (Desktop). |
| 2026-09-10 | Engine 13.6.0 | `check.code.profile(s)` incl. built-in `schemaModel` profile; `deploy` publishes to Flyway Pipelines; dry run report deployment overview; docker provisioner hardening; re-run `flyway auth` after upgrade. |
| 2026-09-03 | Engine 13.5.0 | `-X` shows config value origins; cleaner dry run scripts. |
| 2026-08-26 | Engine 13.4.0 | OS proxy auto-used (`FLYWAY_USE_SYSTEM_PROXIES=false` to disable); default reversed in 13.9.0. |
| 2026-08-11 | Desktop 9.7.0 | Code review policies configurable in Desktop project settings. |
| 2026-08-06 | Engine 13.2.0, Desktop 9.6.5 | JSON timestamps with UTC offset (breaking); Oracle 23+ docker fix; Automated deployment page public preview. |
| 2026-07-23 | Engine 13.1.0 | Databricks Lakebase preview; Databricks snapshot history; `afterConnect` fix; `deploy` execution time. |
| 2026-07-20 | Engine 13.0.0 | Flyway MCP server; Oracle `includeOnlineIndexCreation`; drift/changes JSON difference ids. |
| 2026-07-09 | Engine 12.11.0 | PostgreSQL `disableConstraintsForStaticData`; better `-h` help; faster cold start. |
| 2026-07-06 | Desktop 9.6.0 | Databricks advanced capabilities public preview. |
| 2026-06-30 | Engine 12.10.0 | Smart `docker` provisioner with `keepAlive`; `docker-compose` rename; working-directory hint in "location not found". |
| 2026-06-18 | Engine 12.9.0 | Exit codes derived from error codes; `check.driftResolutionFolder`. |
| 2026-06-04 | Engine 12.8.0 | Offline permit expiry warnings (30 days). Use 12.8.1+ for PAT env vars. |
| 2026-05-29 | Engine 12.7.0 | Custom SQLFluff rules for `check -code`. |
| 2026-05-18 | Desktop 9.5.0 | GitHub Actions workflows with manual approval on Automated Deployment page. |
| 2026-05-08 | Engine 12.6.0 | Native Connectors for `deploy`; Oracle parser `IF EXISTS` / `IF NOT EXISTS`. |
| 2026-04-29 | Desktop 9.4.2 | Automated Deployment page generates GitHub Actions workflows. |
| 2026-04-27 | Engine 12.5.0 | Azure Key Vault resolver; `initSql` deprecated. |

## Sources

- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/flyway-v12-updating-from-v11-329777771.html
- https://documentation.red-gate.com/flyway/flyway-blog/looking-forward-to-flyway-v13
- https://documentation.red-gate.com/fd/reference/callback-events
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-init-sql-setting
- https://documentation.red-gate.com/fd/reference/usage/command-line
- https://documentation.red-gate.com/fd/supported-databases-and-versions-143754067.html
- https://www.red-gate.com/blog/flyway-and-optimized-partition-management-for-oracle-databases
- https://www.red-gate.com/products/flyway/roadmap/
- https://documentation.red-gate.com/fd/licensing-164167730.html
- https://documentation.red-gate.com/fd/docker-compose-provisioner-346163424.html
- https://documentation.red-gate.com/fd/reference/usage/network-troubleshooting (13.9.0 proxy default)
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace (deprecated settings)
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-flyway-namespace
- https://www.componentsource.com/product/flyway/licensing (Teams closure date, via search snippet; page blocks direct fetch)
- https://hub.docker.com/r/redgate/flyway/tags (Docker tag versions)
- https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/maven-metadata.xml (Maven release version)

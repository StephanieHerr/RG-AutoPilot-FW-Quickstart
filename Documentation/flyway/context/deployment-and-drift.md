<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway deployment workflows, snapshots and drift

Scope: state-based vs migrations-based deployment, the `prepare` / `deploy` / `snapshot` / `check` commands, snapshot storage, drift detection and resolution, Flyway Pipelines (now Flyway Insights), and a recommended pipeline order. Parameter names are from the public command reference. For full parameter lists use `flyway-cli-reference.md`.

## 1. The two deployment approaches

| | State-based | Migrations-based |
|---|---|---|
| Source of truth | Schema model (one file per object, plus static data) | Ordered migration scripts (V, R, U, B prefixes) |
| How the deploy script is produced | Generated at deploy time by Redgate comparison (`prepare -source=schemaModel`) | Written or generated at development time, stored in Git |
| Control | Flyway decides order and SQL. Cannot express renames, splits, NOT NULL without default on populated tables, data motion | Full control. Edit, reorder, add data changes, script migrations, callbacks |
| Audit | Object history in Git; the deploy script itself is not kept unless you archive it | Scripts in Git and in `flyway_schema_history` on every target; checksum validation |
| Drift behaviour | Deploy reverts drift unless it is filtered out | Migrate ignores drift unless pending scripts touch drifted objects |
| Rollback | Revert to a previous state (snapshot or schema model) | Undo scripts (`U`) or fix-forward, or snapshot-generated scripts |
| Edition | Manual: Teams. Automated (CLI pipelines): Enterprise | Community runs migrations; Enterprise generates them |
| Docs guidance | Start here if few transactional data changes | Recommended for continuous delivery and complex changes |

**Combined approach** (Redgate's recommended model for Enterprise): state-based development (developers share changes through the schema model), migrations-based deployment (generated, reviewable scripts go to downstream environments). Decouples sharing from deployment ordering.

Desktop note: the state vs migrations choice moved from project creation to the Deployment page (Desktop 9.5.0). A project can be switched later.

## 2. Command summary

| Command | Edition | What it does | Key inputs | Outputs |
|---|---|---|---|---|
| `prepare` | Enterprise | Generates a deployment script from a schema model, another environment, a `diff` artifact, or pending migrations | `-source=schemaModel` / `env:<id>` / `migrations`, `-target`, `-scriptFilename`, `-undoFilename`, `-types=deploy,undo`, `-abortOnWarningSeverity`, `-force`, `-artifactFilename` + `-changes` | SQL script (default name used when chained with deploy), JSON with `differences` and `warnings` |
| `deploy` | Enterprise | Executes any SQL script against a target, optionally saves a snapshot | `-scriptFilename`, `-environment`, `-saveSnapshot`, `executeInTransaction`, `batch` | JSON with `scriptExecuted`, `executionTime`; snapshot row if saved |
| `snapshot` | Enterprise | Captures a binary schema snapshot (no table data) | `-source` (env id, `schemaSnapshot`, `migrations`, empty), `-filename` (file path or `snapshotHistory:<name>`), `-buildEnvironment`, `-buildVersion`, `-buildCherryPick`, `-rebuild`, `-historyTable`, `-historyLimit` | Snapshot file or snapshot history table row |
| `check -changes` | Enterprise | Report of objects that the pending deployment will change | Build environment (`-buildEnvironment` or `-buildUrl`), or snapshots (`-deployedSnapshot` + `-nextSnapshot`), or `-changesSource=schemaModel` | HTML + JSON report |
| `check -drift` | Enterprise | Detects changes made to a target outside Flyway | Embedded snapshot (default), `-deployedSnapshot` file, or `-buildEnvironment`; `-failOnDrift`, `-generateDriftResolutionScripts`, `-driftResolutionFolder`, `-filterFile` | HTML + JSON report, optional drift-resolution scripts |
| `check -dryrun` | Teams (legacy) and Enterprise | Dry-run SQL of what migrate would run (same as migrate dry run) | `-dryRunOutput` | SQL file, HTML + JSON report |
| `check -code` | Community (own SQLFluff); Enterprise adds bundled SQLFluff, Redgate rules, regex rules, fail-on-error | See `code-analysis.md` | HTML, JSON, SARIF (12.2+) |

Notes:
- Comparison options, filters and static data config for `prepare` can only be set in TOML, not overridden on the command line.
- `prepare -source=migrations` does not handle Java or non-SQL migrations and does not run callbacks. It is equivalent to a migrate dry run.
- `prepare -source=schemaModel`: if a target schema is not in the schema model, the script will drop it. Set `schemaModelSchemas` when schemas differ.
- `prepare -source=schemaModel` fails with a clear error if the schema model folder does not exist (12.5+).
- `deploy` succeeds with a warning if the script does not exist, so `prepare deploy` chaining works when there are no changes (11.3.2+).
- `deploy` supports `errorOverrides` (11.13+), for example SQL Server PRINT handling.
- `deploy` supports Native Connectors mode (12.6+).
- `prepare` and `deploy` were added in 11.0.0.
- Snapshots are no longer saved during dry runs of migrate, undo or deploy (12.1.1+).
- If both `-drift` and `-changes` are passed, drift always runs first (11.20.1+).
- `check drift` and `check changes` JSON includes an `id` per difference (13.0+).
- Phase-level progress for drift, changes and dryrun when `outputProgress` is enabled (12.9+).
- PowerShell can reject dotted arguments (`Invalid argument: -check`). Quote them, for example `"-check.buildEnvironment=build"`, or use namespace short-circuiting.

## 3. Build and shadow environments

- Same concept. "Shadow" is the name Desktop uses for the build environment in the generate-migrations workflow.
- Holds schema and static data only. Flyway may clean, drop or re-provision it at any time. Never point it at a database with real data.
- Required for: `check -changes` from migrations, `check -drift` option 3, `snapshot -source=migrations`, Desktop migration generation.
- Since 11.0.0 the build environment used by `check` must have a `provisioner` set or `cleanDisabled=false`. Otherwise: `ERROR: Clean is disabled - unable to configure clean provisioner`. Error code `CHECK_BUILD_NO_PROVISIONER`.
- `check -changes` assumes Flyway is the only party changing the build environment. Do not share it between concurrent pipelines or developers.
- Provisioners: `clean`, `create-database`, `backup`, `snapshot`, `docker` (auto-detecting, preview), `docker-compose` (preview), `clone` (Redgate Clone, deprecated). See `desktop-reference.md`.

## 4. Snapshots

| Item | Detail |
|---|---|
| What | Binary file describing schema structure at a point in time. No table data. Taken from a database, schema model folder, migrations (via build env) or empty source |
| Uses | Drift analysis, change reports, snapshot provisioner, ad hoc rollback and roll-forward script generation |
| File storage | Any path: `-filename=C:\snapshot.json`. Parent directories are created. S3 buckets supported for writing and reading in drift checks (11.17.1+) |
| Embedded storage | `flyway_snapshot_history` table in the target, created automatically. Rename with `snapshot.historyTable`. Schema: `defaultSchema`, else first entry in `schemas`, else connection default. Tablespace via `tablespace` |
| Embedding on deploy | `migrate.saveSnapshot`, `undo.saveSnapshot`, `deploy.saveSnapshot` (default location is the history table) (11.17+) |
| History limit | `snapshot.historyLimit`. Default 5 (12.1+). Older concept page still says 1 |
| Naming | `-snapshot.filename="snapshotHistory:1.0.0_release"`. Auto-saved rows get non-unique names such as "Snapshot following deployment" |
| References | `snapshotHistory:current`, `snapshotHistory:previous`, `snapshotHistory:<name>` |
| Version column | Highest applied migration version when source is a database; build version when source is migrations; null for schema model or empty. Informational only |
| Size limits (after compression) | SQL Server VARBINARY(MAX) 2 GB; Oracle BLOB 4 GB; MySQL LONGBLOB 2 GB; PostgreSQL BYTEA 1 GB |
| Oracle | Set environment `schemas` when snapshotting. New snapshot history tables get a synonym so they can be referenced unquoted (12.0.1+), only when the name has lowercase characters (12.6+) |
| Other DBs | Snapshot history supported on Databricks (13.1+) and Snowflake (13.8+) |
| Desktop | Deploying saves a snapshot by default (Desktop 9.10.0) |

Rollback using snapshot history (state-based):
```
flyway diff -source=snapshotHistory:previous -target=production
flyway prepare -scriptFilename="D__rollback.sql"
flyway deploy -scriptFilename="D__rollback.sql" -environment=production
```
Snapshots cover schema only. Review generated scripts for static and transactional data effects.

## 5. Drift detection

### How it works

| Option | Mechanism | Works for | Detects | Trade-offs |
|---|---|---|---|---|
| 1. Embedded snapshot (recommended) | Save snapshot into `flyway_snapshot_history` on every deploy; `check -drift -environment=prod` compares live DB to it | State and migrations | Drift since last deployment | Easiest, fastest, least config error. Needs write access to create the table |
| 2. Snapshot file | Same, but `-deployedSnapshot=<file>` persisted between runs (artifact store, share) | State and migrations | Drift since last deployment | You must persist and retrieve the file |
| 3. Build environment | Snapshot target, clean build, apply the target's applied migrations to build, compare | Migrations only | All drift relative to migrations, including pre-existing | Slower; needs build environment |

- First deployment: no embedded snapshot yet. Drift check succeeds with a warning so the first run is not a special case (11.17+).
- Running `check -drift` against a database with no snapshot history table was fixed in 11.19.0.
- Filters: drift uses the project comparison config. Override with `check.filterFile`. Oracle schema history table synonyms no longer show as drift (12.0.3+).
- `failOnDrift` returns non-zero exit (`CHECK_DRIFT_DETECTED`). Chained verbs still run after a failOnDrift error, so run the next verb as a separate step.
- Redgate Monitor can alert on drift independently of pipelines.

### Drift resolution scripts (Enterprise CLI 11.20.1+, Desktop 8.7.5+)

`check.generateDriftResolutionScripts` (default true) writes, when drift is found:

| File | Purpose |
|---|---|
| `revertDrift.sql` | Run against the drifted target to remove drift: `flyway deploy -scriptFilename="drift-resolution/revertDrift.sql" -environment=production` |
| Incorporate script | Apply upstream to bring drift into version control. With migrations, generated as the next versioned migration (for example `V1.3__incorporateDrift.sql`). SQL Server version includes existence checks so it is idempotent |
| Filter file | SQL Server `Filter.scpf`, Oracle `IgnoreRules.scpf`. Existing filter plus drift exclusions. SQL Server and Oracle only |

- Folder: `check.driftResolutionFolder`, default `drift-resolution` under the working directory (12.9+). Existing contents are deleted and regenerated each time.
- Generation failures no longer fail `check -drift` (12.10+).
- Folder path serialises as an absolute path in JSON (12.1+). Report and folder names included in JSON when `failOnDrift` fails (12.0.3+).
- Desktop: `check.driftResolutionFolder` settable as an advanced parameter on the Migrations page (Desktop 9.5.8).

### Choosing a resolution

| Choice | State-based | Migrations-based |
|---|---|---|
| Incorporate (drift is valid) | Apply incorporate script to dev, save to schema model, commit, redeploy | Add incorporate migration; make it idempotent or mark applied on the drifted target with `migrate -cherryPick=<ver> -skipExecutingMigrations=true`; optionally re-snapshot target |
| Revert (drift is invalid) | Just deploy; deployment reverts drift, or run `revertDrift.sql` | Run `revertDrift.sql`, then deploy |
| Accept and re-snapshot | Does not help: deploy still reverts unless filtered | Take a new snapshot. Not recommended for production |
| Ignore | Only by filtering | Safe only if pending migrations do not touch or depend on drifted objects. Prefer generated filter file |

## 6. Flyway Pipelines (renamed Flyway Insights)

Status: Redgate renamed Flyway Pipelines to **Flyway Insights** on 10 September 2026. Docs pages still say "Pipelines" and are being updated. Setting names (`publishResult`) are unchanged.

| Item | Detail |
|---|---|
| What | Redgate-hosted SaaS dashboard at https://flyway.red-gate.com (Insights banner links https://flyway.redgate.com) |
| Views | Deployments (what version is where, success, duration, drift alerts) and Deployment metrics (DORA: deployment frequency, lead time, change failure rate, time to restore, rework rate) in public preview. Business value (ROI) view announced as coming soon |
| Edition | Enterprise (and Enterprise trial). OSS no longer recognises `publishResult` (13.2+) |
| Opt-in | Nothing is sent by default. Enable per project |
| What is published | `migrate` results; `deploy` results (13.6+); drift results for any drift check when `publishResult` is on (13.8+; 13.7 fixed publishing when it was false) |
| Data | Project schema and environment data sent to Redgate, hosted on Azure and AWS, governed by Schedule 2 of the Master Subscription EULA |

Setup (from quickstart):
1. Create a Personal Access Token at Redgate's PAT site (tokens are shown once).
2. Set in TOML (preferred) or environment variables:
```toml
[flyway]
email = "${env.FLYWAY_EMAIL}"
token = "${env.FLYWAY_TOKEN}"
publishResult = true
```
   Environment variable form: `FLYWAY_EMAIL`, `FLYWAY_TOKEN`, `FLYWAY_PUBLISH_RESULT=true`.
3. Run the pipeline with at least one pending migration, then view at the dashboard.

- `publishResult` default false. Publishing to Flyway Insights can be configured from Desktop project settings (Desktop 9.10.2); earlier Desktop versions could not set it in the UI but honoured it.
- The quickstart also shows `checkDriftOnMigrate`; OSS dropped it in 13.2. It is deprecated from Flyway 13.10.0 (logs a warning) and listed under "Deprecated settings" on the Flyway namespace page; the "what information is used" page marks the schema snapshots it sends as "Deprecated - only for Flyway Pipelines". `flywayServicePublish.publishReport` is also deprecated (13.10.0). Do not add either to new configs.
- Treat the PAT as a secret. Do not commit it.
- Known historical fix: publishing with a PAT plus an offline permit failed before 10.22.0.

## 7. Recommended pipeline stage order

Based on Redgate's "common deployment scripts" pages. Run each step as its own pipeline step (chained verbs continue after failOnDrift / failOnError).

### Migrations-based
| Stage | Command |
|---|---|
| CI build (per PR) | `flyway check -code "-check.code.failOnError=true"` then `migrate` against a clean build DB (validates scripts deploy) |
| Pre-deploy: drift | `flyway check -drift -environment=production -failOnDrift=true` |
| Pre-deploy: change report | `flyway check -changes -buildEnvironment=build -environment=production` |
| Pre-deploy: dry run | `flyway check -dryrun -environment=production` |
| Approval | Manual gate reviewing HTML report |
| Deploy | `flyway migrate -environment=production -saveSnapshot=true` (add `-baselineOnMigrate=true` only for the first deployment to an existing DB) |

### State-based
| Stage | Command |
|---|---|
| Pre-deploy: drift | `flyway check -drift -environment=production -failOnDrift=true` |
| Change report | `flyway check -changes -changesSource=schemaModel -environment=production` |
| Generate script | `flyway prepare -source=schemaModel -target=production -scriptFilename="D__deployment.sql"` (optionally `-types=deploy,undo -undoFilename="DU__undo.sql"`) |
| Code review | `flyway check -code -scope=script -scriptFilename="D__deployment.sql" -failOnError=true` |
| Approval | Manual review of script and report (docs strongly recommend review for automated state deploys) |
| Deploy | `flyway deploy -scriptFilename="D__deployment.sql" -environment=production -saveSnapshot=true` |

Fully automated state variant: `flyway prepare deploy -prepare.source=schemaModel -deploy.saveSnapshot=true -environment=production` (watch the namespaced parameters).

Guidance for customers:
- Set `cleanDisabled`, `outOfOrder`, `baselineOnMigrate` per environment, not globally.
- Keep the HTML/JSON report as a pipeline artifact for audit. Drift and code review can appear as tabs in the same report. Flyway 13.9.0 switched to a new report implementation by default (`FLYWAY_NEW_REPORTS=false` restores the legacy one); re-check any tooling that parses the report after upgrading.
- Turn on `publishResult` for Enterprise customers who want the Insights dashboard.

## Sources
- https://documentation.red-gate.com/fd/reference/commands
- https://documentation.red-gate.com/fd/reference/commands/prepare
- https://documentation.red-gate.com/fd/reference/commands/deploy
- https://documentation.red-gate.com/fd/reference/commands/snapshot
- https://documentation.red-gate.com/fd/reference/commands/check/check-changes
- https://documentation.red-gate.com/fd/reference/commands/check/check-drift
- https://documentation.red-gate.com/fd/reference/commands/check/check-dryrun
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/deployment-approaches-with-flyway
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/deployment-approaches-with-flyway/state-based-approach
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/deployment-approaches-with-flyway/migrations-based-approach
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/deployment-approaches-with-flyway/combined-state-and-migrations-approach
- https://documentation.red-gate.com/flyway/flyway-concepts/snapshots
- https://documentation.red-gate.com/flyway/flyway-concepts/drift-analysis
- https://documentation.red-gate.com/flyway/flyway-concepts/environments/shadow-and-build-environments
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/checking-production-environments-for-drift
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/checking-production-environments-for-drift/tutorial-resolve-drift-by-reverting-it
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/checking-production-environments-for-drift/tutorial-resolve-drift-by-filtering-it-out
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/checking-production-environments-for-drift/tutorial-resolve-drift-by-incorporating-it-migrations-based-deployments
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/checking-production-environments-for-drift/tutorial-drift-report-for-deployments-using-embedded-snapshot
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/implementing-a-roll-back-strategy/tutorial-roll-back-or-roll-forward-by-generating-scripts-ad-hoc-using-snapshot-history
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/generating-a-deployment-changes-report
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/automating-deployment-using-a-ci-cd-tool/common-migrations-based-deployment-scripts
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/automating-deployment-using-a-ci-cd-tool/common-state-based-deployment-scripts
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-drift-resolution-folder-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-generate-drift-resolution-scripts-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-fail-on-drift-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-snapshot-namespace/flyway-snapshot-history-limit-setting
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/flyway/learn-more-about-flyway/troubleshooting/error-running-flyway-check-clean-is-disabled
- https://documentation.red-gate.com/fd/flyway-pipelines-249987468.html
- https://documentation.red-gate.com/fd/quickstart-ci-cd-pipeline-254148659.html
- https://documentation.red-gate.com/fd/flyway-publish-result-setting-277579025.html
- https://documentation.red-gate.com/fd/features-usage-by-edition-249987475.html
- https://documentation.red-gate.com/fd/what-information-is-being-used-within-the-flyway-service-254148708.html
- https://www.red-gate.com/blog/introducing-flyway-insights-see-the-change-know-the-impact/
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace (deprecated settings)

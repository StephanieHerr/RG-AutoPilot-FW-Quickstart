<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway CLI reference

Usage: `flyway [options] command [options]`. Parameters are `-name=value`; any `[flyway]` TOML setting works as `-setting=`, environment settings as `-environments.<id>.<setting>=`. See toml-config-reference.md for parameter meanings and defaults. Editions: see editions-and-licensing.md (tiers below are from the Commands reference index).

## Commands

| Command | Edition | Purpose | Key flags / params | Example |
|---|---|---|---|---|
| `init` | Community | Create project (flyway.toml, folders, .gitignore); upgrade `.conf`; import SQL Source Control / Source Control for Oracle. 12.1+ can update TOML for Desktop users. | `-projectName`, `-databaseType` (conditionally required), `-fileName` (default `flyway.toml`), `-from`, `-fromType` (`Conf`, `SqlSourceControl`, `SourceControlForOracle`) | `flyway init -projectName=Inventory -databaseType=SqlServer` |
| `auth` | Enterprise | Online licence acquisition via browser. | `-IAgreeToTheEula` (mandatory for non-interactive use), `-logout`, `-startEnterpriseTrial` | `flyway auth -IAgreeToTheEula` |
| `add` | Community | Create empty migration with next version. | `-type` (`versioned` default, `baseline`, `undo`, `repeatable`), `-description`, `-version`, `-location`, `-nameOnly`, `-force`, `-timestamp` (`auto`) | `flyway add -description=add_orders` |
| `info` | Community | Status of applied/pending migrations. | `-infoSinceDate` / `-infoUntilDate` (`dd/MM/yyyy HH:mm`), `-infoSinceVersion`, `-infoUntilVersion`, `-infoOfState`, `-migrationIds` | `flyway info -environment=prod` |
| `validate` | Community | Compare applied vs available migrations (checksums, names, missing). | `ignoreMigrationPatterns` | `flyway validate -environment=prod` |
| `repair` | Community | Remove failed entries, realign checksums, mark missing as deleted. Needs same `locations` as migrate. | | `flyway repair -environment=test` |
| `baseline` | Community | Mark existing DB at `baselineVersion`. | `-baselineVersion`, `-baselineDescription` | `flyway baseline -baselineVersion=1 -environment=prod` |
| `migrate` | Community | Apply pending migrations. | `-target`, `-cherryPick` (Teams), `-outOfOrder`, `-dryRunOutput` (Teams), `-saveSnapshot` (namespace migrate; Enterprise feature) | `flyway migrate -environment=test` |
| `undo` | Teams | Undo last versioned migration (or down to `-target`). | `-target`, `-cherryPick` (reverse order), `-saveSnapshot` | `flyway undo -environment=test` |
| `clean` | Community | Drop all objects in configured schemas. Blocked unless `cleanDisabled=false`. Dev only. | `sqlserver.clean.mode` | `flyway clean -environment=build -cleanDisabled=false` |
| `check -code` | Community (custom rules Enterprise) | Code review (SQLFluff, regex) of `filesystem:` migrations. HTML/JSON reports plus SARIF (12.2+). | `-check.scope`, `-check.rulesConfig`, `-check.code.failOnError`, `-check.code.profile` (13.6+) | `flyway check -code -check.code.failOnError=true` |
| `check -changes` | Enterprise | Report of what pending changes will do (via build DB or snapshots, or schema model). | `-buildEnvironment` or `-buildUrl`, `-deployedSnapshot`, `-nextSnapshot`, `-appliedMigrations`, `-changesSource`, `-filterFile` | `flyway check -changes -buildEnvironment=build -environment=prod` |
| `check -drift` | Enterprise | Detect out-of-process changes vs last snapshot or build DB; resolution scripts. | `-deployedSnapshot`, `-buildEnvironment`, `-failOnDrift`, `-generateDriftResolutionScripts`, `-driftResolutionFolder` (12.9+) | `flyway check -drift -environment=prod -check.failOnDrift=true` |
| `check -dryrun` | Teams | Dry-run deployment script, same as migrate dry run. | `-dryRunOutput` | `flyway check -dryrun -environment=prod` |
| `diff` | Enterprise | Compare two sources, write a diff artifact. | `-source`, `-target` (env, `empty`, `schemaModel`, `migrations`, `snapshot:<path>`, `snapshotHistory:<name>`), `-buildEnvironment`, `-buildVersion`, `-rebuild`, `-artifactFilename` | `flyway diff -source=dev -target=schemaModel` |
| `diffText` | Enterprise | Print object-level DDL diffs from the artifact. | `-changes` (ids or `-` for stdin), `-artifactFilename` | `flyway diff -source=dev -target=schemaModel diffText` |
| `generate` | Enterprise | Generate versioned / undo / baseline migrations from a diff artifact. | `-types`, `-version`, `-description`, `-location`, `-changes`, `-baselineFilename`, `-force` | `flyway diff generate -diff.source=schemaModel -diff.target=migrations -diff.buildEnvironment=shadow` |
| `model` | Enterprise | Apply diff changes to the schema model folder. | `-changes`, `-dryRun`, `-artifactFilename` | `flyway diff model -diff.source=dev -diff.target=schemaModel` |
| `prepare` | Enterprise | Generate a deployment (and undo) script from schema model, a source env, a diff artifact, or migrations. | `-source`, `-target`, `-scriptFilename` (default `deployments/D__deployment.sql`), `-types`, `-undoFilename`, `-abortOnWarningSeverity`, `-force` | `flyway prepare -source=schemaModel -target=prod -scriptFilename=D__deployment.sql` |
| `deploy` | Enterprise | Run a deployment script, optionally save snapshot. Native Connectors supported (12.6+). | `-scriptFilename`, `-saveSnapshot`, `-environment`, `executeInTransaction`, `batch` | `flyway deploy -scriptFilename=D__deployment.sql -environment=prod -saveSnapshot=true` |
| `snapshot` | Enterprise | Capture schema to file or snapshot history table. Set `schemas` for Oracle. | `-filename` (required), `-source`, `-buildEnvironment`, `-buildVersion`, `-historyLimit` | `flyway snapshot -source=dev -filename=C:\snapshot.json` (`filename` also accepts a `snapshotHistory:` location) |
| `mcp` | Enterprise | Start Flyway MCP server for AI agents (13.0+). | `-mcp.toolsets` (required: `develop_migrations`, `develop_state`, `all`), `-mcp.maxLogs` (`100`) | `flyway mcp -mcp.toolsets=all` |
| `testConnection` | Community (unverified tier) | Check Flyway engine and comparison engine can connect; no changes. | `-environment` | `flyway testConnection -environment=development` |
| `list-engines` | Community | List supported databases. | `-outputType=json` | `flyway list-engines` |

Utility: `flyway --version` / `-v` prints edition and version (`-outputType=json` gives `edition`); `-h` / `--help` / `-?` (12.11+ help for migrate, info, validate, clean, undo lists relevant parameters). Licensing docs also show `flyway version -outputType=json`.

## Universal options

| Option | Purpose |
|---|---|
| `-environment=<id>` | Select target environment from TOML (default `default`). Inline env: `-environments.<id>.url=...`. |
| `-configFiles=a.toml,b.toml` | Load specific config (replaces auto-discovery). `-configFiles=-` reads stdin. Env var `FLYWAY_CONFIG_FILES`. |
| `-workingDirectory=<dir>` | Base for relative paths (locations, configFiles, reportFilename, dryRunOutput, snapshot filenames, filterFile, rulesLocation, rulesConfig) and config discovery. No env var. Missing-location messages show the effective working directory (12.10+). |
| `-configFileEncoding` | Config file encoding. |
| `-outputType=json` | JSON to stdout; errors included in JSON payload instead of stderr. |
| `-outputLogsInJson` | Standard logs also in JSON when `-outputType=json`. |
| `-outputFile=<path>` | Also write console output to file. |
| `-X` | Debug output (13.5+ shows each config value and its origin). |
| `-q` | Quiet: errors and warnings only. |
| `-color=always|never|auto` | Default `auto`. |
| `JAVA_ARGS` env var | JVM options, e.g. `-Xmx`. |

## Namespaces on the command line

- Full form always works: `-check.buildEnvironment=build`, `-diff.source=dev`.
- Short-circuit (scoped) form works when the params directly follow their verb: `flyway diff -source=dev -target=prod generate`. It does not work if the verb comes after: `flyway -diff.source=dev -diff.target=prod diff`.
- Docs conflict: the Command-line page says scoped namespacing is disabled when **any** namespaced param is present; 12.6.0 release notes say mixing scoped and unscoped is now allowed. Use full namespaces in scripts to be safe.
- PowerShell: quote namespaced args, e.g. `flyway migrate "-oracle.sqlplus=true"`. URLs with `;`, `&`, `=`: bash/cmd `-url="jdbc:..."`; PowerShell `-url='"jdbc:..."'`.

## Chaining commands

Multiple verbs run in one invocation, left to right:

```
flyway diff -source=dev -target=schemaModel model
flyway diff generate -diff.source=schemaModel -diff.target=migrations -diff.buildEnvironment=shadow
flyway prepare -source=schemaModel deploy -environment=prod -saveSnapshot=true
flyway check -changes -drift -buildEnvironment=build -environment=prod
```

Caveats:
- `check -code` with `failOnError` and `check -drift` with `failOnDrift` do **not** stop later chained verbs. Run the gate as a separate step before `migrate`/`deploy`.
- With `-drift` and `-changes` together, drift runs first.
- Separate check operations write into the same report file; rerunning an operation replaces its section.

## Output formats and reports

| Output | How | Notes |
|---|---|---|
| Console JSON | `-outputType=json` | Per-command schemas on each command page (e.g. migrate: `migrationsExecuted`, `targetSchemaVersion`, `migrations[]`). 13.2+: timestamps include UTC offset (breaking for parsers). |
| HTML + JSON report | `reportEnabled = true` (default `false`), `reportFilename` (default `report.html`; JSON alongside) | `check` writes a report unless `-check.generateReport=false` (12.0.2+). JSON report has `schemaVersion` (13.6+). Reports no longer keep history (12.0+); archive per run. New report implementation on by default (13.9.0); env var `FLYWAY_NEW_REPORTS=false` restores the legacy one. |
| SARIF | `check -code` (12.2+) | For GitHub Code Scanning / Azure DevOps. |
| Dry run script | `-dryRunOutput=<file>` or `check -dryrun` | Teams+. 13.6+ adds deployment overview table. |
| Drift resolution scripts | `check -drift` | Folder `drift-resolution` by default; replaced each run. |

## Exit codes and error codes

Exit codes documented on the reference page:

| Exit code | Meaning |
|---|---|
| `0` | Success |
| `1` | Failure, uncategorised |
| `35` | Licensing failure |

12.9.0 change: "Flyway CLI now exits with a distinct exit code derived from the error code when a FlywayException is thrown." The numeric mapping from error code to exit code is **not published** (unverified). In the 13.8.0 open-source engine source every core error code (general and validate) still exits 1 and licensing exits 35, so distinct codes can only come from Enterprise modules. In CI treat any non-zero exit as failure; do not test `== 1`. Use `-outputType=json` to read the error code string.

Error codes (string, in JSON output / API):

| Category | Codes |
|---|---|
| General | `FAULT`, `ERROR`, `JDBC_DRIVER`, `DB_CONNECTION`, `CONFIGURATION`, `DUPLICATE_VERSIONED_MIGRATION`, `DUPLICATE_REPEATABLE_MIGRATION`, `DUPLICATE_UNDO_MIGRATION`, `DUPLICATE_DELETED_MIGRATION`, `NON_EMPTY_SCHEMA_WITHOUT_SCHEMA_HISTORY_TABLE` (fix: `baseline` or `baselineOnMigrate`) |
| Validate | `VALIDATE_ERROR`, `SCHEMA_DOES_NOT_EXIST`, `FAILED_REPEATABLE_MIGRATION`, `FAILED_VERSIONED_MIGRATION`, `APPLIED_REPEATABLE_MIGRATION_NOT_RESOLVED`, `APPLIED_VERSIONED_MIGRATION_NOT_RESOLVED`, `RESOLVED_REPEATABLE_MIGRATION_NOT_APPLIED`, `RESOLVED_VERSIONED_MIGRATION_NOT_APPLIED`, `OUTDATED_REPEATABLE_MIGRATION`, `TYPE_MISMATCH`, `CHECKSUM_MISMATCH`, `DESCRIPTION_MISMATCH` |
| Check | `PLUGIN_CHECK_MISSING_BUILD_TARGET`, `CHECK_BUILD_NO_PROVISIONER`, `CHECK_DRIFT_DETECTED` |
| Prepare | `PREPARE_ABORT_ON_WARNINGS` |
| Docker provisioner | `DOCKER_NOT_INSTALLED`, `DOCKER_NOT_RUNNING`, `DOCKER_EULA_NOT_ACCEPTED` |
| Comparison (check changes/drift, diff, diffText, generate, model, prepare, snapshot) | `COMPARISON_ERROR`, `COMPARISON_FAULT`, `COMPARISON_BINARY_MISSING`, `COMPARISON_ENGINE_UPDATE_REQUIRED`, `COMPARISON_DATABASE_CONNECTION_FAILED`, `COMPARISON_REGISTRATION_FAILED`, `COMPARISON_ARTIFACT_NOT_FOUND`, `COMPARISON_ARTIFACT_DESERIALIZE_FAILED`, `COMPARISON_ARTIFACT_SERIALIZE_FAILED`, `COMPARISON_MAPPING_FAILED`, `COMPARISON_APPLY_TO_TARGET_FAILED`, `COMPARISON_GENERATE_DEPLOYMENT_SCRIPT_FAILED`, `COMPARISON_GENERATE_UNDO_SCRIPT_FAILED`, `COMPARISON_RETRIEVE_OBJECT_DETAILS_FAILED`, `COMPARISON_SNAPSHOT_FAILED`, `COMPARISON_DATABASE_NOT_SUPPORTED` |

Common fixes: `CHECKSUM_MISMATCH` means an applied script was edited (revert or `repair`); `CHECK_BUILD_NO_PROVISIONER` means give the build env `provisioner = "clean"` or `cleanDisabled = false`. Full code and message index: `troubleshooting-patterns.md`.

## CI usage notes

- **Licensing:** PAT via env vars `FLYWAY_EMAIL` + `FLYWAY_TOKEN` (use 12.8.1+), or offline permit via `FLYWAY_OFFLINE_PERMIT_PATH`. Never `auth` in CI. Fail fast on wrong edition: `flyway version -outputType=json | jq -e '.edition == "ENTERPRISE"'`.
- **Secrets:** keep credentials out of TOML with `${env.VAR}` (any parameter, 12.6.2+) or `environments_<env>_password` env vars (prefix case-insensitive 13.1+). Enterprise: Key Vault / Vault / Dapr / GCSM resolvers.
- **Paths:** always pass `-workingDirectory=<repo path>` (or run from the project folder) so `flyway.toml`, `locations` and reports resolve; add `-configFiles` if the TOML is elsewhere.
- **Environment per stage:** one TOML, `-environment=test|prod`. Put stage-specific tweaks in `[environments.X.flyway]`.
- **Typical gated deploy:** `check -code` (fail on error) then `check -drift -failOnDrift` then `check -changes -dryrun` (review artifacts) then `migrate -saveSnapshot=true` (or `prepare` + `deploy`), as separate steps.
- **Proxy:** OS proxy inheritance is opt-in from 13.9.0: set `FLYWAY_USE_SYSTEM_PROXIES=true` to enable (13.4.0 to 13.8.x used it automatically). Or set explicit proxy properties in `JAVA_ARGS`, which always take precedence.
- **Docker:** `docker run --rm redgate/flyway:<version> <args>`; mount the project and pass `-workingDirectory`. Docker images run JRE 25 (13.6+).
- **Telemetry:** `REDGATE_DISABLE_TELEMETRY` env var disables usage data.
- **Debugging config in CI:** add `-X` to see effective values and their source (13.5+).

## Sources

- https://documentation.red-gate.com/fd/reference/commands (and `/fd/reference/commands/{init,auth,add,info,validate,repair,baseline,migrate,undo,clean,diff,diff-text,generate,model,prepare,deploy,snapshot,mcp,list-engines}`)
- https://documentation.red-gate.com/fd/reference/commands/check
- https://documentation.red-gate.com/fd/test-connection-321585217.html
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/comparison-error-codes
- https://github.com/flyway/flyway/blob/main/flyway-core/src/main/java/org/flywaydb/core/api/CoreErrorCode.java
- https://documentation.red-gate.com/fd/reference/commands/check/check-code
- https://documentation.red-gate.com/fd/reference/commands/check/check-changes
- https://documentation.red-gate.com/fd/reference/commands/check/check-drift
- https://documentation.red-gate.com/fd/reference/commands/check/check-dryrun
- https://documentation.red-gate.com/fd/reference/usage/command-line
- https://documentation.red-gate.com/fd/reference/command-line-parameters
- https://documentation.red-gate.com/fd/reference/command-line-parameters/config-files-parameter
- https://documentation.red-gate.com/fd/reference/command-line-parameters/working-directory-parameter
- https://documentation.red-gate.com/fd/reference/command-line-parameters/output-type-parameter
- https://documentation.red-gate.com/fd/reference/command-line-parameters/output-file
- https://documentation.red-gate.com/fd/reference/command-line-parameters/color-parameter
- https://documentation.red-gate.com/flyway/flyway-concepts/flyway-projects/configuration-namespaces
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-report-enabled-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-report-filename-setting
- https://documentation.red-gate.com/flyway/reference/configuration (MCP server configuration)
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/general-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/validate-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/prepare-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/docker-error-codes
- https://documentation.red-gate.com/fd/licensing-164167730.html
- https://documentation.red-gate.com/fd/how-flyway-per-user-licensing-works-206605237.html
- https://documentation.red-gate.com/fd/reference/environment-variables
- https://documentation.red-gate.com/fd/reference/usage/network-troubleshooting
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine

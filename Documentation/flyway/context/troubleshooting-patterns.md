<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway troubleshooting: entry point and on-call triage

Start here on a live call. This file gets you from symptom or error text to the right detailed entry in under a minute.

| File | Covers | Entry IDs |
|---|---|---|
| `troubleshooting-migrations.md` | validate, checksums, baseline, repair, out of order, schema history and locks, clean, placeholders, callbacks, encoding, transactions/mixed, locations, connections; SQL Server, Oracle, PostgreSQL, MySQL, Databricks, Snowflake | M1-M17, S1-S6, O1-O9, P-1..P-6, Y1-Y6, K1-K2, F1-F4 |
| `troubleshooting-enterprise.md` | licensing and auth (incl. 13.6 re-auth), comparison/diff/generate/prepare/deploy/snapshot, check reports and drift, shadow/build provisioners, code analysis, MCP server, Flyway Insights | E1-E18 |
| `troubleshooting-desktop-and-pipelines.md` | Desktop install, project, Git, schema model, filters, shadow, logs; GitHub Actions, Azure DevOps, GitLab, Jenkins, Docker images, agents, exit codes (12.9), proxy/TLS | D1-D8, P1-P11 |

Each entry: Symptom / Likely causes (ranked) / Ask / Check / Fix / Owner / Escalate when, and collect. Quoted messages are verbatim from the Flyway 13.8.0 engine source or the docs; "(field report)" marks forum, KB or GitHub patterns with a URL.

## 1. On-call quick triage

### First questions (ask in this order)
| # | Ask | Why | How they get it |
|---|---|---|---|
| 1 | Exact error text and code, copied not paraphrased | Most issues match an entry on the message | Console output; with `-outputType=json` the `error.errorCode` field |
| 2 | Flyway engine version, and Desktop version if Desktop | Many issues are fixed-in-version; exit codes changed at 12.9.0; re-auth needed at 13.6.0 | `flyway version`; Desktop Help > About (Desktop pins an engine build) |
| 3 | Edition and licensing method | Wrong edition breaks Enterprise verbs (exit 35) | First output lines: "Flyway <Edition> Edition ..." and "Licensed via: ..." |
| 4 | Database engine, version, hosting (on-prem, Azure SQL, RDS, Snowflake...) | Per-database entries; cloud auth differs | Customer |
| 5 | Where it runs: Desktop, CLI on a laptop, pipeline (which CI), Docker image tag | Paths, secrets, proxies, entrypoints differ | Customer |
| 6 | What changed since it last worked | Upgrade, new migration, edited file, new agent, password rotation, network change | Customer; `git log` |
| 7 | Full command line and redacted `flyway.toml` (plus `flyway.user.toml` if Desktop) | Wrong environment, working directory, chained gates | Pipeline YAML or terminal |
| 8 | Which environment and whether others (dev/test) succeed | Localises drift, config or permissions | `flyway info -environment=<env>` |

### 60-second phase check
| Phase the output stops at | Look at | Go to |
|---|---|---|
| Before any "Database:" line (parameters, licensing) | Config not loaded, unknown property, environment missing, edition banner | P10, D3, E1-E5 |
| Connecting | "Unable to obtain connection...", certificate, auth, driver/plugin | M17, S1-S2, P9 |
| Validating | "Validate failed: ..." | M1-M4, M8 |
| Executing a migration | "Migration of ... failed!" block | M5, M15, per-database |
| Comparison/report steps | `COMPARISON_*`, `CHECK_*`, `PREPARE_*` | E6-E16 |
| After success in logs but the job failed | Exit code logic, report generator, chained gates | P1, P11 |

## 2. Symptom index

| Symptom (customer's words) | Entry |
|---|---|
| "It worked yesterday, now validate fails" | M1, M2, M3 |
| "Someone edited an old migration" | M1, M9 |
| "Flyway wants to run a migration we already ran" / "already exists" | M5 (skipExecutingMigrations), M6 |
| "Two devs created the same version" | M8, M3 |
| "First time on an existing database" | M6, M7 |
| "Migration failed halfway on Oracle/MySQL and now nothing runs" | M4, O6, Y1 |
| "Deploy hangs" | M10, P-2, O3 |
| "Clean does nothing / is refused" | M11, E13 |
| "No migrations found" / "It ignores my files" | M16 |
| "Can't connect from the pipeline but works on my laptop" | M17, P9, P4/P5 |
| "Can't reach licensing / the internet since upgrading to 13.9.0" (behind a proxy) | P9 (OS proxy inheritance became opt-in in 13.9.0) |
| "Certificate / PKIX error" | S1, E5, P9 |
| "Certificate error since upgrading to 13.11.1" | P9 (13.11.1 blocks distrusted CA certificates in bundled JREs and Docker images) |
| "`info` shows old migrations as Pending but migrate skips them" (with `baselineOnMigrate`) | M7 (fixed 13.11.0: shown as `Below Baseline` or `Ignored`) |
| "Pipeline says Community / exit 35" | E1, E2, E3, P5 (protected variables) |
| "Asked to rerun auth after upgrading" | E3 |
| "Deploy ran even though drift was detected" | P11, E14 |
| "Drift reported but nobody changed anything" | E14 |
| "check fails about clean/provisioner" | E13 |
| "Generated script is wrong or drops things" | E10, E11 |
| "Comparison error / RGCompare error" | E6-E9 |
| "Docker provisioner fails" | E15 |
| "Code review fails on the agent only" | E16, P8 |
| "Claude/Copilot can't use the Flyway MCP server" | E17 |
| "Nothing shows in Flyway Insights" | E18 |
| "Desktop won't open / JSON parse error" | D1 |
| "Desktop keeps asking for connection details" | D3 |
| "Objects missing from schema model" | D5, D6 |
| "Git push fails in Desktop" | D4 |
| "Exit code handling broke after upgrade" | P1 |
| "Invalid argument / Invalid flag in PowerShell or ADO" | P4 |
| "GitLab job exits immediately / flyway not a command" | P5, P7 |
| "Stored procedure / trigger block split wrongly" | M5, Y6, K1, F1 |
| "Characters garbled" | M14 |
| "PRINT output floods logs" (SQL Server) | S3 |
| "Can't query flyway_schema_history on Oracle" | O1 |

## 3. Error code index

Codes appear in `-outputType=json` as `error.errorCode` and in API results. Docs pages: General, Validate, Check, Comparison, Docker, Prepare.

| Code | Meaning (docs "Caused by", shortened) | Entry |
|---|---|---|
| `FAULT` | Unexpected internal error | Escalate: Support (section 4) |
| `ERROR` | Invalid configuration or usage not caught elsewhere | P10, D3 |
| `CONFIGURATION` | Incorrect configuration | P10, M12 |
| `JDBC_DRIVER` | JDBC driver cannot be instantiated | M17 |
| `DB_CONNECTION` | SQL issue reported by the JDBC driver | M5, M17 |
| `DUPLICATE_VERSIONED_MIGRATION` / `_REPEATABLE_` / `_UNDO_` | Same version / description / undo target twice | M8 |
| `DUPLICATE_DELETED_MIGRATION` | Schema history or filesystem corruption | M8, escalate |
| `NON_EMPTY_SCHEMA_WITHOUT_SCHEMA_HISTORY_TABLE` | Existing DB, no history table | M6 |
| `VALIDATE_ERROR` | Wrapper: some migrations failed validation (see the lines after it) | M1-M4 |
| `SCHEMA_DOES_NOT_EXIST` | Target schema missing; create it or `createSchemas` | M6 |
| `FAILED_VERSIONED_MIGRATION` / `FAILED_REPEATABLE_MIGRATION` | Failed row in history | M4 |
| `APPLIED_VERSIONED_MIGRATION_NOT_RESOLVED` / `APPLIED_REPEATABLE_...` | Applied file missing locally | M2 |
| `RESOLVED_VERSIONED_MIGRATION_NOT_APPLIED` / `RESOLVED_REPEATABLE_...` | Local file not applied (out of order / pending) | M3 |
| `OUTDATED_REPEATABLE_MIGRATION` | Repeatable changed; run migrate | Informational |
| `CHECKSUM_MISMATCH` / `DESCRIPTION_MISMATCH` / `TYPE_MISMATCH` | Applied file edited, renamed or retyped | M1 |
| `PLUGIN_CHECK_MISSING_BUILD_TARGET` | check changes/drift missing build env or snapshot | E13 |
| `CHECK_BUILD_NO_PROVISIONER` | Build env has no provisioner and clean disabled | E13 |
| `CHECK_DRIFT_DETECTED` | Drift found with failOnDrift on | E14 |
| `PREPARE_ABORT_ON_WARNINGS` | Warnings exceed threshold | E11 |
| `COMPARISON_ERROR` / `COMPARISON_FAULT` | Config error / unexpected (FAULT: contact support) | E6, section 4 |
| `COMPARISON_BINARY_MISSING` / `COMPARISON_ENGINE_UPDATE_REQUIRED` | Comparison libraries missing / project written by newer Flyway | E8 |
| `COMPARISON_DATABASE_CONNECTION_FAILED` / `COMPARISON_REGISTRATION_FAILED` | Cannot connect / cannot read a source | E6 |
| `COMPARISON_ARTIFACT_NOT_FOUND` / `_DESERIALIZE_FAILED` / `_SERIALIZE_FAILED` | Diff artifact location or parallel access | E7 |
| `COMPARISON_MAPPING_FAILED`, `COMPARISON_APPLY_TO_TARGET_FAILED`, `COMPARISON_GENERATE_DEPLOYMENT_SCRIPT_FAILED`, `COMPARISON_GENERATE_UNDO_SCRIPT_FAILED`, `COMPARISON_RETRIEVE_OBJECT_DETAILS_FAILED`, `COMPARISON_SNAPSHOT_FAILED` | Generic comparison-stage failures; detail in message | E10-E12 |
| `COMPARISON_DATABASE_NOT_SUPPORTED` | No comparison engine for this database | E9 |
| `DOCKER_NOT_INSTALLED` / `DOCKER_NOT_RUNNING` / `DOCKER_EULA_NOT_ACCEPTED` | Docker provisioner prerequisites | E15 |

In engine source but not on the docs pages (source-only, meaning inferred from name): `CONFIGURATION_RECOVERABLE`, `FAILED_BASELINE_MIGRATION` (M4), `ENVIRONMENT_RESOLVE` and `ENVIRONMENT_PROVISION` (resolver/provisioner failures, E15). SQL Server connection sub-codes (`subErrorCode` in JSON): `CONNECTION_FAILURE`, `INTEGRATED_AUTH_NOT_SUPPORTED`, `INTERACTIVE_AUTH_DRIVERS_MISSING`, `UNTRUSTED_CERTIFICATE` (S1, S2).

### Exit codes
| Exit | Meaning |
|---|---|
| 0 | Success |
| 1 | Uncategorised failure. In 13.8.0 open-source source, all core error codes still exit 1 |
| 35 | Any licensing failure (10.0.0+) |
| other non-zero | 12.9.0+: "distinct exit code derived from the error code" for some exceptions (Enterprise module codes); mapping unpublished (unverified) |

Rule for pipelines: any non-zero = fail; only branch on 35 (P1).

## 4. Message index (verbatim prefixes)

| Message starts with | Code | Entry |
|---|---|---|
| "Validate failed: Migrations have failed validation" | VALIDATE_ERROR | read the next line |
| "Migration checksum mismatch for migration" | CHECKSUM_MISMATCH | M1 |
| "Detected applied migration not resolved locally:" | APPLIED_..._NOT_RESOLVED | M2 |
| "Detected resolved migration not applied to database:" | RESOLVED_..._NOT_APPLIED | M3 |
| "Detected failed migration to version" | FAILED_VERSIONED_MIGRATION | M4 |
| "Migration of ... failed! Changes successfully rolled back." / "... Please restore backups and roll back database and code!" | DB_CONNECTION (SQL detail) | M5 (before 13.9.0 "successfully rolled back" could appear even when the rollback threw) |
| "Found non-empty schema(s) ... but no schema history table" | NON_EMPTY_SCHEMA_... | M6 |
| "Unable to baseline schema history table" | ERROR | M7 |
| "Found more than one migration with version" | DUPLICATE_VERSIONED_MIGRATION | M8 |
| "Waiting for lock on Flyway schema history table" / "Unable to acquire ... lock" | | M10 |
| "Unable to execute clean as it has been disabled" | | M11 |
| "ERROR: Clean is disabled - unable to configure clean provisioner" | CHECK_BUILD_NO_PROVISIONER | E13 |
| "No value provided for placeholder:" | | M12 |
| "Detected both transactional and non-transactional statements within the same migration" | | M15 |
| "Skipping filesystem location:" / "No migrations found. Are your locations set up correctly?" | | M16 |
| "Unable to obtain connection from database" | DB_CONNECTION / sub-code | M17, S1, S2 |
| "Unable to connect to the database. Configure the url, user and password!" | CONFIGURATION | M17, P10 |
| "No Flyway database plugin found to handle" / "No JDBC driver found to handle" / "Unsupported Database:" | | M17 |
| "Unknown configuration property" / "Unknown configuration properties" | CONFIGURATION | P10, M15 |
| "Upgrade required: ... is not supported by" | licensing (exit 35) | E1 |
| "Flyway permit on disk is outdated" / "... is expired ... Please rerun auth" | licensing | E3 |
| "Your ... license has expired and is no longer valid" | licensing | E4 |
| "ERROR: Invalid argument: -check" / "Invalid flag" | | P4. Exception: "Invalid flag: init" from the open-source (OSS) edition means `init` needs a Redgate edition; from Flyway 13.10.1 OSS reports that Redgate Edition is required instead (exact wording not in the notes) |
| "Run Flyway with -X option to see the actual statement causing the problem" | | section 5 |

## 5. Getting diagnostics

| Need | How | Notes |
|---|---|---|
| Debug log | add `-X` | Command-line errors suggest running with `-X` (13.11.0). Shows actual failing statement, effective config and origin of each value (13.5+), proxy detected (13.4+). Large: pair with `-outputFile` |
| Save console output | `-outputFile=flyway-run.log` | CLI only |
| Machine-readable error | `-outputType=json` (add `-outputLogsInJson` for logs) | Errors go into JSON, not stderr: `{"error": {"errorCode", "message", "cause"}}`; migrate failures add `sqlState`, `sqlErrorCode`, `lineNumber`, `path`; SQL errors add `subErrorCode`. Field list from engine source (docs do not define it) |
| Connectivity only | `flyway testConnection -environment=<env>` | Tests Flyway engine and comparison engine connections; no changes, no callbacks |
| Edition and permit | `flyway version` / `flyway version -outputType=json` | `edition`, `permitExpiry` |
| Reports | `check` always writes `report.html` + `report.json` (set `-reportFilename`); `reportEnabled=true` for migrate | Reports do not keep history (12.0+); `check -code` also writes SARIF; drift scripts in `drift-resolution/` |
| Desktop logs | Settings (cog) > logging "verbose"; `%USERPROFILE%\AppData\Local\Red Gate\Logs\Flyway Desktop` (link in settings) | Verbose also captures CLI debug logs (Desktop 8.5.13+). Logs older than a month deleted at startup from Desktop 9.10.3 (Settings > Log retention). macOS/Linux path undocumented (unverified) |
| Desktop CLI equivalent | "View command" in Desktop, run it in a terminal with `-X` | Separates UI issues from engine issues |
| MCP server logs | `%localappdata%\Red Gate\Logs\Flyway` / `~/.local/share/Red Gate/Logs/Flyway` | Retention `mcp.maxLogs` |
| CLI licensing files | `%APPDATA%\Redgate\Flyway CLI` / `~/.config/Redgate/Flyway CLI` | Delete via `flyway auth -logout` |
| Docker | `docker run --rm -v <project>:/flyway/project redgate/flyway:<tag> -workingDirectory=project -X info` | Logs go to stdout/stderr; write reports into the mounted folder |
| Pipeline | Publish `reports/` and the `-outputFile` log as artifacts with `always()` / `when: always` | |

### What to collect for Redgate support
1. `flyway version` output (edition, version, licensing method) and Desktop version.
2. The exact command and the full console output with `-X` (redact passwords, tokens, hostnames if required).
3. Redacted `flyway.toml` and `flyway.user.toml`; filter files if comparison-related.
4. Database engine, version, edition, hosting; agent OS and whether Docker (image tag).
5. `flyway info` for the affected environment; schema history rows if validate/repair related.
6. Reports (HTML/JSON), drift resolution folder, and for comparison issues the diff artifact (contains schema metadata: get customer consent).
7. Desktop: verbose logs folder zipped.
8. When it started and what changed (upgrade, new agent, edited file).

`FAULT` and `COMPARISON_FAULT` go straight to Support. No published Redgate support checklist exists for Flyway (unverified); the list above is Laura's working standard.

## Sources
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/general-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/validate-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/comparison-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/docker-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/prepare-error-codes
- https://github.com/flyway/flyway (engine source at 13.8.0: CoreErrorCode, FlywaySqlServerErrorCode, Main exit code handling, error output records, message strings)
- https://documentation.red-gate.com/fd/reference/command-line-parameters/output-type-parameter
- https://documentation.red-gate.com/fd/reference/command-line-parameters/output-file
- https://documentation.red-gate.com/spaces/FD/pages/321585217 (testConnection)
- https://documentation.red-gate.com/spaces/FD/pages/138347156 (Flyway Desktop logging)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html
- https://documentation.red-gate.com/fd/reference/commands/auth
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-report-filename-setting
- https://documentation.red-gate.com/spaces/FD/pages/321585710 (Flyway Docker)
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/reference/usage/network-troubleshooting

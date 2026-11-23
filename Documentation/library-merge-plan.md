# Library merge plan: `flyway/` into `FlywayAIDump/`

Comparison done 2026-11-10. Every file in `Documentation/flyway/` was read in full. It was compared with the matching FlywayAIDump files. The main contradictions were checked against the source lines.

- **NEW** = `Documentation/flyway/` (CLAUDE.md, sources.md, context/*.md). Written for a Redgate SE, covering several databases and CI platforms. Dated with `last-verified` headers.
- **OLD** = `Documentation/FlywayAIDump/` (00 to 30, .txt). Customer-facing, for SQL Server and GitHub Actions. The setup and troubleshoot skills use it.
- References: `NN:line` means an OLD file. `name.md:line` means a NEW file in `context/`.

## Status (2026-11-10)

- **Merged.** Sections 1a to 6 are applied to FlywayAIDump. The library is now 32 files (00 to 31), with new file 31 on SQL Change Automation and SQL Source Control. File 25 is refreshed from the live release notes (engine 13.12.1, Desktop 9.11.5). `manifest.json` is updated and validated.
- **Coverage audit done.** Every file in `Documentation/flyway/context/` was audited fact by fact against the library. About 790 facts were already present and about 230 were left out on purpose (section 7). About 100 were missing and have now been added, the important ones being:
  - the snapshot-history grant for the read-only drift account (N12);
  - the config-mismatch cause of "Found non-empty schema(s)";
  - `revertDrift.sql`;
  - state-based rollback from snapshot history;
  - `callbackLocations` for `deploy`;
  - the backup provisioner file mapping;
  - the `noqa` syntax;
  - the 13.10.0 clean-mode fix.

  The .NET history is settled in file 25: .NET 8 from 10.1.0, .NET 9 from 11.1.0, .NET 10 from 12.0.0 (per the V12 upgrade guide). Deliberately skipped: the unverified "Redgate Monitor can alert on drift" claim and the internal `NOLOCK` change.
- **Kept as decided:**
  - the "Not from Redgate docs" banner, em dash included;
  - file 00's one-month re-check rule;
  - existing `flyway testConnection` mentions, which file 00's sandbox paragraph overrides.
- **Not done yet:**
  - skill updates (the Desktop "Baseline and continue" warning before deploying to Test, and MCP fault routing to file 23 section 12);
  - section 9 repo issues;
  - retiring `Documentation/flyway/`.
- **Left open in the library:**
  - file 12's GitHub PR workflow still runs code review after the build, inside the checks action (C10);
  - file 16's `databaseEngine` value for SQL Server is a placeholder;
  - SARIF file naming is unverified;
  - `-check.changesSource=schemaModel` is unverified.

## Approach

1. Keep OLD as the base. Its numbering, operating rules and routing table stay.
2. Move every version fact into OLD file 25. Other files keep version floors only ("from engine 13.0.0").
3. Fold useful NEW content into the matching numbered OLD file (see "Bring over").
4. Add one new numbered file: moving off SQL Change Automation or SQL Source Control.
5. Fix the contradictions below, the internal inconsistencies and the repo issues.
6. Retire `Documentation/flyway/` once its content is merged.

## 1. Open items: verify before merging

Neither library settles these. A read-only `flyway info -X` (13.5+) on a test project, or the Redgate docs page, would decide them. The verdicts are in section 1a.

| # | Topic | NEW | OLD | Why it matters |
|---|---|---|---|---|
| V1 | `-configFiles` | Replaces auto-discovery (`cli-reference.md:43`, `toml-config-reference.md:43`, `troubleshooting-desktop-and-pipelines.md:106`) | Loads in addition to the auto-loaded files (`10:36`). OLD is unsure itself (`12:43`, `12:570`) | OLD's `ci/<env>.toml` pattern (`10:181-186`, `12:281`) loses `flyway.toml` if NEW is right |
| V2 | One TOML with every environment's `${env.X}` | One TOML, `-environment=test\|prod` (`cli-reference.md:117`). Every NEW architecture puts all environments in one file | Flyway resolves every `${env.X}` it loads, so this fails in every step (`10:176`; also `02:143`, `23:73`, `24:86`, `01:114`, `27:168`, `28:113`, `15:97`) | AGENTS.md keeps every environment in the shared `flyway.toml`. If OLD is right, NEW's Postgres, Oracle and MySQL pipelines also fail, because they leave out the dev secrets |
| V3 | What `[environments.X.flyway]` can override | Anything except `environment`, `cherryPick`, `email`, `token`, `licenseKey`, `undoSqlMigrationPrefix`. Child namespaces can't be overridden (`toml-config-reference.md:32-33`) | From 13.10.0, also non-`flyway` namespaces such as `check.buildEnvironment`. Only `environment` can't be overridden (`10:328`, `10:334`) | The two cite different Redgate pages, so record both statements and test on the installed engine |
| V4 | `${env.X}` inside `-configFiles` TOMLs | Works in all parameters, 12.6.2+ (`toml-config-reference.md:53`) | Treated as unproven (`10:409`, `02:143`, `06:195`) | NEW probably settles OLD's open question. Confirm on the resolver page |
| V5 | `init` syntax | `flyway init -projectName=... -databaseType=SqlServer` (`cli-reference.md:11`, `sca-to-flyway-upgrade.md:214`) | `flyway init -init.projectName=... -init.databaseType=sqlserver` (`06:109`) | Pick one form |
| V6 | CI PAT service account licence | Needs no licence (`editions-and-licensing.md:89`; source is the Licensing FAQ, Nov 2024) | Needs Flyway Engine allocated (`04:51`, `04:157`) | NEW's source is old. Probably no commercial seat, but the entitlement still has to be allocated |
| V7 | Java floor for the API and Maven | Java 21+ on 13.x, from a blog post (`release-status.md:69`) | JDK 17+ on 13; Java 21 from engine 14, not re-read (`25:79`) | Re-read the API (Java) page |
| V8 | `check -dryrun` SQL output | `check -dryrun -dryRunOutput` gives SQL, HTML and JSON (`deployment-and-drift.md:33`) | For a SQL file, run `migrate -dryRunOutput` on its own (`11:180`, `13:35`) | Two different commands |
| V9 | `-check.deployedSnapshot` path | Needs a `filesystem:` or `snapshotHistory:` prefix (`toml-config-reference.md:159`), but a bare path appears at `deployment-and-drift.md:93` | Bare path (`15:172`) | NEW contradicts itself |
| V10 | `REDGATE_FLYWAY_MCP_SERVER_FEATURE` | Not mentioned | Not mentioned | It's set in `.mcp.json:7`. Document it from docs.red-gate.com or drop it |
| V11 | Automate deployment page preview status | Public preview in Desktop 9.6.5 (`release-status.md:173`) | No label (`12:94`); not in the preview table (`25:86-94`) | Re-check |
| V12 | State-based deploys on the Insights Deployments page | `deploy` publishes from 13.6.0 (`release-status.md:169`) | Migrations-based only (`24:74`, `18:165`) | Re-check |

## 1a. Verdicts (docs.red-gate.com read 2026-11-10; installed CLI is 13.12.1)

| # | Verdict | Evidence |
|---|---|---|
| V1 | **OLD is right: `-configFiles` adds to the auto-discovered `flyway.toml`.** Fix NEW `cli-reference.md:43`, `toml-config-reference.md:43` and `troubleshooting-desktop-and-pipelines.md:106`. Also fix the precedence page wording | The docs disagree. The configFiles page says the files load "in addition to those loaded automatically", while the precedence page implies they replace them. **Tested on 13.12.1** in a temporary folder with no database. With `-configFiles=extra.toml -environment=autoenv`, Flyway found `autoenv`, which exists only in the working directory's `flyway.toml`, and tried to connect. The control run without `-configFiles` asked for `extraenv` and failed with "Environment 'extraenv' not found" |
| V2 | **NEW is right: an unused environment's unset `${env.X}` doesn't break a command.** Fix OLD `10:176` and the files that build on it (`02:143`, `23:73`, `24:86`, `01:114`, `27:168`, `28:113`, `15:97`). The per-environment `ci/<env>.toml` pattern is optional, not required. One shared `flyway.toml` works, which matches AGENTS.md | Not stated in the docs. **Tested on 13.12.1.** One TOML had `alpha` (`user = "${env.FWTEST_ALPHA_USER}"`, set) and `beta` (`user = "${env.FWTEST_BETA_USER}"`, unset). `-environment=alpha` got past config and tried to connect as the alpha user. `-environment=beta` failed with "Unable to resolve environment variable: 'FWTEST_BETA_USER'". Add that message to the troubleshooting index. Not tested: placeholders and `[flyway]`-level settings that reference an unset variable |
| V3 | **OLD is right. Fix NEW `toml-config-reference.md:32-33`** | Environment overrides page: only `environment` can't be overridden. `email`, `token` and the license key can be, but "not recommended". Other namespaces such as `check` can be overridden too. Command-line-only settings (working directory, config files, output type, color) can't be set per environment. The 13.10.0 release note adds `undoSqlMigrationPrefix` and `check.buildEnvironment`. `cherryPick` isn't named; it isn't on the exclusion list, so it's probably allowed. The environment-flyway-namespace page only links to the overrides page |
| V4 | **NEW is right. Remove OLD's "unproven" wording (`10:409`, `02:143`, `06:195`)** | 12.6.2 release note: the resolver "now works in all flyway configuration parameters". The resolver page says "all Flyway namespace parameters and environment properties in TOML configuration". Whether it covers non-`flyway` namespaces is still unclear |
| V5 | **Use NEW's documented form: `flyway init -projectName=<name> -databaseType=sqlserver`** | The init page examples use the short forms. OLD's `-init.projectName=` is valid under the namespace rule, but it isn't shown and would need quoting in PowerShell. The only SQL Server value shown is `sqlserver`. `-fromType` values: `Conf`, `SqlSourceControl`, `SourceControlForOracle` |
| V6 | **Docs conflict. Keep OLD's advice (allocate a licence to the CI account) and say to confirm with the Redgate account team** | The licensing page (updated 12 May 2026) says every option needs "a Redgate account and the account has been allocated a Flyway license". The Commercial Licensing FAQ (updated 7 Nov 2024) says a PAT service account isn't required to buy one |
| V7 | **OLD is right. Fix NEW `release-status.md:69`** | API (Java) page (updated 5 Nov 2026): "Java JDK 17+" for engine 13; "Starting with Flyway v14, Java 21 will be required." The CLI and MCP bundle their own JRE |
| V8 | **Both partly right. Merge them** | `check -dryrun` "generates a dry run script", and `dryRunOutput` is a root-level setting. The dryRunOutput page says that in any multi-command run "only the first command" is recorded, and recommends dry runs "when running `migrate` on its own". For a SQL file, document `flyway migrate -dryRunOutput=<file>` as a separate step |
| V9 | **OLD is right. Fix NEW `toml-config-reference.md:159`** | check.deployedSnapshot page: "will be a file path if no prefix is specified". `filesystem:` is optional. The default is `snapshotHistory:current` |
| V10 | **Not documented. Plan to drop it from `.mcp.json`, after testing that the server still starts without it** | Not on any MCP page. The documented Claude Code registration is `"type": "stdio"`, `"command": "flyway"`, `"args": ["mcp", "-mcp.toolsets=...", "-mcp.maxLogs=100"]`, with no `env`. The MCP server is still preview, needs 13.0.0+, and `-mcp.toolsets` is required with no default. Toolsets are `develop_migrations`, `develop_state` and `all` ("today identical to `develop_migrations`"). Redgate's example uses `develop_state`, but this sandbox needs `develop_migrations` |
| V11 | **NEW is right. Add it to OLD file 25's preview table** | Desktop 9.6.5 release note: "New Automated deployment page is now available in public preview". No later note takes it out of preview |
| V12 | **OLD is right. Also confirms O9** | Insights Deployments page (updated 1 Oct 2026): "only migrations-based deployments are shown on this page", and "All deployments (state and migrations) are included in the DORA and ROI pages". All of Flyway Insights is in public preview for Enterprise |

Side findings:
- **O16 is softer than stated.** The namespaces page documents short-circuiting: `flyway check -drift -failOnDrift=true` is valid when the verb comes first. A namespace is still required for options placed before the verb, and for later verbs in a chain (e.g. `flyway diff generate -diff.source=...`). In PowerShell, namespaced args need quoting. Standardise on namespaced forms for consistency, but don't call the short forms wrong.
- **Installed CLI is 13.12.1**, newer than both libraries. File 25 needs a refresh from the release notes during the merge.
- **`-X` doesn't show where each setting came from.** On 13.12.1, `flyway info -X` didn't print config origins before the connection failed, so NEW's "13.5+ `-X` shows each value's source" (`toml-config-reference.md:45`, `cli-reference.md:49`) may only apply once a connection succeeds, or not at all. Don't rely on it until it's confirmed.

## 2. Contradictions where OLD is right (keep OLD)

| # | Topic | NEW (change or drop) | OLD (keep) |
|---|---|---|---|
| O1 | `baselineOnMigrate` on first deploy | Offered as a one-off: `deployment-and-drift.md:168`, `arch-sqlserver-github-migrations.md:186`, `arch-sqlserver-gitlab-migrations.md:220`, `sqlserver-reference.md:154`, `sca-to-flyway-upgrade.md:86`, `troubleshooting-migrations.md:60` | Keep it false on shared environments, because it hides a wrong-target connection (`07:50`, `07:151`, `07:279`, `28:288`, `28:350`, `29:44`). AGENTS.md: the user runs `flyway baseline`, and Backup as Baseline comes first |
| O2 | `repair` after a checksum mismatch | Repair if the edit was intended and the DB matches (`troubleshooting-migrations.md:14`). Also used as the fix at `:23`, `:41`, `:162` and `cli-reference.md:110`, with no owner named | Only for a proven cosmetic edit, run by a person once per environment, never in a pipeline (`22:97-98`, `14:197`). AGENTS.md: never run repair |
| O3 | `outOfOrder` | `outOfOrder = true` in dev and test environments (`troubleshooting-migrations.md:32`) | Never different values across shared environments (`09:336`). Never enable it in production to get past the error (`22:106`). One reviewed run for a hotfix (`09:91`) |
| O4 | `trustServerCertificate` | True for dev and test (`troubleshooting-*.md` S1:136; `toml-config-reference.md:284`) | Only for a disposable development database (`23:87`, `10:102`) |
| O5 | What to send Support | Redacted `flyway.toml` and `flyway.user.toml`, schema history rows, diff artifacts; hostnames redacted only "if required" (`troubleshooting-patterns.md:173-177`) | No passwords, tokens, permits, host, server, database or schema names unless Support asks. Never table data (`23:176-178`). The troubleshoot skill matches OLD |
| O6 | Fully automated state-based production deploy | `flyway prepare deploy -prepare.source=schemaModel ...` (`deployment-and-drift.md:180`) | The file approved is the file deployed (`11:156`, `11:343`) |
| O7 | `[flyway] environment` | `environment = "test"  # default target` (`toml-config-reference.md:254`) | Never set it to a deployed environment (`10:170`) |
| O8 | Desktop AI features | No preview label (`feature-history.md:21`, `:39`; `release-status.md:101`) | Preview (`25:92`) |
| O9 | Insights preview scope | Only the Deployment metrics view is preview (`deployment-and-drift.md:133`) | All of Flyway Insights is in public preview (`18:28`) |
| O10 | Bundled engine in Desktop | "Desktop 9.10.1 ships engine 13.8.0" (`desktop-reference.md:5`) | Never report a bundled RC build as a released engine (`25:76`) |
| O11 | Killing lock sessions | "Kill the orphaned session" (`troubleshooting-migrations.md:87`) | A DBA decision, never from a pipeline (`22:87`, `22:138`) |
| O12 | SQL Compare engine parity | "Same engine, so generated SQL behaves as they expect" (`sca-to-flyway-upgrade.md:42`, `:134`) | Flyway's option defaults differ, 15 options are fixed, and `.snp` is not a Flyway snapshot (`19:43-52`) |
| O13 | Baseline mechanisms | Script, `B__` and `baseline` command treated as alternatives (`sca-to-flyway-upgrade.md:62`) | `B` scripts are for new environments, the command is for populated ones, and `baselineVersion` must match the timestamped `B` version (`07:42-48`) |
| O14 | Concurrency in GitHub Actions | Workflow-level `concurrency` with defaults (`arch-sqlserver-github-migrations.md:75`) | The default replaces pending jobs, so use `queue: max` and `cancel-in-progress: false` (`12:209`, `12:224-227`) |
| O15 | Promotion | Re-checks out source in every job (`arch-sqlserver-github-migrations.md`) | Package once with a sha256 check and promote the artifact (`12:289`, `12:456`) |
| O16 | `-failOnDrift` and other short flags | Bare short-circuit forms (`deployment-and-drift.md:164`, `:168`, `:176`; `cli-reference.md:118`; ADO architecture `:79`, `:81`) | Always namespaced, e.g. `"-check.failOnDrift=true"` (`11:201`, `14:85`, `13:128`, `13:220`, `16:319`). Safer in PowerShell. Standardise on namespaced |
| O17 | Backup and snapshot provisioners | No preview label (`sca-to-flyway-upgrade.md:63`, `:132`) | Preview (`25:90`, `29:52`); NEW `toml-config-reference.md:225` agrees |
| O18 | Licensing values in TOML | `email` and `token` in `[flyway]` (`toml-config-reference.md:262-263`) | Env vars only, kept out of `flyway.toml` (`04:157`, `04:183`) |

## 3. Contradictions where NEW is right (fix OLD)

| # | Topic | OLD (fix) | NEW (adopt) |
|---|---|---|---|
| N1 | Latest engine | 13.10.2, 15 Oct (`25:42`) | 13.11.1, 21 Oct. 13.10.2 has been removed from the release notes (`release-status.md:11`, `:89`) |
| N2 | Latest Desktop | 9.10.6, plus an unnumbered 14 Oct entry (`25:43`) | 9.10.9, 22 Oct. The unnumbered entry is 9.10.7 (`release-status.md:12`, `:106`) |
| N3 | Exit codes | Only `1` and `35` are documented; don't branch on others (`22:26`, `11:332`, `22:275`) | From 12.9.0 a code can come from the error code, so treat any non-zero as failure and branch only on 35 (`release-status.md:57`, `cli-reference.md:97`) |
| N4 | MCP starting toolset | Start with `develop_state` (`20:154`, `20:194`, `08:195`, `01:123`) | `develop_migrations` (`ai-and-mcp.md:63`), which matches `.mcp.json:6` and the skill. Add a sandbox carve-out to file 20 |
| N5 | Tools only in `develop_migrations` | Lists four (`20:119`) | Also `create_diff_migrations` (`ai-and-mcp.md:105`) |
| N6 | Redgate rule groups | All RG rules are in `redgate` (`13:67`) | Except RG18 and RG19, which are in `all` only (`code-analysis.md:69`) |
| N7 | Redgate regex rules | "Copy in any Redgate-supplied rules" (`13:137`) | No longer shipped from 12.0.0 (`code-analysis.md:156`) |
| N8 | Regex rule dialect | Use `["tsql"]` (`13:137`) | `TEXT` applies to all databases (`code-analysis.md:149`). The repo's `Rules/DM*.toml` use `TEXT` |
| N9 | SQLFluff config discovery | Never merged; local `.sqlfluff` ignored (`13:111`) | Local files are ignored only when Flyway resolves a file (`code-analysis.md:108-109`) |
| N10 | Shipped SQLFluff rule list | Not documented (`13:81`) | A subset plus Redgate rules (`code-analysis.md:99`). The repo's `sqlfluff.cfg:17` matches |
| N11 | Static data row filter | Flyway can't filter by rows (`24:38`) | `whereClause`, SQL Server, Enterprise (`editions-and-licensing.md:69`, `toml-config-reference.md:241`). OLD `07:158` and `16:206` agree |
| N12 | Drift read-only permissions | `SELECT` on `flyway_schema_history` (`04:99`) | Also `flyway_snapshot_history` (`sqlserver-reference.md:131`) |
| N13 | Accepting drift | "Accept and re-baseline" (`14:113`) | Re-snapshot is the lighter documented step (`deployment-and-drift.md:123`). Separate the two |
| N14 | Key Vault resolver sign-in | "Relies on the Azure SDK credential chain" (`10:266`) | Not described on the page; unverified (`toml-config-reference.md:54`). Change OLD to "expected" |
| N15 | No-licence behaviour | Falls back to Community silently (`24:104`, `12:124`) | Enterprise-only commands fail with exit 35 (`editions-and-licensing.md:73`). Merge both: Enterprise-only commands fail, while optional Enterprise behaviour quietly doesn't happen |
| N16 | Deprecated settings replacements | `checkDriftOnMigrate` becomes `check -drift`; `publishReport` becomes `publishResult` (`25:109-110`) | The release notes don't state replacements (`release-status.md:144-145`). Label OLD's as library advice |
| N17 | Object level history GA | Unnumbered 14 Oct entry (`25:43`) | GA in Desktop 9.10.7; the roadmap still says Preview (`desktop-reference.md:58`) |

## 4. Internal inconsistencies

**OLD**
- `22:218` says the scratch project is the only place for `cleanDisabled = false`. `13:41` allows it on build, which is correct. Fix 22.
- Snapshots are `reports/before.snp` in `13:271` but `.json` in `15:172`. Use `.json`.
- `07:94` calls Backup as Baseline "the preferred route", and `07:114` says its preview status isn't stated. `29:52`, `29:178` and `29:260` label it preview.
- `25:94` sends object level history to file 08, but file 08 never mentions it.
- `02:132-143` recommends one `ci/<env>.toml` per environment, which conflicts with AGENTS.md keeping every environment in `flyway.toml` (see V2).

**NEW**
- `code-analysis.md:30` uses `"-check.code.failOnError=true"`, but `:31` uses a bare `-failOnError=true`. Use the namespaced form.
- CLAUDE.md says to set `cleanDisabled` per environment, but `common-architectures.md:27` and every architecture file set it globally.
- `desktop-reference.md:18` uses `flyway --version`. `ai-and-mcp.md:32` and the skill use `flyway version`. Keep `flyway version`.
- `ai-and-mcp.md:102` dates the checkpoint tool to 13.7+, but `:150` says it was renamed in 13.5.0.
- The `last-verified` headers are older than the checks cited in the bodies (`toml-config-reference.md:33`, `desktop-reference.md:1`, `feature-history.md:1`).
- "50+" platforms (`sca-to-flyway-upgrade.md:44`, `:194`) vs "60+" (`competitive.md:23`, `editions-and-licensing.md:29`).
- Engine release notes URL: `/flyway/...` in `release-status.md:189` but `/fd/...` in `feature-history.md:138`.
- GitHub, GitLab and ADO architectures mix namespaced and bare `check` flags.
- `common-architectures.md:26` requires an edition check, but only the GitLab architecture has one.
- `common-architectures.md:33` says to publish reports on failure, but the GitHub production-deploy job uploads nothing.

**Both**
- `flyway testConnection` is recommended in OLD (`23:80`, `23:93`, `23:183`, files 04, 10, 12, 27) and NEW (`cli-reference.md:33`, `troubleshooting-patterns.md:161`, troubleshooting entries M17 and E6, the Oracle and Databricks files, the GitLab architecture `:151`). AGENTS.md bans it, so the merged library needs one sandbox override.
- Docs URL forms differ for the same pages: `/fd/...-id.html` or `/fd/reference/...` vs `/flyway/...`. OLD `26:465` says to prefer `/flyway/`, so standardise on that.

## 5. Operating rule conflicts (NEW CLAUDE.md vs OLD 00 and 01)

| Rule | NEW | OLD | Merge decision |
|---|---|---|---|
| Em dash | Don't use em dashes | The composed-content banner contains one (`00:63`) | Decide. If em dashes go, reword the banner |
| Composed-content banner | None; inline "(unverified)" and per-file Sources | Required on everything composed (`00:63`) | Keep OLD's banner, and add NEW's per-file Sources lists |
| Placeholders | Complete, runnable blocks, no placeholder comments | Placeholders for servers and secrets (`00` rule 8, `01:33`) | Keep OLD |
| Credentials | `${env.X}` everywhere, including dev | Dev has no credentials in TOML; Desktop stores the logins. `${env.X}` only in CI | Keep OLD and AGENTS.md |
| Versions | Inline in every file; `release-status.md` is the source of truth | Only file 25 (`00` 6.8) | Keep OLD, and move NEW's inline versions into 25 |
| Freshness | Re-fetch the release notes if `release-status.md` is more than two weeks old | Re-check if file 25 is more than a month old (`00:159`) | Decide |
| Ask vs default | Ask if the database or platform isn't stated | Proceed on safe defaults (`01:199`) | Keep OLD (the sandbox is SQL Server) |
| Connecting | Not stated | "The assistant never connects" (`00:34`, `27:67`) | Align with AGENTS.md (MCP on dev and shadow, read-only CLI) |

## 6. Bring over from NEW

The OLD file each item goes into is in brackets. Version numbers go to file 25, and only floors stay in the target file.

**Troubleshooting [22, 23]**
- Error code index, including `COMPARISON_*`, `CHECK_*`, `PREPARE_*`, `DOCKER_*` and `NON_EMPTY_SCHEMA...` (`troubleshooting-patterns.md:84-113`, `cli-reference.md:103-108`).
- Message-prefix index mapping exact error text to an entry (`troubleshooting-patterns.md:127-152`).
- SQL Server connection sub-codes `UNTRUSTED_CERTIFICATE`, `INTEGRATED_AUTH_NOT_SUPPORTED` and `INTERACTIVE_AUTH_DRIVERS_MISSING`, plus "PKIX path building failed" (`:113`, S1, S2).
- "Unable to obtain connection" and "Configure the url, user and password!" mean no config was loaded. With `.conf` and `.toml` together, only TOML loads (M17, P10).
- `-X` shows each effective setting and where it came from. JSON error fields `sqlState`, `lineNumber` and `subErrorCode` (`troubleshooting-patterns.md:158-160`).
- MCP log path `%localappdata%\Red Gate\Logs\Flyway`; MCP file locations; MCP troubleshooting table (`ai-and-mcp.md:126-148`). The troubleshoot skill can use these.
- Desktop "Environment 'development' not found"; `${localSecret.X}` is machine-specific ("Error reading secret: Element not found") (D3).
- "View command" in Desktop, then rerun in a terminal with `-X` (`troubleshooting-patterns.md:165`).
- Desktop won't start / JSON parse error: clean reinstall (D1). "--No text is available" in the schema model; the filter `[_]` tip (D5).
- `COMPARISON_ENGINE_UPDATE_REQUIRED` when the CLI is older than Desktop (E8).
- `CHECK_BUILD_NO_PROVISIONER`, `PLUGIN_CHECK_MISSING_BUILD_TARGET` (E13); `PREPARE_ABORT_ON_WARNINGS` and `abortOnWarningSeverity` (E11).
- "Migration failed! Changes successfully rolled back." wasn't reliable before 13.9.0 (M5).
- Gates don't stop chained verbs, so use one gate per step (P11).

**Azure DevOps [11, 12, or a new ADO section]** OLD has almost nothing here, but the repo ships ADO pipelines.
- Secret variables aren't exported automatically; map them into each step's `env:` (`arch-sqlserver-azuredevops-state.md:146`, P4).
- "Invalid argument: -check": quote dotted arguments. `-azure` images have no entrypoint (P4).
- Deployment jobs with an ADO environment approval check, as an alternative to `ManualValidation@0` (`:69-70`, `:120`).
- `publish` / `download: current` to deploy the exact reviewed script; `prepare -types=deploy,undo` for a rollback script; a drift re-check after approval (`:102-145`).
- SARIF works in ADO too (`cli-reference.md:83`).

**PowerShell [12, 23]**
- PowerShell rejects dotted arguments unless quoted (`deployment-and-drift.md:49`).
- PowerShell 5.1: `2>&1` under `$ErrorActionPreference='Stop'` throws before `$LASTEXITCODE` is read (`sqlserver-reference.md:144`).

**Config and CLI [10]**
- Config load order: install `conf/`, then user home, execution dir, working dir; `flyway.user.toml` overrides in each folder (`toml-config-reference.md:39`).
- `.conf` plus TOML in `-configFiles` is an error; `flyway init -fromType=Conf` (`:43`).
- `environments_` prefix is case-insensitive (`:67`); built-in placeholders `filename`, `workingDirectory`, `table` (`:106`).
- `[flyway.sqlserver.clean]` `mode` values `default`/`schema`/`all`, `schemas.exclude`; setting `mode` and `schemas` together is an error; clean never drops users (`:211-212`, `sqlserver-reference.md:99`). The repo sets `mode = "all"`.
- `kerberos.login.file` must be paired with `kerberosConfigFile` (`:210`); `connectRetriesInterval` defaults to 120 (`:84`).
- `initSql` is deprecated; use the `afterConnect` callback (`:85`, `:151`).
- `-workingDirectory` is the base for `configFiles`, `filterFile`, `rulesLocation` and report paths (`cli-reference.md:44`).
- Scoped command-line namespaces only work directly after the verb, so use full namespaces (`cli-reference.md:56-58`).
- `-outputFile`, `-q`, `-color`, `-outputLogsInJson` (`cli-reference.md:46-51`).
- `[flywayDesktop] schemaModel` is deprecated for `[flyway] schemaModelLocation` (`:236`). `[flywayDesktop.generate]` has `undoScripts` and `repeatableTypes` (`:237-238`).
- The root `redgateCompare.filterFile` isn't written for SQL Server since 13.9.0 (`:240`). This explains `flyway.toml:40`, which is harmless.
- LocalDB resolver `${localdb.pipeName}` (jTDS), using `.` instead of `localhost`, `ntlmauth.dll` (`:60`, `sqlserver-reference.md:26`, `:92`).
- `provisionMode=reprovision` goes on the command line only (`:143`).
- Multi-schema: `schemas` is case-sensitive; the first entry is the default and holds history; `createSchemas = false` needs the schema to exist; qualify object names (`oracle-reference.md:87-90`). Changing `table` makes Flyway look for a different history table (`:105`).

**Deployment, drift and code review [11, 13, 14]**
- `prepare -source=schemaModel` drops target schemas that aren't in the model, so set `schemaModelSchemas` (`deployment-and-drift.md:39`).
- `prepare` comparison options, filters and static data come only from TOML (`:37`). `prepare -source=migrations` skips callbacks and Java migrations (`:38`).
- `deploy` succeeds with a warning when the script is missing (`:41`). With `-drift` and `-changes` together, drift runs first (`:46`).
- Snapshot parent directories are created; snapshot history schema resolution; no snapshot during dry runs (`:45`, `:66-67`).
- The drift resolution folder is wiped each run, and generation failures don't fail the check (`:112-113`).
- `-changesSource=schemaModel` for state-based change reports (`:174`). Verify.
- SQLFluff isn't called when nothing is pending (`code-analysis.md:53`). `FLYWAY_ENV_NATIVE_SQLFLUFF=false`, bundle fallback, version banner (`:21-24`). GLIBC 2.35+ on Linux runners (`:23`).
- RG08 is postgres/snowflake only, so it has no effect in the repo's `sqlfluff.cfg` (`:80`). Full RG01 to RG23 table (`:73-95`). The `rules = RG01,RG02` + `exclude_rules = redgate` gotcha (`:128`).
- The `schemaModel` profile must be defined yourself (`:136-141`). The regex engine no longer converts line endings, so check `\r\n` (`:157`).
- JSON violation fields; SARIF 2.1.0 (`:177-178`). The Desktop Policies tab regenerates rule lines (`:195`).
- Pipeline stage order: run `check -code` before the build (`deployment-and-drift.md:163-168`). Keep OLD's broader gating and post-deploy `info`/`validate`/snapshot.
- Report changes: reports keep no history (archive each run), `schemaVersion` in the JSON, `-check.generateReport=false`, `FLYWAY_NEW_REPORTS=false` (`cli-reference.md:82`, `deployment-and-drift.md:184`).
- JSON timestamps carry a UTC offset from 13.2 (`cli-reference.md:81`).

**Desktop and MCP [08, 20]**
- Full 12-tool MCP reference with parameters and returns; the `*` vs IDs rule; dependencies included automatically (`ai-and-mcp.md:97-113`). Confirmed against the live server in this session.
- `generate_migrations` returns `undoScriptsGenerated`; `test_migrate` can force a rebuild (`:106`, `:108`).
- Marketing mentions a migration-status tool that doesn't exist (`:152`).
- Desktop AI services: the endpoint `api.prod.prompt.redgate-platform.com:443`, Portal setting, no offline permit, Preview features toggle, 50-character limit, data handling (`:154-178`). Mark as preview.
- "Start here" appears whenever the schema model is empty (`desktop-reference.md:51`). This explains the skill's "ignore Start here".
- Desktop offers "baseline and continue" on a non-baselined target (`:72`). The skill should warn the user before deploying to Test.
- Desktop deploy page; Migrate, Info, Validate, Check, Clean and Undo buttons; "View command" (`:43`, `:46`, `:73-74`).
- "Ok to erase and rebuild" prompt (`:98`); Desktop hard-codes `cleanDisabled=true` except for shadow re-provisioning (`:78`); shadow re-provision triggers and one shadow per developer (`:80-84`).
- Desktop deploy saves a snapshot by default (`:142`). Badge on uncommitted objects; schema model history, preview (`:60-62`).
- Fixed SQL Compare option `AddDatabaseUseStatement=false` (`:123`). `IgnoreSynonymDependencies` removed (`:124`). No object locking and no SSMS integration (`:162`).
- `claude --mcp-config <path>` (`ai-and-mcp.md:68`).

**SQL Server [04, 10, 12]**
- Fabric SQL Database is foundational only; Fabric Data Warehouse status conflicts between docs pages; Lakehouse, Eventhouse, Cosmos DB and Mirrored Databases aren't supported (`sqlserver-reference.md:15-16`).
- SQL Server 2025, RDS, Google Cloud SQL Server and Babelfish support (`:11-17`).
- `errorOverrides` can't be combined with `batch = true`; Desktop adds the PRINT override by default; `deploy` honours it (`:79-80`).
- SSL handshake error text and the "it's the Microsoft driver" talking point (`:68-69`).
- `entraId` is an alias for `azureAdInteractive`; managed identity is the most secure option (`:37-38`).
- `schemas` is ignored by `diff`/`prepare` on SQL Server; `includeDependencies` defaults to true (`:98`, `:106-107`).
- Docker provisioner TOML shape, `keepAlive`, `iAgreeToTheDBVendorsEula` for SQL Server (`arch-mysql-docker.md:34-52`, `:147-149`). Preview.

**Versions [25]**
- Latest engine 13.11.1, Desktop 9.10.9 bundling `13.11.1-rc3055` (`release-status.md:11-12`, `:107-108`). Re-check, because both libraries are over two weeks old.
- The 11 to 12 breaking-change table (`release-status.md:25-38`).
- 12.1.0 removed `IgnoreSynonymDependencies`; 12.2.0 renamed Code Analysis to Code Review in output and added SARIF; 12.5.0 deprecated `initSql`; 12.6.2 `${env.X}` everywhere; 12.8.0 PAT env-var bug (use 12.8.1+); 12.11.0 interactive EULA prompt without `-IAgreeToTheEula`.
- 13.1.0 `afterConnect` fix; 13.2.0 JSON timestamps; 13.5.0 `-X` origins and MCP tool rename; 13.9.0 reports reimplemented; 13.11.0 `info` shows `Below Baseline`/`Ignored` with `baselineOnMigrate`, docker provisioner uses a dedicated `flyway` database; 13.11.1 distrusted CAs blocked in bundled JREs and Docker images.
- Only the latest 13.x line is patched; 12.x stopped at 12.11.0 (`:13`, `:17`).
- Offline permits warn 30 days before expiry; the Desktop permit uses productCode 64; permits are stored in `%APPDATA%\Redgate\Flyway CLI` (`editions-and-licensing.md:101-108`).
- Deprecations table with replacements (`release-status.md:132-149`).
- Roadmap items, labelled not released (`release-status.md:110-125`).
- Desktop builds to avoid: merge NEW's 9.2.3 and 9.7.2 mentions with OLD `25:104`.

**New file: moving off SQL Change Automation or SQL Source Control** (from `sca-to-flyway-upgrade.md`, factual sections only)
- SCA lineage (ReadyRoll), project contents, header-ID tracking (`:11-14`); status quotes, retired from sale but still supported with no end-of-life date (`:31-36`).
- `ProgrammableObjectHandling` mapped to `R__` or versioned migrations (`:15`, `:57`).
- `__MigrationLog` is not converted, so leave it or filter it (`:60`, `:98`, `:223`).
- Capability mapping table, including the PowerShell cmdlet equivalents (`:52-75`). Official migration steps; no importer exists (`:79-91`). Practical checklist (`:93-100`).
- SQL Clone baselines replaced by the backup provisioner, which is preview; the Redgate Clone provisioner is deprecated (`:63`).
- SQL Source Control facts and limits (`:143-188`); importing into Desktop and `flyway init -fromType=SqlSourceControl` (`:214-219`); capability table (`:191-209`); gotchas (`:221-232`).
- Shadow DB must be pre-created with settings, linked servers and filegroups (`:64`, `:83`).
- Use Backup as Baseline as the default route (OLD 07), not NEW's "generate a new baseline script" (`:85`).

**SSDT facts [06]** (from `competitive.md:87-101`, neutral parts only)
- SDK-style project support by IDE; `azure/sql-action` v2.3; code-analysis warnings don't fail the build by default.

**Library structure**
- A `last-verified` date at the top of each file.
- A sources list at the end of each file, and a `sources.md`-style refresh routine.
- A `field-notes.md`-style file for fixes found in real use. Keep it outside the library folder, like the decision log.

## 7. Leave out

- NEW `CLAUDE.md` persona: Laura, sales stages, live-call virtual support mode, `laura-writing-voice` / `redgate-house-style` hooks, demo and campaign guidance, field notes as "Laura's".
- Edition positioning and upsell framing; Teams and Community comparison tables; commercial licence terms; pre-2024 winback history (`feature-history.md:9-19`, `:43-134`); "position Enterprise for every SCA customer" (`sca-to-flyway-upgrade.md:38`, `:102-134`).
- `competitive.md`, apart from the neutral SSDT block above.
- Per-entry Owner and Escalate fields in the troubleshooting files ("SE (Laura)", Dev/DBA/DevOps).
- `oracle-reference.md`, `postgres-reference.md`, `mysql-reference.md`, `databricks-snowflake-reference.md`, `arch-oracle-native-multischema.md`, `arch-postgres-shadow-gitlab.md`, `arch-mysql-docker.md`, `arch-sqlserver-gitlab-migrations.md`. The general facts from them are listed in section 6. If they're kept at all, put them in an appendix that isn't in the routing table, with the sales notes removed.
- Resolvers not relevant to the sandbox: Lakebase, Databricks, Dapr, GCSM, HashiCorp Vault.
- The Insights PAT setup (`deployment-and-drift.md:139-153`), which is already in OLD 18.
- The bash/`jq` edition check (`cli-reference.md:114`, `editions-and-licensing.md:92`). Write a PowerShell equivalent instead.
- `pizza-schema-sqlserver-2022.sql`. It conflicts with "never run SQL against the user's databases", and with the rule that Dev must start from real tables. At most, keep it as an optional seed the user runs themselves.

## 8. Gaps NEW doesn't cover (OLD stays authoritative)

Discovery, defaults and the decision log (01). Proof of concept (05). SSDT paths and cutover (06). Script runners, Backup as Baseline and side-by-side running (07). Developer workflows (08). Many teams, version collisions and CODEOWNERS (09). Fresh vs configured projects, JDBC URL forms, the Entra mode list with driver floors, MI ports, GitHub OIDC and Key Vault (10, 12). Undo in depth, failed migrations on SQL Server, and the recovery tree (14). Operations runbooks (15). Dev and test provisioning and Azure limits (16). Audit evidence (17). The Insights data policy (18). SQL Compare, Data Compare, Prompt and Monitor (19). Instruction files and the skills kit (20, 21). Production-first runbook and drills (22). The Azure SQL error table, Kerberos, Git, GitHub runner issues and OneDrive (23). Modes, workflow architect, scenarios and ticketing (27 to 30).

## 9. Repo issues found along the way (separate from the merge)

| Issue | Where | What both libraries say |
|---|---|---|
| `-baselineOnMigrate=true` on every Test and Prod migrate | `.github/workflows/GitHub-Flyway-CICD-Pipeline_Windows.yml:226`, `:278`; `Flyway-Live-Release.yml:182`, `:234`; `AzureDevOps/AzureDevOps-Flyway-CICD-Pipeline_Windows.yml:343`, `:500` | Baseline deliberately, once |
| `FLYWAY_VERSION: "Latest"` | All GitHub and ADO pipelines | Pin the version |
| `flyway auth -IAgreeToTheEula -email=... -token=...` in CI | `AzureDevOps/AzureDevOps-Flyway-CICD-Pipeline_Windows.yml:144`, `:253`, `:333`, `:411`, `:490`; Build `:140` | Never run `flyway auth` in CI; use `FLYWAY_EMAIL`/`FLYWAY_TOKEN` env vars. Neither documents `-email`/`-token` on `auth` |
| `-cleanDisabled=false` on Test and Prod `check` steps | `GitHub-Flyway-CICD-Pipeline_Windows.yml:213`, `:265` | Only on build and shadow |
| Deprecated `checkDriftOnMigrate` and `flywayServicePublish.publishReport` | GitHub `:197`, `:213`, `:226`, `:278`; ADO `:213`, `:343` | Deprecated in 13.10.0 |
| Check reports uploaded only on success, with `continue-on-error: true` | GitHub `:157`, `:217`, `:269` | Upload on failure too |
| `REDGATE_FLYWAY_MCP_SERVER_FEATURE` | `.mcp.json:7` | Not documented (V10) |
| Only `[flywayDesktop.generate] undoScripts = true` | `flyway.toml:36-37` | Also set `[flyway.generate] types = ["versioned", "undo"]` |
| No `rulesDialect = "tsql"` | `flyway.toml` `[flyway.check]` | Without it, script scope reviews as ANSI (`13:59`) |
| Project lives in OneDrive | Repo location | Desktop can break in OneDrive folders (`04:64`, `23:55`) |
| Environment names `Check`, `Build`, `Test`, `Prod` | `flyway.toml:137-144` | Neither library uses these names; 13.10.1 warns on case-only clashes (`25:117`) |

These may be deliberate, since the pipelines look like the standard Autopilot templates. Decide whether to change them or note them in the library as known differences.

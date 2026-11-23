<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway Desktop 9 reference

Scope: install and licensing, projects and TOML, schema model workflow, migrations workflow, filters, comparison options, provisioners, object support, snapshots, code review policies, Git. Desktop version tags are from the Desktop 8 and 9 release notes. Desktop bundles the Flyway CLI; each Desktop release pins an engine build (for example Desktop 9.10.1 ships engine 13.8.0).

## 1. Install and licensing

| Item | Detail |
|---|---|
| Platforms | Windows, macOS (Intel and Apple Silicon), Linux. Installer includes Flyway CLI |
| Other installers | Flyway CLI (Win/macOS/Linux), Docker image, GitHub Actions Marketplace (setup-flyway), Java API/Maven/Gradle |
| Enterprise extras | SQL Compare, SQL Data Compare, Schema Compare for Oracle, Data Compare for Oracle (Desktop tools license) |
| License model | Flyway Enterprise, per user contributing database changes. (Legacy Teams licences cover manual state-based work only; position Enterprise, see `editions-and-licensing.md`) |
| Desktop activation | Sign in with Redgate ID on first launch. Desktop tools entitlement required. Firewall must allow red-gate.com |
| Offline Desktop | User icon > Licensing > Manage offline license; permit from https://permits.red-gate.com/offline?productCode=64, or `REDGATE_LICENSING_PERMIT_PATH` |
| CLI licensing | PAT (`email` + `token`) for CI; offline permit (productCode=63, `offlinePermitPath`, 365-day or subscription end) for air-gapped; `flyway auth -IAgreeToTheEula` interactively; legacy `licenseKey` deprecated |
| Verify | `flyway --version` prints edition, e.g. "Flyway Enterprise Edition x.y.z by Redgate" |
| Trial | 28-day Enterprise trial |
| Legacy licensing client | No longer installed (Desktop 8.5.7) |
| Sign-in helper | Copy sign-in link to clipboard when browser cannot open (Desktop 9.5.3) |

Note: CLI 12.0.0 replaced `REDGATE_LICENSING_PERMIT_PATH` with `FLYWAY_OFFLINE_PERMIT_PATH` for the engine. The Desktop licensing page still documents `REDGATE_LICENSING_PERMIT_PATH` for Desktop.

## 2. Projects and flyway.toml

Default layout (from `flyway init` or Desktop):

| Path | Purpose |
|---|---|
| `flyway.toml` | Shared project settings, committed |
| `flyway.user.toml` | Per-user settings, git-ignored. Desktop stores development and shadow connection details here by default |
| `migrations/` | Migration scripts |
| `schema-model/` | Object-level scripts (only for DBs with Redgate comparison support) |
| `Filter.scpf` / `IgnoreRules.scpf` | Comparison filter (SQL Server) / ignore rules (Oracle), picked up from project root |
| `.gitignore` | Created by init |

- TOML load order: install `conf/`, user home, execution dir, working dir (each `flyway.toml` then `flyway.user.toml`). Later wins.
- `[flywayDesktop]` namespace: development and shadow environment ids, `showDeploymentDecision`, `generate` sub-namespace; `schemaModel` deprecated (use root `schemaModelLocation`). Use `developmentEnvironment` / `shadowEnvironment`: Desktop writes these, Redgate sample projects use them and the MCP docs require them. The namespace reference pages still show `development` / `shadow` (out of step; whether Desktop accepts them is unverified). See `common-architectures.md`.
- Connection dialogs write environments to disk. Credentials entered there can land in TOML as plain text. Use resolvers (`${env.X}`, `${localSecret.X}`, AWS Secrets Manager, Vault, Google Secret Manager, Dapr).
- Surrounding double quotes are stripped from JDBC URLs pasted into connection dialogs, such as those copied from the Snowflake website (Desktop 9.10.5). Databricks Lakehouse and Lakebase connections can sign in interactively through the browser; for Lakehouse choose "OAuth Interactive Sign-In" from the Authentication dropdown (Desktop 9.10.6). The Snowflake connection dialog has dedicated fields for server hostname, warehouse, database, role and authentication (Desktop 9.10.8).
- `.conf` projects: open from landing page; auto-upgraded to TOML with a backup (Desktop 8.4.1). Projects with deprecated config can be auto-upgraded on open (Desktop 9.2.3; lists changes from 9.4.3).
- Many settings "can't be set via Desktop but are honoured"; Desktop exposes them as **advanced parameters** on the Migrations page (for example `cleanDisabled`, `outOfOrder`, `failOnDrift`, `driftResolutionFolder`, `saveSnapshot`).
- Publishing to Flyway Insights can be configured from project settings (Desktop 9.10.2). Code review settings page has a search bar for policies (9.10.2).
- Desktop deletes its log files older than a month at startup; choose a different period or keep them all under Settings > Log retention (Desktop 9.10.3).
- Desktop shows the equivalent CLI under "View command", useful for teaching pipeline syntax.
- Multiple project tabs (Desktop 9.1.0). Dark mode and high DPI supported.

## 3. Schema model workflow (Enterprise; legacy Teams covers the manual parts)

1. Configure development database (Schema model page). Guided setup whenever the model is empty (Desktop 9.8.0).
2. Schema model page compares dev DB to `schema-model/`. Select changes, **Save** (dependencies pulled in for SQL Server and Oracle when `includeDependencies` is true; deselectable since 8.7.6).
3. Commit and push from the Version control side panel.
4. Teammates **Pull**; apply schema model changes to their own dev DB ("Update development"). Alert when upstream changes exist, checked on window focus (Desktop 9.8.3).
5. Generate migrations (Enterprise): shadow DB is built from existing migrations, compared to schema model, selected changes scripted as `V` (and optional `U` undo) scripts. Code review panel shown (9.2+). AI description suggested if AI enabled.
6. Or deploy state-based: Deploy page, select changes, review script, optionally save snapshot, deploy.

Object level history: view history per object from the schema model page. Enabled by default as a preview on Enterprise (Desktop 9.8.3); out of preview and GA in Desktop 9.10.7 (the roadmap still labels it Preview, checked 2026-10-26); diff header shows commit short hash (9.10.0); diff settings button (9.10.1); "Explain this change" with Redgate AI (9.9.1); commit authors shown by name, email on hover (9.10.2); heading shows current branch, schema and object type (9.10.3).

Schema model page shows a blue badge on objects and object groups with uncommitted changes (Desktop 9.10.4).

Schema model history (preview, Desktop 9.10.8): recent commits across the whole schema model, filterable down to individual objects.

Limitations of state-based deploy: no renames, splits, data motion, NOT NULL without default on populated tables. Use migrations for those.

## 4. Migrations workflow

| Task | Desktop behaviour |
|---|---|
| Add migration | Versioned default version `001_yyyymmddhhmmss` style; next number follows the existing convention |
| Baseline existing DB | Guided baseline script creation (8.6.0); find invalid objects before baselining; or use a provisioner (backup, snapshot) instead of a baseline script |
| Deploy to non-baselined non-empty target | Offers to baseline and continue (Desktop 9.8.0) |
| Manual deploy | Dedicated Deploy page for migrations projects (Desktop 9.0.0); summary drawer after deploy (9.7.2 pulled) |
| Run commands | Migration scripts page: Migrate, Info, Validate, Check, Clean, Undo, etc. with advanced parameters |
| Automated deployment page | Generates recommended CLI scripts (8.4.0), dry run (8.5.9), drift and snapshot usage (8.5.14), GitHub Actions workflows using the Flyway GitHub Actions (9.4.2), manual approval workflows with GitHub environments (9.5.0), rollback scripts (9.0.1). Newer page in public preview (9.6.5) |
| Undo scripts | Generate alongside versioned scripts (Enterprise) |
| Generate without shadow | Out of preview (Desktop 8.5.0) |
| Clean | Confirmation modal requires ticking "Ok to erase" (9.6.2). Desktop hard-codes `cleanDisabled=true` except when re-provisioning shadow |

Shadow database rules:
- Must be disposable; Desktop cleans or re-provisions it when you visit Generate migrations.
- Re-provisioned only when needed: checksum changes, shadow version ahead of scripts, name/description mismatch, previous failure, or only repeatables exist. Otherwise pending migrations are applied on top.
- Best practice: one shadow per developer per project, on the same server as dev (cross-database dependencies).
- SQL Server options: LocalDB, Express, same instance, containers. Flyway can create the shadow automatically (8.6.0; guided shadow provisioning always on for Enterprise from 9.6.1).

## 5. Provisioners

| Provisioner (`provisioner =`) | Status | Engines | Use |
|---|---|---|---|
| `clean` | GA | All | Re-provision by dropping objects. Desktop default for shadow |
| `create-database` | Preview in docs; not labelled preview in Desktop since 9.6.5 ("Create empty") | SQL Server, MySQL, PostgreSQL | Creates DB if missing, resets to clean |
| `backup` | Preview in docs; not labelled preview in Desktop since 9.6.5 | SQL Server `.bak`, Oracle Data Pump `.dmp` | Provision to a baseline state with data and history table |
| `snapshot` | Preview | Uses snapshot file + `snapshotVersion` | Fast shadow at version N (schema only) |
| `docker` | Preview (Enterprise) | SQL Server, PostgreSQL, MySQL, Oracle | Auto-detects engine/version from target or `sourceEnvironment`; `iAgreeToTheDBVendorsEula = true` for SQL Server and Oracle; container kept alive by default. Desktop "Provision with Docker" |
| `docker-compose` | Preview | Any via compose file | Previous behaviour of `docker`; `composeFile`, `services`, `waitTimeout` |
| `clone` (Redgate Clone) | **Deprecated** | | Removed from Desktop connection dialogs in Desktop 9.0.0; deprecated in engine and will be removed |

- Docker provisioner only offered in Desktop for SQL Server, Oracle, PostgreSQL, MySQL projects (9.8.1/9.8.2). Docker-provisioned connection details are not saved (9.8.2). Docker errors now explained (9.9.1). Development and target connections ask for "Ok to erase and rebuild" when using a provisioner that erases the database (Backup, Snapshot or Create Database) (Desktop 9.10.8). From engine 13.11.0 the `docker` provisioner builds SQL Server and PostgreSQL in a dedicated `flyway` database and Oracle in a dedicated `FLYWAY` schema.
- Old `docker` configs with only compose keys are forwarded to `docker-compose` with a warning; mixing compose keys and smart keys errors.
- The Provisioning concept page still says Desktop supports Redgate Clone via the UI; that is out of date.

## 6. Filters

| DB | File | Format | Default location / setting |
|---|---|---|---|
| SQL Server | `Filter.scpf` | XML `NamedFilter` with per-object-type `Include` + `Expression` (`@NAME`, `@SCHEMA`, LIKE/NOT LIKE, `[_]` to escape underscore). `None` node sets default | Project root, or `[redgateCompare.sqlserver] filterFile` |
| Oracle filters | `Filter.scpf` | Oracle post filter format | `[redgateCompare.oracle] filterFile` |
| Oracle ignore rules | `IgnoreRules.scpf` | JSON; regex per object type with `\!` negation and `\&` AND | `[redgateCompare.oracle] ignoreRulesFile` |
| PostgreSQL, MySQL | Redgate Compare filter format | | `[redgateCompare] filterFile` |

- Filters apply after comparison (no speed gain). Oracle ignore rules exclude before comparison (faster); prefer them.
- Defaults: SQL Server new projects exclude Users and Certificates. Flyway filters out users and secure objects by default.
- Dependencies of selected objects are pulled in even if filtered (SQL Server, Oracle).
- Filters apply to all comparisons: schema model, generation, drift. Override for drift with `check.filterFile`.
- Desktop filter UIs: SQL Server (8.2.0, redesigned 8.7.11), Oracle (8.7.11), PostgreSQL (9.5.2, multi-rule 9.5.4, any-type 9.5.5), Databricks Lakebase (9.8.1). Unsupported expressions from imported files show read-only.
- Alternatives: edit in SQL Compare / Schema Compare for Oracle, or by hand; commit the file.
- Drift resolution can generate a filter file with drift exclusions (SQL Server, Oracle).

## 7. Comparison options

- Schema model tab > Static data & comparisons. Available for SQL Server and Oracle in the UI; others via TOML.
- TOML: `[redgateCompare.sqlserver.options.behavior]`, `...options.ignores` (Enterprise), `...data.options.comparison|deployment|mapping` (Teams); Oracle equivalents under `redgateCompare.oracle`.
- Some SQL Compare options are hard-coded in Flyway (for example `NoTransactions=true`, `NoErrorHandling=true`, `AddDatabaseUseStatement=false`).
- Recent options: Oracle preserve case of schema names in deployment scripts, preview (9.10.4, engine `preserveIdentifierCase` 13.9.0); Oracle ignore invisible columns/indexes (9.1.0); Oracle `IncludePermissionsUserCheck` (9.2.3); Oracle `ONLINE` index clause (9.6.2, engine `IncludeOnlineIndexCreation` 13.0); Oracle existence checks preview (9.5.3); SQL Server INSERT existence checks for data deployment (9.4.3); Oracle `IgnoreIndexRelatedPrimaryKeyDiffs` (8.5.15). SQL Server `IgnoreSynonymDependencies` removed (Desktop 9.1.1, engine 12.1.0).
- Static data: track tables (Enterprise); SQL Server per-table WHERE clause (8.4.5).

## 8. Object support summary

| DB | Comparison engine | Notes |
|---|---|---|
| SQL Server | SQL Compare / SQL Data Compare engine | Object coverage follows SQL Compare. Users and certificates filtered by default. Kerberos supported for advanced capabilities (9.2.3); Managed Identity (8.5.9) |
| Oracle | Schema Compare for Oracle engine | Filter UI supports all object types Schema Compare for Oracle supports. Needs Schema Compare for Oracle permissions. Oracle 11g support to be removed in a future major (warning in 9.10.0) |
| PostgreSQL, MySQL | Redgate comparison | Schema model and generation supported |
| Snowflake, Databricks | Advanced capabilities in public preview (Desktop 9.9.0 Snowflake, 9.6.0 Databricks); Snowflake Postgres (9.8.4); Databricks Lakebase and Lakehouse (9.6.3) |

Detailed per-object-type lists are not published in the Flyway docs; point customers to the SQL Compare and Schema Compare for Oracle documentation (unverified that coverage is identical in every case). Review "generated scripts that may need extra review" before trusting generated SQL for renames and data motion.

## 9. Snapshots in Desktop

- Save snapshot to the target's snapshot history table when deploying from the schema model (8.5.16).
- Advanced parameters for `migrate.saveSnapshot`, `undo.saveSnapshot`, `snapshot.filename`, `snapshot.historyLimit`, `snapshot.historyTable` (8.5.13).
- Deploy saves a snapshot **by default** (Desktop 9.10.0), so drift checks and rollbacks work without extra setup.
- Drift check from the Migration scripts page (Check > drift), resolution scripts generated (8.7.5). Revert/incorporate scripts must be run from the CLI (`deploy` with custom args not available in Desktop).

## 10. Code review policies

See `code-analysis.md`. Summary: code review panel on generate/deploy screens (9.2 preview), apply fix (9.3.3), **Code Review Policies** tab in project settings (9.7.0) writing `sqlfluff.cfg` and `rulesConfig`. SQLFluff only; regex rules by hand.

## 11. Git integration

| Feature | Detail |
|---|---|
| Built-in client | Teams and Enterprise: clone (open from VCS), pull, commit, push, create/switch/delete branches, add remote |
| Requires Git | Git must be installed and on PATH ("Download Git" button 8.3.8; clearer error 9.9.1) |
| Hosts | Any Git host (Azure DevOps, GitHub, GitLab, Bitbucket, CodeCommit) |
| Non-Git VCS | Use Desktop to save to disk, commit with your own client |
| Push rejected | Explains remote has new commits and offers "Pull changes" (9.5.10) |
| Diff viewer | Previous/next navigation and "2 of 5" position (9.0.3, 9.8.1) |
| Merge conflicts | Resolve in files; schema model is per object, so conflicts are object-level |
| Branch DBs | Tutorials for database-per-branch and recreate-on-switch |

No object locking and no SSMS integration (Redgate has no plans for locking without demand).

## Sources
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/flyway-desktop-8-release-notes-294781518.html
- https://documentation.red-gate.com/fd/installers-172490864.html
- https://documentation.red-gate.com/fd/licensing-164167730.html
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/quickstart-guides/quickstart-flyway-desktop
- https://documentation.red-gate.com/flyway/database-development-using-flyway/about-flyway-desktop
- https://documentation.red-gate.com/flyway/flyway-concepts/flyway-projects
- https://documentation.red-gate.com/flyway/flyway-concepts/version-control
- https://documentation.red-gate.com/flyway/flyway-concepts/schema-model
- https://documentation.red-gate.com/flyway/flyway-concepts/environments
- https://documentation.red-gate.com/flyway/flyway-concepts/environments/provisioning
- https://documentation.red-gate.com/flyway/flyway-concepts/environments/shadow-and-build-environments
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting/clean-provisioner
- https://documentation.red-gate.com/fd/backup-provisioner-277578935.html
- https://documentation.red-gate.com/fd/create-database-provisioner-291931544.html
- https://documentation.red-gate.com/fd/docker-provisioner-277578938.html
- https://documentation.red-gate.com/fd/docker-compose-provisioner-346163424.html
- https://documentation.red-gate.com/fd/redgate-clone-provisioner-277578939.html
- https://documentation.red-gate.com/fd/snapshot-provisioner-277578940.html
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace
- https://documentation.red-gate.com/flyway/reference/configuration/redgate-compare-namespace
- https://documentation.red-gate.com/flyway/reference/configuration/redgate-compare-namespace/redgate-compare-sql-server-namespace
- https://documentation.red-gate.com/flyway/flyway-concepts/database-comparisons
- https://documentation.red-gate.com/flyway/flyway-concepts/database-comparisons/comparison-filtering
- https://documentation.red-gate.com/flyway/flyway-concepts/database-comparisons/comparison-options
- https://documentation.red-gate.com/flyway/reference/filter-formats
- https://documentation.red-gate.com/flyway/reference/filter-formats/sql-server-filter-format
- https://documentation.red-gate.com/flyway/reference/filter-formats/oracle-ignore-rules-format
- https://documentation.red-gate.com/flyway/database-development-using-flyway/updating-configurations/tutorial-update-sql-server-filter-configuration
- https://documentation.red-gate.com/fd/oracle-filters-ignore-rules-138347101.html
- https://documentation.red-gate.com/flyway/database-development-using-flyway/updating-configurations/tutorial-update-comparison-options
- https://documentation.red-gate.com/fd/flyway-desktop-using-oracle-138346957.html
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools
- https://www.red-gate.com/blog/announcing-the-flyway-docker-provisioner-now-in-preview-in-flyway-enterprise/
- https://documentation.red-gate.com/flyway/learn-more-about-flyway/troubleshooting
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine (13.11.0 docker provisioner database)

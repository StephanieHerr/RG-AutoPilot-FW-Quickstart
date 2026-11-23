<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# SQL Change Automation (SCA) to Flyway Enterprise upgrade

Scope: what SCA was, its status, why Flyway is the upgrade path, capability mapping, how to move an SCA project, how to position Flyway Enterprise to SCA / SQL Toolbelt customers, gotchas. SQL Source Control (SoC): what it is and does (section 7) and moving SoC projects to Flyway Desktop (section 8).

## 1. What SCA is

| Component | Description |
|---|---|
| Lineage | Formerly **ReadyRoll**. Redgate's migrations-based approach for SQL Server, after SQL Compare (state) and SQL Source Control (state, 2010) |
| Projects | `.sqlproj`-based SCA projects, authored in **Visual Studio** or the **SSMS extension**. SQL Server only |
| Project contents | `Migrations`, `Programmable objects`, `Pre-deployment`, `Post-deployment`, `Schema-model` (offline schema model), `Additional scripts`, `Unsupported`, `Provisioning`, `[Name].sqlproj`, `[Name].sqlproj.user`, `Filter.scpf` |
| Migrations | Files must start with a number and end `.sql` (for example `0005_Alter-Customer-Add-PhoneNo.sql`). Each has a unique **ID in the header**; tracking is by ID, so files can be renamed after deployment. Order by folder path then numeric prefix |
| Programmable objects | Stored procedures, views, functions, DDL triggers stored as repeatable scripts, redeployed when checksum changes, run after migrations. Setting `ProgrammableObjectHandling`: `UseRepeatableScriptsForAllObjects` (default), `UseRepeatableScriptsForModifiedObjects`, `ScriptInMigrations` |
| Pre/post-deployment scripts | Run on every deployment, support SQLCMD syntax, not in a transaction by default |
| Offline schema model | Read-only object-level scripts for history in VCS |
| Tracking table | `__MigrationLog` in the target database (default `[dbo]`), plus a `__MigrationLogCurrent` view (view name unverified) |
| Variables | SQLCMD variables (`$(DatabaseName)`, `$(DeployPath)`, custom); env vars override in Azure DevOps and Octopus |
| Baseline | Baseline script, or a SQL Clone image as baseline. `ForceDeployWithoutBaseline` safety variable |
| Shadow DB | SCA creates the shadow database automatically |
| PowerShell module | Cmdlets including `Invoke-DatabaseBuild`, `New-DatabaseBuildArtifact`, `Export-DatabaseBuildArtifact`, `Publish-DatabaseBuildArtifact`, `New-DatabaseReleaseArtifact`, `Use-DatabaseReleaseArtifact`, `Export-DatabaseReleaseArtifact`, `Invoke-DatabaseTests` (tSQLt), `Sync-DatabaseSchema`, `New-DatabaseConnection`, `Test-DatabaseConnection`, `New-DatabaseDocumentation` |
| CI/CD add-ons | Azure DevOps, Team Foundation Server, Octopus Deploy, TeamCity, Bamboo, Jenkins |
| SoC projects | SCA could also build and deploy SQL Source Control projects (state-based, less control) |
| Bundling | Available with the SQL Toolbelt bundle. Historically in Redgate's DevOps bundles (SQL Toolbelt, SQL Automation bundles) (bundle names beyond "SQL Toolbelt" unverified) |

## 2. Status (official statements)

| Source | Statement |
|---|---|
| Redgate SCA support page (current) | "SQL Change Automation is retired from sale and is not available to new users. It is still available for purchase of additional entitlements if you are an existing SQL Change Automation customer, or if you have an active license of the SQL Toolbelt bundle. We are continuing to support and maintain SQL Change Automation." Non-SCA customers are directed to Flyway Enterprise |
| Flyway docs, transition page | "Flyway Enterprise is the next version of SQL Change Automation." Side-by-side install allowed, but use on different projects. SCA only available for users with an active SQL Toolbelt license |
| Redgate forum, Jan 2023 (staff) | Flyway Desktop is the next version of SCA; Redgate "will continue to support this for at least three years after we stop new sales" |
| SCA product page | Now redirects to the support page; SCA is not listed in Redgate's product menu |

Not published: an end-of-support or end-of-life date. Do not quote one. The "three years after stop of new sales" statement is a 2023 forum post, not a contractual notice; confirm with Redgate product/licensing before using it with a customer.

Licensing transition (docs): SCA users, and SoC / Source Control for Oracle users automating state-based deployments, move to **Flyway Enterprise**. The transition page still says SoC users not automating deployments move to Flyway Teams, but Teams has been closed to new customers since May 2025. **Position Flyway Enterprise for every SCA and SoC customer.** Confirm packaging for edge cases with Sales. Licensed per contributing user. Customers can keep using the old tools during transition (not on the same project); Sales can arrange licences covering both.

## 3. Why Flyway (value for an SCA shop)

- Same Redgate comparison engine (SQL Compare / Schema Compare for Oracle) underneath, so generated SQL behaves as they expect.
- Standalone Desktop (not in SSMS memory space), Windows, macOS, Linux; CLI and Docker for any agent OS. SCA PowerShell is Windows/.NET centric.
- 50+ database platforms; one tool for SQL Server, Oracle, PostgreSQL, MySQL, Snowflake, etc.
- Combined workflow: schema model for sharing (like SoC) plus generated migrations for deployment (like SCA).
- Enterprise-only additions: drift detection with resolution scripts, change reports, snapshots and rollback generation, auto-generated undo scripts, code review with Redgate rules and SARIF, Flyway Insights dashboard, secrets manager integration, Docker provisioner, MCP Server for AI agents, Desktop AI.
- Azure interactive / MFA authentication (not available in SoC).
- Pipelines-as-code with official GitHub Actions and examples for all major CI/CD systems instead of vendor plug-ins.

## 4. Capability mapping (SCA to Flyway)

| SCA | Flyway equivalent | Notes |
|---|---|---|
| SCA project (`.sqlproj`) | Flyway project folder with `flyway.toml` (+ `flyway.user.toml`) | No project file tied to VS |
| VS / SSMS extension | Flyway Desktop (any IDE for editing) | No SSMS integration |
| Migrations `0001_x.sql` with header ID | Versioned `V<version>__<desc>.sql` | Flyway tracks by version + checksum, not by ID. Renaming or editing an applied file breaks validation |
| Programmable objects | Repeatable migrations `R__<desc>.sql` | Also run after versioned migrations, reapplied when checksum changes. Or keep them in versioned migrations |
| Pre/post-deployment scripts | Callbacks (`beforeMigrate`, `afterMigrate`, `beforeEachMigrate`, `afterClean`, etc.) | No SQLCMD `:r` includes; placeholders instead. Redgate asks SoC pre/post users to contact them |
| Offline schema model | Schema model (`schema-model/`) | Editable and deployable, not read-only |
| `__MigrationLog` / `__MigrationLogCurrent` | `flyway_schema_history` | Different table and semantics; not converted |
| SQLCMD variables | Placeholders `${name}`, environment overrides, resolvers | `$(var)` syntax must be rewritten |
| Baseline script | Baseline migration `B__` or `baseline` command + `baselineVersion` | Re-baseline in Flyway |
| SQL Clone image as baseline | `backup` or `snapshot` provisioner for shadow/build | Redgate Clone provisioner is deprecated |
| Shadow DB auto-created | Shadow environment; Flyway can create it (`create-database`, guided setup, `docker`) | Docs: SCA-style auto-creation is not the default; pre-create an empty shadow with required settings, linked servers, filegroups |
| `Invoke-DatabaseBuild` | `flyway migrate` against a clean build environment, `flyway check -code` | |
| `New-DatabaseReleaseArtifact` (change report, drift, update script) | `flyway check -changes`, `check -drift`, `check -dryrun`, `prepare` | Reports as HTML/JSON |
| `Use-DatabaseReleaseArtifact` | `flyway migrate` or `flyway deploy` | |
| Drift check in release artifact | `check -drift` with embedded snapshots and resolution scripts | |
| `Invoke-DatabaseTests` (tSQLt) | No built-in test runner found in docs; run tSQLt via callbacks or pipeline step (unverified best practice) | |
| `Sync-DatabaseSchema` | `flyway deploy` of a `prepare`d script, or Desktop update development | |
| `New-DatabaseDocumentation` | None (SQL Doc is separate) | |
| Azure DevOps / Octopus / TeamCity / Bamboo / Jenkins add-ons | Flyway CLI or Docker in pipeline YAML; official GitHub Actions; Azure DevOps template and examples | Pipelines must be rebuilt |
| `Filter.scpf` | Same format for SQL Server; copy into Flyway project root | |
| Static data | Enterprise static data tracking | |
| Rollback scripts | Auto-generated undo (`U__`) scripts, snapshot-based rollback | |

## 5. Migrating an SCA project (official steps)

For SCA projects in Visual Studio or SSMS (docs describe a fresh Flyway project, not a converter):
1. Install Flyway Desktop (Enterprise).
2. Create a new project.
3. Connect the development database.
4. Connect the shadow database (pre-create it; empty; include database settings, linked servers, filegroups).
5. Copy the SCA `Filter.scpf` into the Flyway project root, overwriting the default.
6. Generate a **new baseline** script for the project.
7. **Baseline downstream environments** (`flyway baseline -baselineVersion=<n>` or `baselineOnMigrate` on first deploy).
8. Rebuild CI/CD pipelines with the Flyway CLI.

For SoC projects deployed with SCA: import the SoC project into Flyway Desktop (section 8), then rebuild pipelines.

No automated SCA project importer is documented (Desktop import supports SoC and Source Control for Oracle only).

Practical checklist:
- Freeze SCA changes; ensure every environment is at the same SCA release.
- Keep SCA migration files out of the Flyway `migrations` folder (history is not converted). Archive or tag them in Git.
- Convert pre/post-deployment scripts to callbacks and SQLCMD variables to placeholders.
- Decide programmable objects strategy: `R__` repeatables vs versioned.
- Leave `__MigrationLog` in place (harmless) or drop once SCA is retired. Filter it out of comparisons if it shows up.
- Start using `saveSnapshot` on deploy from day one for drift checks.
- Pilot one database, then roll out.

## 6. Positioning the upsell

### Discovery questions
| Area | Questions |
|---|---|
| Current estate | Which SCA projects (VS vs SSMS)? How many databases and environments? Any SoC projects deployed by SCA? |
| Pipelines | Which CI/CD (Azure DevOps classic release, Octopus, TeamCity, Jenkins, GitHub)? Using add-ons or PowerShell cmdlets? Pipelines-as-code yet? |
| Pain | Shadow DB performance, VS version coupling, SSMS memory, Windows-only agents, cross-database dependencies, merge conflicts on migrations? |
| Governance | Drift incidents? Audit/compliance evidence required? Code standards enforced? Approval gates? |
| Platforms | Any Oracle, PostgreSQL, MySQL, Snowflake, Azure SQL / Fabric in the roadmap? |
| People | Who writes migrations: devs or DBAs? SQL confidence? Team size (per-user licensing)? |
| Licensing | SQL Toolbelt renewal date? Using SQL Clone for baselines? |
| AI | Are developers using Copilot, Claude Code, Cursor for SQL? Policy on AI-authored DB changes? |

### What they gain (lead with pain)
- Supported strategic path; SCA is retired from new sale.
- Drift detection plus generated revert/incorporate/filter scripts.
- Change reports, dry runs, snapshot-based rollback, auto undo scripts.
- Code review policy with fail-the-build and SARIF for GitHub/Azure DevOps.
- Cross-platform agents and Docker; multi-database coverage.
- Visibility: Flyway Insights deployments and DORA metrics (preview).
- AI governance: MCP Server keeps agent-authored changes in the same governed workflow.

### Common objections
| Objection | Response |
|---|---|
| "SCA still works, why move?" | It is retired from sale and maintained only; new capability lands in Flyway. Plan on your timeline, pilot now |
| "We will lose history" | Git history stays. SoC imports preserve settings and history. SCA migrations stay archived; Flyway starts from a baseline |
| "Rebuilding pipelines is effort" | Desktop's Automated deployment page generates CLI scripts and GitHub Actions; Redgate publishes example pipelines per CI system |
| "No SSMS integration" | Correct. Desktop is standalone; devs keep SSMS for editing. Faster: no polling, not in SSMS memory |
| "We rely on SQL Clone baselines" | Use `backup` or `snapshot` provisioner; Redgate Clone provisioner is deprecated |
| "Cost on top of Toolbelt" | Licensing exchange and dual-use during transition via Sales. Quantify drift incidents and manual script time |
| "Flyway is just migrations" | Enterprise adds schema model, generation, state deploys, drift, reports; same comparison engine as SCA |

## 7. SQL Source Control: what it is and does

Verified from the SoC 8 docs (space SOC8, the current version) on 2026-09-25. Page links: `SOC8/<id>` = `https://documentation.red-gate.com/spaces/SOC8/pages/<id>`.

### What it is
| Item | Detail | Source |
|---|---|---|
| Product | "An add-in for Management Studio that links your database to your source control system." Version-controls SQL Server schemas (and optionally static data) as object-level scripts | SOC8/296813678 |
| Engine | SQL Compare engine and a scripts folder. Three-way comparison between the database, the "transient" (local copy of the head revision) and the "working base" (state at your last commit or get latest) | SOC8/296813911 |
| Host | SSMS 18, 19, 20, 21 and 22 (8.1.0 added SSMS 22; ARM64 not supported). Windows only, .NET 4.7.2+ | SOC8/296813690, SOC8/296816084 |
| SQL Server | No SQL Server 2000, 2005, 2008/R2. For Azure SQL DB, Managed Instance, RDS, GCP and Entra MFA (Azure AD Interactive), the docs point to Flyway, "Redgate's next generation of SQL Source Control" | SOC8/296813690 |
| Release cadence | Frequent updates continue (8.1.25, 10 Sept 2026). No end-of-life notice on the docs or product page | SOC8/321586273 |
| Licensing | "SQL Source Control is part of SQL Toolbelt Essentials" (per user per year); standalone owners contact sales to renew. Docs also mention licensing through SQL Toolbelt and Flyway Enterprise | Product page, SOC8/296813690 |

### Development models
| Model | How it works | Trade-offs (docs) | Source |
|---|---|---|---|
| Dedicated | Each developer has their own copy (shared instance, local Developer Edition, LocalDB or SQL Clone). Get latest, develop, commit | "No risk of accidentally overwriting someone else's changes"; you maintain a database per developer | SOC8/296813867 |
| Shared | One database for all developers. Develop, then commit; Get latest not needed | "No safe way to test changes in isolation"; without object locking developers "may overwrite each others' changes by mistake"; "who made changes" is sometimes lost | SOC8/296813870 |

- Change attribution on a shared database comes from the SQL Server default trace, cached in tempdb and lost on restart unless a ChangeLog database is set up; "Changes made to data can't be logged." (SOC8/296813881)
- The docs lean to dedicated: "If developers regularly modify the same database objects, consider adopting a dedicated database development model." (SOC8/296813852)

### Object locking
- Lock an object so others can't edit it; "When you try to edit an object locked by someone else, the server returns an error." Enforced by a server-level DDL trigger (`RG_SQLSourceControl_DDLTrigger`) and a `RedGate` database, installed by a setup script that needs elevated rights. (SOC8/296813852, SOC8/296813857)
- Limits: "Anyone can unlock any locked object, no matter who locked it." Only defaults, queues, rules, functions, stored procedures, synonyms, tables, user-defined and table types, CLR types, views and XML schema collections can be locked. Not compatible with In-Memory OLTP, Amazon RDS or Azure SQL Database. Locks persist if SoC is uninstalled without the removal script. (SOC8/296813852, SOC8/296813857, SOC8/296813858)
- It works per server, so it serves the shared model; it has no practical effect across dedicated copies (inference, not stated in the docs).

### Version control systems
| VCS | Integration | Source |
|---|---|---|
| Git | Full. Git for Windows 2.3+ on PATH; SSH works but key passphrases are not supported. Commit is local, then **Push** from the Commit tab banner; Get latest does **Pull from remote repository** then **Apply changes to database** | SOC8/296813693, SOC8/296813771, SOC8/296813778 |
| SVN | Full (1.5+) | SOC8/296813690 |
| TFS / Azure DevOps (TFVC) | Full (TFS 2008+, including Azure DevOps). Git-based Azure DevOps repos use Git mode | SOC8/296813690, SOC8/296813708 |
| Mercurial, Perforce, Plastic SCM, others | "Custom" setup: XML config of command-line hooks, with presets for these; any VCS with a command line | SOC8/296813724, SOC8/296813732 |
| Working folder | "SQL Source Control doesn't automate any source control operations": scripts are saved to a folder and committed with your own client | SOC8/296813735 |

"SQL Source Control only has full integration with Git, SVN, and TFS." (SOC8/296813723). Vault and ClearCase support for SoC is (unverified).

### Static data, migrations, filters
- **Static data:** "You can only source-control data in tables with a valid primary key." No row limit stated, but "Source-controlling very large static data tables might cause SQL Source Control to time out." Schema and data changes to the same object are committed or retrieved together. (SOC8/296813800, SOC8/296813783)
- **Migration scripts:** the Migrations tab "was deprecated for all new projects in Jan 2020"; "As of Nov 1, 2023, if you want to use migration scripts for deployments, we recommend transitioning to Flyway." Linking the SoC project to an SCA project was the other route. (SOC8/296813807, SOC8/296813851)
- **Pre/post-deployment scripts:** one of each per project. Run by SQL Compare (UI or CLI 13.4.7+) and SCA (3.0.4+), "but not SQL Data Compare"; also run locally on Get latest and Undo. Must be idempotent, run outside the main transaction, "SQLCMD syntax and variables are not supported", and "There is no SQL parsing before the scripts are committed." (SOC8/296813859)
- **Filters:** exclude by object type, name or schema; filtered objects never appear in Commit, Get latest or Undo; can be committed to share with the team. The SoC filter page does not name the file; Flyway's importer carries SoC filters across (section 8). (SOC8/296813828)
- **Comparison options:** SQL Compare options (defaults include IgnoreWhiteSpace, IgnoreUserProperties, IgnoreCertificatesAndCryptoKeys, ForceColumnOrder), local to the machine until committed. (SOC8/296813873)

### What it can't do
- **No deployment of its own.** Deploy with SQL Compare Pro, the SQL Compare CLI, or SCA in CI/CD; automated SCA deployment needs SQL Toolbelt or Flyway Enterprise licensing. (SOC8/296813843, SOC8/296813847)
- **No drift detection or drift reporting** is documented in SoC. The SoC product page lists drift detection and reporting as Flyway capabilities.
- **No merge:** "You can't merge conflicts using SQL Source Control itself" (Keep mine or Take theirs; external merge tools only for stored procedures, and "The output from the merge tool is immediately executed on the database"). (SOC8/296813783)
- **No guaranteed rollback** of a failed commit or get: it "uses transactions to try to roll the changes back, but won't always be successful." (SOC8/296813691)
- **No CI/CD, change reports, code review, undo scripts, snapshots or non-SQL Server databases** in SoC itself.
- Runs inside the SSMS process; the performance page suggests "moving to Flyway". (SOC8/296813887)

### SoC vs Flyway Enterprise
| Capability | SQL Source Control | Flyway Enterprise |
|---|---|---|
| Where it runs | SSMS add-in, Windows | Flyway Desktop (Windows, macOS, Linux) plus CLI, Docker, CI/CD |
| Databases | SQL Server (cloud targets redirected to Flyway) | SQL Server, Azure SQL, Oracle, PostgreSQL, MySQL with comparison; Snowflake and Databricks comparison in preview; 50+ engines for migrations |
| Schema capture | Object-level scripts from the dev DB | Schema model (object-level scripts); same SQL Compare engine for SQL Server |
| Development models | Dedicated or shared | Per-developer development and shadow databases (Desktop's documented model); shared-model features such as locking are absent |
| Object locking | Yes (server DDL trigger, limited object types, anyone can unlock) | No |
| Change attribution | Default trace or ChangeLog database (shared model) | Git history; object-level history in Desktop (Enterprise preview from Desktop 9.8.3, GA in Desktop 9.10.7) |
| Version control | Git, SVN, TFVC full; others via command-line hooks or working folder | Built-in Git client (any Git host); other VCS by committing the project folder with your own client |
| Static data | Yes (primary key required) | Yes (Enterprise static data tracking) |
| Migration scripts | Deprecated since Jan 2020; Redgate recommends Flyway | Core: versioned, repeatable, undo, baseline; generated from the schema model |
| Pre/post scripts | One each, no SQLCMD | Callbacks (`beforeMigrate`, `afterMigrate` and others) with placeholders |
| Filters and comparison options | Yes (SQL Compare) | Yes; SoC settings carried over by the importer; `Filter.scpf` for SQL Server |
| Deployment | None; needs SQL Compare or SCA | `migrate`, or `prepare` + `deploy` (state-based), with approval gates in CI |
| Drift detection and reports | Not documented | `check -drift` with revert, incorporate and filter scripts; `check -changes`, `check -dryrun`; HTML/JSON reports |
| Code review | No | `check -code` (Redgate and SQLFluff rules, SARIF, fail the build) |
| Rollback | Undo of uncommitted local changes | Undo scripts, rollback scripts from `prepare` and snapshots |
| Entra MFA and cloud targets | Docs point to Flyway | Supported |
| AI and visibility | None | MCP server, Desktop AI, Flyway Insights (preview) |

## 8. SQL Source Control to Flyway Desktop (state-based)

- Status: SoC is still sold and included in SQL Toolbelt Essentials (as of 2026-09-25). A third-party vendor reported a 2023 Redgate docs banner announcing a 2025 end of life; current Redgate pages do not show one (unverified, do not quote).
- Import: Desktop **Import project... > SQL Source Control**, paste the SoC repository folder (Git only; SVN/TFVC need the working base path). CLI: `flyway init -projectName=MyProject -databaseType=<type> -from=C:\path\SoCProject -fromType=SqlSourceControl` (the docs example uses `Sqlite`; check the `init` database type values for SQL Server). Bulk import by looping the CLI.
- Preserved: comparison options, filters, static data config, Git history. Connection details are incomplete (SoC stores few); complete them in settings.
- One team lead imports, commits, pushes; others open from VCS. Tag the repo first; back up the local repo.
- Do not use SoC on the project after import. Pre/post deployment scripts: contact Redgate.
- Then deploy state-based (Deploy page or `prepare`/`deploy`), or start generating migrations with a shadow DB.
- Source Control for Oracle has an equivalent importer (passwords not imported).

## 9. Gotchas

- History tables differ (`__MigrationLog` vs `flyway_schema_history`); nothing is migrated automatically.
- Flyway validates checksums: editing or renaming an applied migration fails `validate` (SCA allowed renames).
- SCA orders by numeric prefix with padding rules; Flyway orders by version. Use timestamped versions to avoid clashes.
- SQLCMD syntax in SCA pre/post scripts does not run in Flyway.
- Programmable objects referencing each other: repeatables run in description order, not dependency order.
- Shadow DB must already exist (unless using a provisioner) and needs cross-database dependencies reachable.
- Do not run SCA and Flyway on the same database project.
- Object level history in Desktop is now available (Enterprise preview from Desktop 9.8.3, GA in Desktop 9.10.7), although the transition page still lists it as missing (not re-checked 2026-10-26).
- No object locking, no non-Git VCS client in Desktop.
- Cross-database and circular dependencies can block baselines; plan filters or provisioner-based baselines.

## Sources
- https://www.red-gate.com/products/sql-change-automation/support/
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools/sql-change-automation
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools/sql-source-control
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools/the-journey-to-flyway
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools/transition-license-information
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/transitioning-from-other-redgate-tools/deploying
- https://documentation.red-gate.com/flyway/database-development-using-flyway/importing-projects-from-other-redgate-tools
- https://documentation.red-gate.com/flyway/database-development-using-flyway/importing-projects-from-other-redgate-tools/tutorial-import-projects-from-sql-source-control
- https://forum.red-gate.com/discussion/89543/is-sca-going-away
- https://documentation.red-gate.com/sca
- https://documentation.red-gate.com/sca/developing-databases/concepts
- https://documentation.red-gate.com/sca/developing-databases/concepts/projects
- https://documentation.red-gate.com/sca/developing-databases/concepts/migrations/migration-scripts
- https://documentation.red-gate.com/sca/developing-databases/concepts/migrations/programmable-objects
- https://documentation.red-gate.com/sca/developing-databases/concepts/migrations/pre-deployment-and-post-deployment-scripts
- https://documentation.red-gate.com/sca/developing-databases/concepts/offline-schema-model
- https://documentation.red-gate.com/sca/developing-databases/concepts/advanced-concepts/variables
- https://documentation.red-gate.com/sca/developing-databases/concepts/baseline
- https://documentation.red-gate.com/sca/reference/powershell-cmdlets
- https://documentation.red-gate.com/sca/deploying-database-changes/add-ons
- https://documentation.red-gate.com/scas/working-with-the-ssms-extension/apply-changes-to-a-database
- https://www.red-gate.com/products/sql-toolbelt-essentials/
- https://documentation.red-gate.com/soc
- https://versionsql.com/help/redgate-is-ending-support-for-sql-source-control
- https://documentation.red-gate.com/flyway/flyway-concepts/migrations
- https://documentation.red-gate.com/fd/redgate-clone-provisioner-277578939.html
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/spaces/SOC8/pages/296813678
- https://documentation.red-gate.com/spaces/SOC8/pages/296813690
- https://documentation.red-gate.com/spaces/SOC8/pages/296813691
- https://documentation.red-gate.com/spaces/SOC8/pages/296813693
- https://documentation.red-gate.com/spaces/SOC8/pages/296813708
- https://documentation.red-gate.com/spaces/SOC8/pages/296813723
- https://documentation.red-gate.com/spaces/SOC8/pages/296813724
- https://documentation.red-gate.com/spaces/SOC8/pages/296813732
- https://documentation.red-gate.com/spaces/SOC8/pages/296813735
- https://documentation.red-gate.com/spaces/SOC8/pages/296813771
- https://documentation.red-gate.com/spaces/SOC8/pages/296813778
- https://documentation.red-gate.com/spaces/SOC8/pages/296813783
- https://documentation.red-gate.com/spaces/SOC8/pages/296813800
- https://documentation.red-gate.com/spaces/SOC8/pages/296813807
- https://documentation.red-gate.com/spaces/SOC8/pages/296813828
- https://documentation.red-gate.com/spaces/SOC8/pages/296813843
- https://documentation.red-gate.com/spaces/SOC8/pages/296813847
- https://documentation.red-gate.com/spaces/SOC8/pages/296813851
- https://documentation.red-gate.com/spaces/SOC8/pages/296813852
- https://documentation.red-gate.com/spaces/SOC8/pages/296813857
- https://documentation.red-gate.com/spaces/SOC8/pages/296813858
- https://documentation.red-gate.com/spaces/SOC8/pages/296813859
- https://documentation.red-gate.com/spaces/SOC8/pages/296813867
- https://documentation.red-gate.com/spaces/SOC8/pages/296813870
- https://documentation.red-gate.com/spaces/SOC8/pages/296813873
- https://documentation.red-gate.com/spaces/SOC8/pages/296813881
- https://documentation.red-gate.com/spaces/SOC8/pages/296813887
- https://documentation.red-gate.com/spaces/SOC8/pages/296813911
- https://documentation.red-gate.com/spaces/SOC8/pages/296816084
- https://documentation.red-gate.com/spaces/SOC8/pages/321586273
- https://www.red-gate.com/products/sql-source-control/

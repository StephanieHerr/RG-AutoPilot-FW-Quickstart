<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway feature history

**How to use:** date features ("when did X ship?"), and build "what's changed since you last looked" stories for winback campaigns, videos and demos. Pick the year the prospect last used Flyway and read forward. Versions and dates come from the official engine and Flyway Desktop release notes unless marked otherwise. For the last 6 months (breaking changes, point releases, current versions) use `release-status.md`, which has more detail and wins on any conflict. "Engine" = Flyway CLI/Docker/API; "Desktop" = Flyway Desktop GUI.

## Headline milestones

- **Jul 2019: Redgate acquires Flyway** (Boxfuse, Axel Fontaine's company), announced 24 Jul 2019, $10M investment in acquisition and development. Community edition stays Apache 2.0.
- **Aug 2019: Engine 6.0.0**, first major release under Redgate. Snowflake support followed in 6.1.0 (Nov 2019).
- **Sep 2020: Engine 7.0.0 introduces Flyway Teams**, combining the old per-schema Pro and Enterprise editions.
- **Nov 2021: Redgate Change Control becomes Flyway Desktop** (Desktop 5.0; public preview announced Sep 2021).
- **Jul 2022: Engine 9.0.0 adds the `check` command** (deployment reports: dry run, changes, drift). Code analysis (`check -code`, SQLFluff) followed in 9.1.x and reached Community in 9.4.0 (Sep 2022).
- **Sep 2022: per-user licensing, Teams and Enterprise sold per user**; per-schema licences closed to new customers. Desktop runs in Community (preview) from 5.16.0.
- **Oct 2023: Engine 10.0.0**: TOML config becomes the default format, Java 17 required (Java 8 retired), `auth` command for online licensing.
- **Jul 2024: Flyway Pipelines preview** (hosted deployment dashboard). Renamed **Flyway Insights on 10 Sep 2026**.
- **Nov 2024: Engine 11.0.0 adds `prepare` and `deploy`**: state-based deployment from the CLI. `generate`, `diff`, `model`, `diffText`, `add` out of preview.
- **Dec 2024: Native Connectors** (11.1.0, MongoDB via mongosh), extended to Oracle in 11.7.0 (Apr 2025).
- **May 2025: Teams closed to new customers** (14 May 2025); Community and Enterprise are the two editions sold. Desktop 8.0.0 the same month.
- **Nov 2025: snapshot history in the target database** (11.17.0): embedded snapshots after migrate/undo/deploy, the basis for easy drift checks and ad-hoc rollbacks.
- **Dec 2025: AI in Desktop** (8.7.0): AI migration summaries, descriptions and commit messages.
- **Jan/Feb 2026: Engine 12.0.0 (28 Jan) and Desktop 9.0.0 (3 Feb)**: Deploy page in Desktop, SQLFluff-based code review, MongoDB JDBC removed.
- **Jul 2026: Engine 13.0.0 ships the Flyway MCP Server** (`flyway mcp`, Enterprise, public preview) for AI coding agents.

## Timeline by year

### 2026

Engine 11.20.1 to 13.10.2 (12.0.0 on 28 Jan, 13.0.0 on 20 Jul). Desktop 8.7.x to 9.10.6 (9.0.0 on 3 Feb).

- Jan 2026: Engine 12.0.0. Breaking: MongoDB only via Native Connectors, default Redgate regex ruleset dropped (SQLFluff rules instead), `check.major/minor*` removed, `REDGATE_LICENSING_PERMIT_PATH` replaced by `FLYWAY_OFFLINE_PERMIT_PATH`, reports lose timestamp history. Redgate product update promotes AI script descriptions.
- Feb 2026: Desktop 9.0.0: dedicated Deploy page for migrations projects; Redgate Clone provisioner preview removed.
- Mar 2026: 12.1.0 Babelfish foundational support; snapshot history limit default 5. 12.2.0 "Code Analysis" renamed "Code Review", SARIF output, rules RG19 to RG21. Desktop 9.2.0 code review panel (preview) on generate and deploy screens.
- Apr 2026: 12.4.0 (14 Apr) Oracle `checksumIncludeReferencedScripts` setting; code review rule RG23. Desktop 9.2.3 (7 Apr, pulled; fixes in 9.3.0): advanced capabilities with SQL Server Kerberos authentication, Oracle `IncludePermissionsUserCheck` option, projects with deprecated config auto-upgraded on open. 12.5.0 Azure Key Vault resolver; `initSql` deprecated; secrets managers removed from Teams; Cassandra Native Connectors. Desktop 9.4.2 Automated Deployment page generates GitHub Actions workflows. "Looking forward to Flyway V13" blog (28 Apr).
- May 2026: 12.6.0 Native Connectors for `deploy`. 12.7.0 custom SQLFluff rules. Desktop 9.5.0 GitHub Actions with manual approval; state vs migrations choice moved to the Deployment page.
- Jun 2026: 12.9.0 distinct exit codes, `check.driftResolutionFolder`. 12.10.0 smart `docker` provisioner (old one renamed `docker-compose`); Cassandra Native Connectors default.
- Jul 2026: Engine 13.0.0 (20 Jul): Flyway MCP Server, drift/changes JSON ids, Oracle `includeOnlineIndexCreation`. 13.1.0 Databricks Lakebase preview, Databricks snapshot history. Desktop 9.6.0 Databricks advanced capabilities public preview; 9.6.3 Lakebase as its own database type.
- Aug 2026: 13.2.0 JSON timestamps with UTC offset (breaking); Community stops recognising `publishResult`. 13.4.0 uses OS proxy. Desktop 9.7.0 code review policies in project settings.
- Sep 2026: 13.6.0 code review profiles, `deploy` publishes to Pipelines, Snowflake Postgres recognised, Docker images on JRE 25. **Flyway Pipelines renamed Flyway Insights (10 Sep)**, Enterprise, Deployments and Deployment Metrics views in public preview. 13.7.0 MCP `test_migrate` and three-sided diff. Desktop 9.9.0 Snowflake advanced capabilities public preview; 9.9.1 "Explain this change" with Redgate AI; 9.10.0 deploy saves snapshot by default, Oracle 11g removal warning. Engine 13.8.0 and Desktop 9.10.1 (24 Sep); engine 13.8.1 (29 Sep) Cassandra Native Connectors hang fix. Desktop 9.10.2 (29 Sep) Flyway Insights publishing configurable in project settings.
- Oct 2026: 13.9.0 (1 Oct) OS proxy inheritance becomes opt-in (`FLYWAY_USE_SYSTEM_PROXIES=true`), new Flyway Report implementation on by default, Oracle `preserveIdentifierCase` comparison option (Preview). 13.10.0 (8 Oct) `checkDriftOnMigrate` deprecated, `lakebase` resolver for interactive Databricks Lakebase sign-in, plugin parameters settable per environment, MCP `generate_migrations` `generateUndoScripts`. Desktop 9.10.3 log retention setting; 9.10.4 Oracle preserve schema name case (preview). 13.10.1 (15 Oct) `databricks` resolver for browser-based OAuth sign-in to Databricks, Flyway prints the environment it is working on, Snowflake connections identify as `Redgate_Flyway`. Desktop 9.10.6 (14 Oct) interactive browser sign-in for Databricks Lakehouse and Lakebase connections.
- Announced: Oracle 11g support ends in the next major release (expected end 2026 or early 2027). Java 21 minimum announced for V13 (enforcement unverified, see `release-status.md`).

### 2025

Engine 11.1.1 to 11.20.0. Desktop 7.7.x to 8.7.x (8.0.0 on 7 May).

- Jan 2025: 11.2.0 `flyway init` converts `.conf` to TOML. 11.3.0 Native Connectors callbacks; DuckDB and Timeplus community support. Desktop 7.7.4 static data versioning in Teams.
- Mar 2025: 11.4.1 change reports for schema model (state) projects; migration tags (preview).
- Apr 2025: 11.7.0 Native Connectors for Oracle (clean in 11.7.1).
- May 2025: Teams closed to new customers (14 May; existing customers can renew). Desktop 8.0.0 (7 May, pulled; fixed in 8.0.1): new schema model view, Update development page, generate migrations without a shadow database, legacy `flyway-dev.json` removed. 8.0.2 PostgreSQL table partitioning.
- Jun 2025: 11.9.2 Microsoft Fabric SQL Database foundational support. Desktop 8.1.0 static data for PostgreSQL.
- Jul 2025: 11.10.2 Fabric Data Warehouse preview. 11.10.4 Oracle Flashback with Native Connectors; QuestDB community support.
- Sep 2025: 11.13.0 Couchbase foundational support (preview).
- Oct 2025: 11.14.1 first Redgate SQLFluff code analysis rules (RG01 to RG08); offline permits configurable in TOML/CLI.
- Nov 2025: 11.17.0 snapshots stored in a snapshot history table after migrate/undo/deploy; drift check warns (not fails) on first deployment. 11.17.1 snapshots to/from S3. Desktop 8.5.16 code analysis for state-based deployment scripts.
- Dec 2025: 11.19.0 CLI ships with Java 25. 11.19.1 Oracle `includeDependencies = false`. Desktop 8.7.0 AI summaries, AI migration descriptions, AI commit messages.
- Evolution page summary for 2025: state-based deployments, automated code reviews, advanced drift detection, backup/snapshot provisioners, drift correction scripts.

### 2024

Engine 10.5.0 to 11.1.0 (11.0.0 on 21 Nov). Desktop 7.0.3 to 7.7.0.

- Jan 2024: 10.7.1 ClickHouse (community contribution).
- Feb 2024: Desktop 7.1.1 dark theme.
- Mar 2024: 10.9.0 Cassandra preview (Redgate edition).
- Apr 2024: 10.11.0 `init` command (Desktop-compatible project); `communityDBSupportEnabled`. 10.12.0 Personal Access Tokens for licensing. Desktop 7.2.0 deploy directly from the schema model (state-based) in Desktop.
- May 2024: 10.13.0 Databricks support (community contribution); CLI on Temurin 17 JRE.
- Jul 2024: Flyway Pipelines preview (docs "Introducing Flyway Pipelines", published 5 Jul 2024). 10.16.0 `schemaModelLocation` in `flyway.toml`. 10.17.0 Cassandra out of preview, in open source.
- Sep 2024: Flyway Autopilot sample projects (FastTrack, Backup & Running) published (approximate, docs pages dated Sep 2024).
- Oct 2024: 10.19.0 CLI `add`, `diff`, `diffApply`, `diffText`, `generate` in preview. 10.20.0 PostgreSQL 17. Pipelines for PostgreSQL announced.
- Nov 2024: 10.21.0 legacy FL0 licence keys deprecated. 10.22.0 `diffApply` becomes `model`. Engine 11.0.0: `prepare` and `deploy` (state-based deployment), comparison commands GA, `cleanOnValidationError` removed, `check` build env needs a provisioner or `cleanDisabled=false`.
- Dec 2024: 11.1.0 Native Connectors for MongoDB (open source).

### 2023

Engine 9.11.0 to 10.4.1 (10.0.0 on 31 Oct). Desktop 6.0.1 to 7.0.2 (7.0.1 on 21 Dec).

- Feb 2023: 9.14.1 multi-release builds for Java 8 and Java 17 ahead of a move to Java 17.
- Mar 2023: Desktop 6.2.0 MySQL connection dialog (Desktop MySQL comparison support around this time; exact GA version unverified).
- Jun 2023: 9.20.0 latest SQL Server 2022 support.
- Jul 2023: Desktop 6.5.0 projects upgrade from JSON to TOML.
- Sep 2023: Desktop 6.7.0 trials for Teams and Enterprise from the app.
- Oct 2023: Engine 10.0.0 "Flyway V10 has landed": TOML the default config format; Java 8 retired, Java 17 required; `auth` command and offline permits; database support modularised; Maven group `com.redgate.flyway`; script migrations, info filters and several callbacks moved to Community; SingleStore in Community; Cloud Spanner out of beta.
- Nov 2023: 10.1.0 MongoDB preview (Redgate edition).
- Dec 2023: 10.2.0 start a trial with `auth`. Desktop 7.0.1: version control side panel; `flyway-dev.json` deprecated; secrets manager credentials.

### 2022

Engine 8.4.0 to 9.10.2 (9.0.0 on 13 Jul). Desktop 5.8.x to 6.0.0 (6.0.0 on 28 Dec).

- Jul 2022: Engine 9.0.0: `check` command with deployment reports; `cleanDisabled` defaults to true; older DB versions moved to Teams. Desktop 5.15.2 undo script generation; Teams trial.
- Aug 2022: 9.1.5/9.1.6 SQLFluff in Docker image, code analysis (`check -code`) with dialect auto-detect.
- Sep 2022: 9.3.0 change and drift reports leave Teams preview (paid). 9.4.0 code analysis in Community; SQL Server 2022. Per-user licensing starts; Flyway Enterprise sold alongside Teams. Desktop 5.16.0 Community edition (preview).
- Nov 2022: 9.8.0 `check.failOnDrift`; SingleStore (Teams); engine reads TOML config (via jackson-dataformat-toml). Desktop 5.16.11 PostgreSQL object-level history and migration generation GA.
- Dec 2022: 9.9.0 BigQuery GA. Desktop 5.16.17 `check -code` in Desktop. Desktop 6.0.0 static data comparison out of preview (SQL Server, Oracle).
- Snapshot command: in use with `check -changes` by Dec 2022 (9.10.1); exact introduction version (unverified).

### 2021

Engine 7.4.0 to 8.3.0 (8.0.0 on 6 Oct). Desktop 3.29 to 5.8.x (5.0 in Nov).

- Mar/Apr 2021: 7.7.x Azure AD (MSAL4J) auth dependencies shipped.
- May 2021: 7.9.0 Cloud Spanner beta.
- Jul 2021: 7.11.0 Spanner and BigQuery public beta; TiDB and YugabyteDB community support. Desktop 4.0 (29 Jul): schema model workflow (develop in a schema model, deploy with migrations).
- Aug 2021: 7.13.0 State Scripts (renamed Baseline Migrations in 8.0.0-beta3).
- Sep 2021: Flyway Desktop preview announced (Redgate forum, 13 Sep 2021).
- Oct 2021: Engine 8.0.0: CLI extensibility for custom verbs; Dapr and Google Cloud Secret Manager; Community support deprecated for DB versions older than 5 years; 10GB limit for BigQuery/Spanner in Community.
- Nov 2021: Desktop 5.0 (5.0.645 on 8 Nov): first release under the Flyway Desktop name.

### 2020

Engine 6.1.4 to 7.3.2 (7.0.0 on 28 Sep). Desktop 2.3 to 3.28 (then called Redgate Change Control).

- Jan 2020: 6.2.0 JDK 13 support.
- Apr 2020: 6.4.1 Snowflake drivers shipped.
- Jun 2020: Desktop 3.0: version control page out of experimental.
- Sep 2020: Engine 7.0.0: Flyway Teams edition introduced (replaces Pro and Enterprise); machine-readable JSON output; secrets manager support; cherry pick; migrations from S3 and GCS; Azure Synapse.

### 2019

Engine 6.0.0-beta (Feb) to 6.1.3 (6.0.0 on 19 Aug). Desktop, as Redgate Change Control, 0.x beta to 2.2 (1.0 on 23 Oct, out of beta in 2.0 on 10 Dec).

- Feb/May 2019: 6.0.0 betas: Java 6 dropped, CLI bundles OpenJDK 11 JRE, SQL Server 2019.
- Jul 2019: Redgate acquires Flyway (24 Jul).
- Aug 2019: Engine 6.0.0: PostgreSQL 12, Firebird 3/4, colourised output. Redgate Change Control betas (Oracle-first GUI on Flyway).
- Within about 12 months of the acquisition Redgate added its comparison engine to Flyway (object-level history, auto-generated migrations), per Redgate's history page (approximate).
- Nov 2019: 6.1.0 Snowflake support.
- Dec 2019: Redgate Change Control 2.0 out of beta with full Redgate licensing.

### Before 2019 (context)

- 2010: Flyway started as an open-source project (0.0.1 on 20 Apr 2010, 1.0 on 26 Dec 2010).
- Dec 2017: 5.0.0: undo migrations (paid); Java 8 minimum.
- Pre-2019 paid editions were Pro and Enterprise (per schema).

## Sources

- https://documentation.red-gate.com/fd/release-notes-for-flyway-engine-179732572.html (via REST API page 179732572)
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/flyway-desktop-8-release-notes-294781518.html
- https://documentation.red-gate.com/fd/flyway-desktop-7-release-notes-229116743.html
- https://documentation.red-gate.com/fd/flyway-desktop-6-release-notes-188646216.html
- https://documentation.red-gate.com/fd/flyway-desktop-5-release-notes-138347151.html (includes Redgate Change Control 0.x to 4.x)
- https://documentation.red-gate.com/fd/commercial-licensing-faq-181633028.html (Teams from 7.0, per-user licensing Sep 2022)
- https://tech.eu/2019/07/25/redgate-acquires-flyway-for-10-million/
- https://www.devopsdigest.com/redgate-acquires-flyway
- https://www.red-gate.com/products/flyway/history/
- https://www.red-gate.com/products/flyway/evolution/
- https://productsupport.red-gate.com/hc/en-us/community/posts/24971974885789-Flyway-Desktop-Preview-available
- https://documentation.red-gate.com/fd/flyway-v10-has-landed-222627771.html
- https://documentation.red-gate.com/fd/introducing-flyway-pipelines-251363987.html
- https://www.red-gate.com/blog/introducing-flyway-pipelines-your-new-window-into-the-health-and-history-of-your-database-deployments/
- https://documentation.red-gate.com/fd/flyway-autopilot-fasttrack-254154588.html
- https://www.red-gate.com/blog/introducing-flyway-insights-see-the-change-know-the-impact/
- https://www.red-gate.com/blog/introducing-the-flyway-mcp-server-governed-database-change-now-available-to-your-ai-coding-assistant/
- https://documentation.red-gate.com/flyway/flyway-blog/looking-forward-to-flyway-v13
- https://documentation.red-gate.com/flyway/flyway-blog/redgate-flyway-product-updates-january-2026
- https://www.componentsource.com/product/flyway/licensing (Teams closure 14 May 2025, via search snippet)
- `release-status.md` in this folder (last 6 months)

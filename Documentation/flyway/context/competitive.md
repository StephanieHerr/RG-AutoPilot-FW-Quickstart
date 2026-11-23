<!-- last-verified: 2026-10-05 | refreshed-by: weekly refresh routine -->

# Flyway Enterprise competitive landscape

Scope: the tools a Flyway Enterprise prospect is most likely to already use or be evaluating, plus the "do nothing" options. For Flyway's own capabilities this file summarises the sibling files (`editions-and-licensing.md`, `deployment-and-drift.md`, `code-analysis.md`, `ai-and-mcp.md`, `desktop-reference.md`, `release-status.md`); go there for detail and version tags.

## How to use this file

- **Acknowledge strengths first.** Name the strength before the gap; it earns the right to ask the next question.
- **Never disparage.** Position on fit and evidence, never on the competitor being bad or the customer's choice being wrong.
- **Discovery before positioning.** Let the customer find the gap. A gap that does not hurt this customer is not a gap.
- **Verify before a slide or email.** Competitor editions and prices change fast (Liquibase licence and edition rename Sept 2025, MCP 2026, Secure 6.0 and new plan capacities Sept 2026; DBmaestro MCP April 2026; Harness "vs Flyway Enterprise" page Sept 2026). Re-check the vendor page first.
- **Flag dated info.** Each section has a "Checked" date; if older than ~3 months, say "as of <date>".
- **"(unverified)"** = not confirmed from a primary source; not for customer use. **Landmines** = claims that are false, outdated or easily rebutted.

## Flyway Enterprise baseline (what we compare against)

Checked 2026-10-05 (from sibling files).

| Area | Flyway Enterprise |
|---|---|
| Approach | Migrations, state-based (schema model), or combined (state dev, generated reviewable migrations for deploy; Redgate's recommended model) |
| Databases | Migrations on 60+ platforms. Redgate comparison features (generate, diff, drift, change reports, state deploy, snapshots) on SQL Server, Oracle, PostgreSQL, MySQL and cloud variants; Databricks/Snowflake preview |
| Generation | `generate`, `diff`, `prepare`/`deploy` on SQL Compare / Schema Compare for Oracle engines; Desktop GUI; shadow DBs via provisioners |
| CI/CD | CLI/Docker in any CI tool; PAT or offline permit (air-gapped) |
| Drift | `check -drift` vs embedded snapshot; `failOnDrift`; generated revert, incorporate and filter files |
| Evidence and checks | `check -changes`, `check -dryrun`, `check -code` (bundled SQLFluff, RG rules, regex, `failOnError`, SARIF) |
| Rollback | Undo scripts, `prepare -types=deploy,undo`, snapshot-generated rollback |
| AI | MCP Server (Enterprise, **public preview**, 13.0.0+), 12 tools: real dev DB diff, generate, `review_code`, `test_migrate` on shadow; cannot edit `flyway.toml` or reach non-dev environments via tools. Desktop AI (preview) |
| Visibility | Flyway Insights (renamed from Pipelines 10 Sept 2026): deployments, drift, DORA (preview) |
| Licensing | Per contributing user, unlimited databases, approvers free, 28-day trial; secrets resolvers included |

**Own landmines:** MCP and Desktop AI are preview. MCP needs the Desktop dev/shadow project shape (fails on migrations-only single-target projects). There is no "check migration status" MCP tool despite launch-blog wording. Databricks/Snowflake advanced features are preview. Do not say Flyway is "the first" database MCP.

## Comparison matrix

Checked 2026-10-05. Y = yes, P = partial / paid tier only / with caveats, N = not found. See each section for evidence.

| | Flyway Ent | Liquibase Secure | SSDT/DACPAC | Bytebase | Atlas | DBmaestro | Harness DB DevOps | Sqitch | ORM migrations |
|---|---|---|---|---|---|---|---|---|---|
| Approach | Mig + state + combined | Changelog (mig) | State | Mig (UI/GitOps) | Declarative + versioned | Release automation | Orchestrates Liquibase/Flyway | Mig (dependency plan) | Code-first mig |
| SQL Server + Oracle + PG + MySQL | Y | Y | SQL Server/Azure only | Y | Y (Pro) | Y (+Db2) | Y | No SQL Server | Provider-dependent |
| Generate change from dev DB diff | Y (Redgate compare) | P (diff-changelog) | Y (state compile) | (unverified) | Y | Y ("automated generation") | P (AI, Liquibase only) | N | Y (from model) |
| Drift detection | Y + resolution scripts | Y (Secure) | P (DriftReport, registered DAC) | Y | Y (Pro) | Y | Y | N | N |
| Policy / code checks, fail build | Y | Y (Secure) | P (code analysis) | Y (200+ rules, free) | Y (lint; policy Pro) | Y | Y (OPA) | N | N |
| Rollback | Undo, snapshot-generated | Basic (Community), targeted (Secure) | Redeploy prior dacpac | Script gen + DML prior backup | Down migrations | "Certified backout" | Automated / restore points | Revert scripts | Down / from-to script |
| MCP server | Y (preview) | Y (Secure) | N for schema deploy | Y (governed proxy) | N official (agent skills) | Y (workflow orchestration) | Y (Harness platform MCP with a Database DevOps toolset) | N | Prisma: Prisma Postgres (and Prisma Compute) only |
| Pricing model | Per user, unlimited DBs | Tiers by DB types + DB targets; Professional Services package required | Free | Free / $20 user/mo / quote | $9 dev/mo + per project/target | Per environment | Per DB instance | Free (MIT) | Free |

## Liquibase (Community and Secure)

Checked 2026-10-05.

**What it is.** The other long-standing migration tool. Changes are "changesets" in changelogs (XML, YAML, JSON or formatted SQL), tracked in `DATABASECHANGELOG`. 65+ databases.

**Licensing and editions (2025-2026 changes).**
- 30 Sept 2025, Liquibase 5.0: Community moved from Apache 2.0 to **FSL-1.1-ALv2**. Dev, test and production use stays free; third parties may not commercialise it in competition with Liquibase. Each release becomes Apache 2.0 after two years; earlier releases stay Apache 2.0. CLA for contributors.
- 5.0 Community ships without bundled drivers/extensions (add via `liquibase lpm`); Java 17 minimum.
- **Liquibase Pro renamed Liquibase Secure**, distributed only from liquibase.com. Tiers: Starter (5 apps, 1 DB type), Growth (10 apps, 3 types), Business (25 apps, 4 types), Enterprise (unlimited); Starter/Growth only under $1B revenue. **No public prices.**
- Secure 5.2 (10 June 2026): "Agent Safe Governance", MCP server, schema lineage, Teradata/MongoDB/DynamoDB additions.
- **Secure 6.0 (GA 30 Sept 2026):** repositions Secure as a "unified platform for database change governance" in three capabilities: Change Automation, Change Governance (centralised policy management in a new visual UI, reusable policy packages, governed exceptions, 50+ prebuilt rules) and **Change Intelligence** (one view of deployments, policy outcomes, drift, failures and change history, DORA performance, AI-assisted failure analysis and remediation guidance). Adds role-based access control over who manages policies and exceptions.
- **Plans (pricing page, checked 2026-10-05):** Starter (under $1B revenue; 1 DB type, 250 DB targets; no Change Intelligence), Team ("for a single application"; 1 type, 500 targets), Business (2 types, 750 targets, RBAC, 24/7 premium support), Enterprise (4 types, 2,000 targets, RBAC). Extra DB types and capacity can be added on every plan, and **every Secure plan requires a Professional Services package**. This replaces the earlier apps-based tiers (Starter 5 apps, Growth 10, Business 25). Still **no public prices.**

**Community vs Secure (vendor page).** Community: basic rollback (last change or to a point), manual diffs only, no policy checks, no Flows, tracking table only, no AI/MCP. Secure adds targeted changeset rollback, automated drift detection, default + custom policy checks, Flows pipelines, dashboards and compliance reports, built-in secrets, MCP.

**AI/MCP.** The Liquibase AI Changelog Generator (v1.0, Secure) is a local MCP server (Docker; Claude Code/Desktop, VS Code) with 19 tools (tables, columns, indexes, views, sequences, procedures, raw SQL, validation). It turns natural language into changesets and validates each one **against an H2 in-memory database**, not the customer's engine, and needs no DB connection. Secure 5.2 marketing adds lineage showing "who or what created" a change and drift detection of "AI-assisted changes that bypass governed workflows".

**Strengths to acknowledge.** Broad DB coverage; database-agnostic changelog formats; mature targeted rollback and policy checks in Secure; strong compliance messaging; early and clear AI governance story; Change Intelligence dashboard and RBAC over policy ownership (6.0); large community; TrustRadius awards 2026.

**Gaps vs Flyway Enterprise (with evidence).**
- Governance features (policy checks, drift automation, targeted rollback, MCP) are all Secure-only; Community is migrations plus basic rollback.
- AI changelog generator validates on H2, not the target engine; Flyway MCP diffs the real dev DB, and `test_migrate` runs on a shadow of the real engine.
- Liquibase generation is diff-changelog based; Flyway Enterprise uses the Redgate comparison engines (SQL Compare, Schema Compare for Oracle) and offers state-based and combined workflows. (Do not claim Liquibase diffs are inaccurate; that is unverified.)
- Liquibase Secure is packaged by database types and database target counts, with a mandatory Professional Services package (6.0 pricing page); Flyway Enterprise is per contributing user with unlimited databases.
- Community 5.0 needs users to assemble drivers/extensions via LPM; Flyway CLI bundles its JRE and drivers.

**Discovery questions.** "Community or Secure, and which features do you rely on?" "When you add a database type or more targets, what happens to the quote, and what did the required Professional Services package cost?" "Do DBAs review XML/YAML changesets or the SQL that runs?" "How do you test AI-generated changes on your real engine before merge?" "How is the 5.0 move (FSL, LPM, Java 17) going?"

**Landmines.** Do not say Community is "no longer free", "not allowed in production" or "closed source" (FSL permits production use and source is available). Do not say Liquibase has no AI/MCP, no rollback or no SQL support (formatted SQL changelogs exist). Do not call it "Liquibase Pro" without noting the rename. Do not quote Liquibase prices. Do not describe Secure tiers by application count any more (6.0 pricing is by DB types and targets). Do not say Liquibase has no deployment dashboard or DORA view (Change Intelligence, 6.0).

**One-line positioning.** Liquibase governs changesets; Flyway Enterprise governs the SQL itself, generated from your real databases by Redgate's comparison engine, with drift, checks and AI in one per-user licence.

## Microsoft SSDT / SQL Database Projects / SqlPackage / DACPAC

Checked 2026-10-05.

**What it is.** Microsoft's free state-based tooling for the SQL Server family. Declarative `.sql` object files build (with reference and syntax validation against a target platform) into a `.dacpac`; `SqlPackage /Action:Publish` diffs the dacpac with the target and applies the delta. SDK-style projects (`Microsoft.Build.Sql`) are GA and the recommended format, GA in VS Code; preview in Visual Studio 2022; Visual Studio 2026 supports only the original format.

**Databases.** SQL Server, Azure SQL DB, Managed Instance, Synapse, SQL database in Fabric. SQL Server family only.

**CI/CD.** `dotnet build` + SqlPackage; GitHub Action `azure/sql-action` v2.3 (Publish, Script, DeployReport, DriftReport for dacpac/sqlproj; PR comments); Azure DevOps Azure SQL dacpac deployment task. Free.

**Drift.** `SqlPackage /Action:DriftReport` reports changes "since it was last registered", so the DB must be registered as a data-tier application (`RegisterDataTierApplication`); `BlockWhenDriftDetected` blocks publish to drifted/unregistered DBs. XML output, no resolution scripts.

**Policy/code checks.** SQL code analysis (built-in rules, custom rules via DacFx); code analysis GA in the VS Code extension (v1.41). `BlockOnPossibleDataLoss` defaults true. Warnings do not fail the build by default.

**Rollback.** No native rollback; redeploy a previous dacpac (state revert) or restore.

**AI/MCP.** GitHub Copilot in the MSSQL VS Code extension: Schema Designer with Copilot (natural language schema design, GA per 2026 blog), Copilot chat. Data API builder can generate MCP endpoints, but that is data access, not governed schema deployment. No Microsoft MCP server for dacpac deployment found. MSSQL extension v1.46 (Sept 2026) adds one-click install of Microsoft SQL agent skills (preview) for GitHub Copilot, available to all customers; these are Azure SQL guidance skills, not a governed deployment path.

**Strengths to acknowledge.** Free and Microsoft-supported; deep SQL Server fidelity; compile-time reference validation; refactorlog handles renames; huge knowledge base; natural fit with Visual Studio, Azure DevOps and Fabric source control.

**Gaps vs Flyway Enterprise.**
- SQL Server family only; Flyway covers Oracle, PostgreSQL, MySQL and more in one workflow.
- State-only: SQL is computed at publish time per target, so environments can get different scripts; data motion lives in pre/post-deploy scripts. Flyway's combined model reviews generated migrations once and deploys them identically everywhere.
- DriftReport needs DAC registration and outputs XML; Flyway drift uses snapshots and generates revert/incorporate scripts. (DeployReport XML exists; acknowledge it, then show the `check -changes` HTML report.)
- No rollback mechanism and no governed AI path for schema change.

**Discovery questions.** "Will all your databases be SQL Server in three years?" "Can you show the exact script that ran in production last release and prove it matched test?" "When someone hotfixes production, how do you find out?" "Where do data migrations live?" "Which Visual Studio version and project format are you standardising on?"

**Landmines.** Do not say SSDT is deprecated or unsupported. Do not say it cannot do renames (refactorlog) or has no drift report or code analysis. Do not say DACPAC deploys are unsafe; `BlockOnPossibleDataLoss` exists.

**One-line positioning.** Keep the state-based development you like, add reviewed, repeatable migrations, drift you can act on, and one workflow beyond SQL Server.

## Bytebase

Checked 2026-10-05.

**What it is.** Self-hosted (Docker/Helm) database governance platform: "single control plane between your users, humans and AI agents, and your databases". Combines change management (GUI issues/plans and GitOps), SQL review, SQL editor, access control, data masking and audit. Dual licensed (standard and enterprise licence files in repo).

**Databases.** PostgreSQL, MySQL, SQL Server, Oracle, MongoDB, Redis, MariaDB, TiDB, Snowflake, ClickHouse, Spanner, OceanBase and more ("20+ engines").

**Pricing (public).** Community free (up to 20 users, 10 instances); Pro $20/user/month (10 instances, SSO, 7-day audit); Enterprise quote (approval workflow, JIT access, data masking, custom roles, SCIM, unlimited audit). SQL review, GitOps, AI assistance and MCP are in all plans. **Custom approval workflow is Enterprise-only.**

**Drift.** Background comparison of recorded vs live schema; drift detail, rollback SQL, raise an issue.
**Policy.** Pre-deployment SQL review, 200+ rules, all plans.
**Rollback.** Generated schema rollback from change history; "Prior Backup" captures rows before DML for data rollback.

**AI/MCP.** Governed MCP server: agents connect to Bytebase, not the DB, each with its own identity; inherit access control, masking, SQL review, audit; risk-based routing of DDL/bulk DML to human approvers. AI assistant in SQL editor (bring your own OpenAI/Azure/Gemini/Claude key; schema sent, not data). Separate open-source DBHub MCP for local dev (read-only by default, no governance). Bytebase 3.23.0 (24 Sept 2026) adds a workspace **MCP access policy** (Disabled, Read-only, Read-write; new workspaces start Read-only, user permissions still cap every call; no mode lets MCP approve issues or touch credentials).

**Strengths to acknowledge.** Strongest "AI agent access governance" story in this list; generous free tier; UI-first for DBAs; data masking and JIT access beyond change management; broad engine list.

**Gaps vs Flyway Enterprise.** A platform to host, with changes flowing through Bytebase issues (Flyway runs in existing Git and CI/CD). Approval workflow is Enterprise-only. Authoring is mainly SQL the user or agent writes; Flyway generates from a dev DB via Redgate compare and tests on a shadow (Bytebase generation depth: unverified). Pro caps at 10 instances; Flyway has unlimited databases.

**Discovery questions.** "Is the problem who can query production, or how changes are built, tested and promoted?" "Another server in the path to production, or checks in your existing pipeline?" "Who writes the SQL, and how is it tested before review?" "How many instances are in scope?"

**Landmines.** Do not say Bytebase lacks drift, rollback, AI or MCP. Do not say it is only for MySQL or only for Chinese customers. Do not dismiss its MCP governance; acknowledge it and move to change authoring and pipeline fit.

**One-line positioning.** Bytebase governs access to databases; Flyway Enterprise governs how changes are built, tested and deployed through the pipeline you already run.

## Atlas (Ariga)

Checked 2026-10-05.

**What it is.** "Schema as code", Terraform-like. Declarative workflow (compare desired vs current, plan, apply) and versioned workflow (Atlas plans migrations into a directory). HCL, SQL or ORM schemas. Atlas Cloud for CI, monitoring and ERD.

**Databases.** 15+: PostgreSQL, MySQL, SQLite, MariaDB, SQL Server, ClickHouse, Redshift, Oracle, Spanner, Snowflake, Databricks, CockroachDB, Aurora DSQL and others. Free Starter limited to MySQL, MariaDB, PostgreSQL, SQLite; other engines need Pro/Enterprise.

**Pricing (public).** Starter free. Pro from $9/developer/month plus usage: $59/month per CI/CD project (2 target DBs), $39/month per extra target, $39/month per monitored DB; 50-seat cap. Enterprise custom from 20 databases, air-gapped option. Seats count every Atlas Pro user, and AI agents that trigger Atlas in CI are counted as seats too (bot tokens are not).

**CI/CD.** GitHub Actions, GitLab CI, Bitbucket, Azure DevOps, CircleCI, Terraform provider, Kubernetes operator.
**Drift.** Schema monitoring and drift detection (Pro).
**Policy.** `atlas migrate lint`, pre-migration checks, `atlas schema test`; schema policy and governance on Pro.
**Rollback.** Down migrations documented.

**AI/MCP.** Agent Skills and guides for Claude Code, Cursor, Copilot, Codex: agent declares intent, Atlas generates migrations deterministically, lint/policy/test return structured errors for self-correction. No official Atlas MCP server found (third-party ones exist).

**Strengths to acknowledge.** Modern developer UX; declarative plus versioned; strong ORM integrations; Kubernetes/Terraform native; clear, deterministic AI story; public pricing.

**Gaps vs Flyway Enterprise.** SQL Server/Oracle and drift monitoring are paid; cost scales per project, target and monitored DB (Flyway: per user, unlimited DBs). No desktop GUI for DBA-led work (Atlas Cloud UI/ERD exist). Comparison depth on SQL Server/Oracle vs Redgate compare: unverified; prove in a POC.

**Discovery questions.** "Who owns schema change: platform engineers or DBAs? Do DBAs want HCL?" "How many targets and monitored DBs at list price?" "Any SQL Server or Oracle with procedures, synonyms, packages?"

**Landmines.** Do not say Atlas lacks SQL Server, Oracle, drift, rollback or AI support. Do not call it hobbyist.

**One-line positioning.** Atlas suits platform teams writing schema as code; Flyway Enterprise suits mixed dev/DBA teams who need Redgate-grade comparison, a GUI and flat per-user pricing across every database.

## DBmaestro

Checked 2026-10-05.

**What it is.** Enterprise database release automation platform. Modules: Dev (Git integration, change documentation, branching/merging with conflict detection, "automated generation of database change scripts"), Sec (policy, segregation of duties, RBAC, SSO/MFA, vault), Ops (release pipelines with "AI assisted releases", dry run, drift detection, "certified backout plans", smart backups, compliance reports). IBM strategic OEM partner.

**Databases.** 15+: Oracle, SQL Server, Db2, PostgreSQL, MySQL, MariaDB, Snowflake, RDS, Redshift.

**Pricing.** Licensed per environment (database/schema connection in release pipelines). No public prices.

**AI/MCP.** MCP server launched 7 April 2026, "available now to all customers": natural language triggers existing governed workflows (project creation, multi-environment deploys, packages, release orchestration) within RBAC and audit. It **does not generate SQL**. DBmaestro markets itself as "the first database DevOps platform purpose-built for agentic AI workflows".

**Strengths to acknowledge.** Release orchestration and segregation of duties for regulated enterprises; Db2 coverage; backout plans; strong audit; MCP inherits platform RBAC.

**Gaps vs Flyway Enterprise.**
- Per-environment licensing grows with every DB/schema; Flyway Enterprise is per contributor, unlimited databases.
- MCP orchestrates releases but does not author or test SQL; Flyway MCP generates migrations from a dev DB diff, reviews code and test-migrates on shadow.
- Heavier central platform vs CLI in any CI tool (implementation effort: unverified, ask the customer).

**Discovery questions.** "How many environments and schemas are licensed today and planned?" "Where does the SQL come from before DBmaestro packages it?" "How long did implementation take, and who maintains it?"

**Landmines.** Do not say DBmaestro lacks drift, policy, rollback or MCP. Do not dispute its "first" claim; just do not repeat it.

**One-line positioning.** DBmaestro orchestrates releases; Flyway Enterprise helps developers and AI agents build correct changes and ships them through your existing pipeline, priced per person, not per environment.

## Harness Database DevOps

Checked 2026-10-05.

**What it is.** A module of the Harness platform that orchestrates Liquibase or Flyway engines inside Harness pipelines (Flyway support added 18 Nov 2025). Unified app + DB deployment, OPA policy-as-code, drift/cross-environment visibility, rollback with restore points, ServiceNow/Jira/Slack steps, secrets integrations.

**Databases.** PostgreSQL, MySQL, MariaDB, Oracle, SQL Server, Aurora/RDS, MongoDB, DocumentDB, Snowflake, BigQuery, AlloyDB, Spanner, CockroachDB.

**Pricing.** Per database instance (dev360 model); free tier advertised. No public prices.

**AI/MCP.** AI migration authoring from plain English with rollback scripts: **Liquibase engine only; Flyway "on roadmap"** (Harness's Flyway OSS comparison page). AI failure analysis works on all engines including Flyway. MCP: Harness's official platform MCP server (github.com/harness/mcp-server) includes a Database DevOps toolset (`database_schema`, `database_instance`, `database_snapshot_object`, `database_llm_authoring_pipeline` resources); no separate DB DevOps MCP.

**Strengths to acknowledge.** One platform for app and DB delivery; OPA governance across pipelines; strong enterprise integrations; supports Flyway, which validates Flyway's model.

**Gaps vs Flyway Enterprise.**
- Harness has two comparison pages. The "vs Flyway OSS" page compares against **Flyway Community + DIY**; most gaps it lists (dry run, generation, drift, snapshots, policy checks, fail on violation, secrets managers, dashboards) are Flyway Enterprise features.
- **New: "Harness vs Redgate Flyway Enterprise" page (updated 10 Sept 2026).** It credits Flyway Enterprise with generation, drift (including out-of-band drift, which it marks Harness "Not supported"), snapshots, schema comparison, the Redgate rule library and custom rules, and 40+ databases Harness lacks. Points to correct with evidence, without disparaging: it says state-based deployments are "SQL Server only" (Flyway feature summary: state-based deployments from the schema model on all advanced-capability databases, SQL Server, Oracle, PostgreSQL, MySQL); it says Flyway's AI "does not create SQL" (the Flyway MCP server generates migrations from a real dev DB diff and test-migrates them on a shadow, Enterprise preview, 13.0.0+); it lists Snowflake as foundational only (advanced capabilities are in public preview); it lists only three secrets managers (Flyway also has Google Secret Manager and Dapr resolvers); it still says "Flyway Pipelines" (now Flyway Insights). Its fair points: no native ServiceNow/Jira/Slack steps or promotion gates (Flyway relies on the customer's CI/CD for those), and no unified app + DB dashboard.
- Which Flyway edition Harness runs, and whether Enterprise features work inside it: (unverified). Ask.
- AI authoring not available for the Flyway engine. Flyway Enterprise runs in any CI/CD, including as CLI steps in Harness pipelines.

**Discovery questions.** "Are you standardising on Harness for all delivery?" "Which engine would you run, and which edition?" "Who generates the migration SQL before Harness deploys it?" "Have you seen Harness's Flyway Enterprise comparison? Let's check its state-based and AI rows against a live demo."

**Landmines.** Do not say Harness does not support Flyway. Do not claim Flyway Enterprise is certified with Harness DB DevOps (unverified). Do not say Harness has no MCP (its platform MCP covers DB DevOps). Do not say Flyway has native ServiceNow/Jira/Slack steps.

**One-line positioning.** Harness can orchestrate Flyway; Flyway Enterprise is what makes the changes it orchestrates correct, reviewed and drift-aware.

## Sqitch

Checked 2026-10-05.

**What it is.** Free (MIT), framework-free change management. Each change has deploy, revert and verify scripts; a plan file declares dependencies (Merkle-tree integrity), not version numbers.

**Databases.** PostgreSQL, SQLite, MySQL, MariaDB, Oracle, Firebird, YugabyteDB, CockroachDB, Vertica, Exasol, Snowflake, ClickHouse. **SQL Server is not in the supported list.**

**CI/CD / drift / policy / AI.** CLI and Docker in any CI. No drift detection, policy checks, GUI, generation, vendor support or AI/MCP found.

**Strengths.** Disciplined revert and verify scripts; dependency ordering avoids version-number merge conflicts; native SQL; free.

**Gaps.** No SQL Server; everything beyond ordered execution is DIY; no commercial support; no generation from a dev DB.

**Discovery.** "Who maintains the revert and verify scripts, and are they tested?" "How do you detect drift or block risky SQL today?"

**Landmines.** Do not say Sqitch has no rollback (revert is core) or is abandoned.

**One-line positioning.** Sqitch gives disciplined scripts; Flyway Enterprise gives those plus generation, checks, drift and support.

## ORM migrations: EF Core, Alembic, Prisma (the "dev-owned / do nothing" option)

Checked 2026-10-05.

**What it is.** Code-first migrations generated from the application model and owned by developers. Free.

**Evidence to use (vendor docs, not ours).**
- EF Core: "always inspect the generated migrations... A migration may drop a column when the intent was to rename it." A bundle "does not currently provide a way to inspect the SQL it will execute"; use a SQL script when SQL must be reviewed or handed to a DBA. Down-migration rollback "may result in data loss".
- Alembic: autogenerate cannot detect table or column renames (add/drop instead), anonymous constraints, sequences; "always necessary to manually review and correct the candidate migrations."
- Prisma 6.15.0 (Aug 2025) blocks `prisma migrate reset --force` from detected AI agents until user consent is passed. Prisma MCP (remote, mcp.prisma.io) manages **Prisma Postgres** databases plus Prisma Compute deployments and Object Storage; it is not a general database MCP.

**Drift / policy / AI.** No drift detection or policy engine; objects outside the model (procs, permissions, DBA changes) unmanaged. Agents already write ORM migrations; only Prisma adds a guardrail.

**Strengths.** Zero cost, in the developer's language and IDE, fast for greenfield apps, fits app release cadence.

**Gaps vs Flyway Enterprise.** No DBA review artifact by default, no drift, no code policy, no change report, no governance for procedures and non-model objects, one app at a time.

**Discovery.** "Who reviews the SQL an ORM or an agent generates before production?" "What happens to objects the ORM does not know about?" "Have you had a rename turn into a drop?" "How many apps share this database?"

**Landmines.** Do not tell developers to abandon their ORM. Do not say EF Core cannot produce SQL scripts. Pattern to offer (not a documented Flyway feature): keep the ORM for modelling, save its SQL output as Flyway migrations, and let Flyway Enterprise add checks, drift and reports.

**One-line positioning.** Keep your ORM; Flyway Enterprise adds the review, checks and drift control your DBAs and auditors need.

## Flyway Community (the free starting point)

Checked 2026-10-05. Frame as "what Enterprise adds", never as a lesser product.

Community gives versioned/repeatable migrations, info/validate/repair/baseline on 60+ DBs, and `check -code` with self-installed SQLFluff (cannot fail the build). Enterprise adds: undo, dry run, cherryPick; bundled SQLFluff, RG and regex rules, `failOnError`; state-based and combined workflows, `generate`, `diff`, `prepare`/`deploy`, snapshots; drift with resolution scripts and change reports; provisioners and secrets resolvers; full Desktop, MCP Server, Desktop AI, Insights (Community dropped `publishResult` in 13.2.0); Redgate support.

Discovery: "What have you built around Community (scripts, SQLFluff steps, drift checks)? Who maintains it?" Harness's Community comparison list is a useful checklist of DIY gaps.

Landmine: Community is not being withdrawn; do not imply it is.

## Redgate SQL Source Control / SQL Change Automation (legacy)

Checked 2026-10-05. SCA is retired from sale (existing customers and SQL Toolbelt only; still supported; no published end-of-life date, do not quote one). Flyway Enterprise is "the next version of SQL Change Automation". Position Flyway Enterprise for every SCA and SQL Source Control customer. Full mapping, migration steps and objections: `sca-to-flyway-upgrade.md`.

## AI and LLM-driven database change (live customer theme)

Checked 2026-10-05. Database teams want what front-end teams have: agents writing changes. The questions are where the agent runs, what it can reach, how its output is tested, and whether it goes through the same gates as human changes.

| Vendor | AI / MCP offer | How AI changes are governed | Edition / status |
|---|---|---|---|
| Flyway Enterprise | MCP, 12 tools: real dev DB diff, schema model update, generate, `review_code`, `test_migrate` on shadow; Desktop AI | Local stdio, customer's AI tool; dev/shadow only; output is Git migrations through the same checks, drift, reports, approvals | Enterprise, public preview |
| Liquibase | AI Changelog Generator MCP (19 tools), validated on H2; AI-assisted failure remediation (6.0) | Policy checks, lineage "who or what created it", drift of AI changes bypassing workflow; centralised policy packages, governed exceptions, RBAC (6.0) | Secure; v1.0; 5.2 June 2026; 6.0 Sept 2026 |
| Bytebase | Governed MCP proxy, SQL editor AI assistant, DBHub | Per-agent identity, workspace MCP access policy (3.23.0), SQL review, masking, approval routing, audit | All plans; approvals Enterprise |
| DBmaestro | MCP triggers release workflows | Platform RBAC and audit; no SQL generation | GA April 2026 |
| Harness | AI migration authoring; AI failure analysis; platform MCP with DB DevOps toolset | OPA policy, pipeline approvals | Authoring Liquibase-only |
| Atlas | Agent Skills, AI guides | Deterministic generation, lint, policy, schema tests | Guides free; policy Pro |
| Microsoft | Copilot in MSSQL extension, Schema Designer, SQL agent skills (preview, v1.46); DAB MCP (data) | Standard SSDT build/code analysis | GA features vary |
| Prisma | MCP (Prisma Postgres); AI destructive-command guard | Consent env var for `migrate reset` | 6.15.0+ |
| Sqitch | None found | n/a | n/a |

**Flyway's AI story in one breath:** the agent works on a real dev database and a real shadow of the same engine, produces ordinary reviewable migration scripts, and those scripts meet exactly the same code review, drift and approval gates in the pipeline. AI speeds up authoring; it does not get a separate path to production.

**Discovery questions.**
- "Which AI tools may developers use, and can they reach databases today?"
- "Should AI-written changes be reviewed any differently from human ones?"
- "How would you test an agent's change on your real engine before the pull request?"
- "Must you prove which changes were AI-assisted?" (Flyway: Git history and review; no built-in AI attribution feature.)
- "Is the concern AI reading production data, or AI changing schema?" (Data access is Bytebase's strength; schema change is ours.)

**Landmines.** Do not say competitors have no AI (Liquibase, Bytebase, DBmaestro, Harness, Atlas all do). Do not claim Flyway MCP is GA, reaches production, or is "the first". Do not promise Desktop AI to Teams customers without confirming entitlement.

## Sources

- https://www.liquibase.com/blog/liquibase-community-for-the-future-fsl
- https://docs.liquibase.com/community/release-notes/5-0
- https://www.liquibase.com/pricing
- https://www.liquibase.com/community-vs-secure
- https://www.liquibase.com/agent-safe-governance
- https://forum.liquibase.org/t/liquibase-secure-5-2-is-here-agent-safe-governance-for-ai-generated-database-change/10879
- https://www.businesswire.com/news/home/20260610524258/en/Liquibase-Introduces-Agent-Safe-Governance-for-AI-Generated-Database-Change
- https://docs.liquibase.com/ai-changelog-generator/get-started
- https://www.liquibase.com/blog/introducing-liquibase-secure-6-0
- https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17
- https://techcommunity.microsoft.com/blog/azuresqlblog/the-microsoft-build-sql-project-sdk-is-now-generally-available/4392063
- https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-deploy-drift-report?view=sql-server-ver17
- https://github.com/Azure/sql-action
- https://devblogs.microsoft.com/azure-sql/vscode-mssql-march-2026/
- https://learn.microsoft.com/en-us/sql/tools/visual-studio-code-extensions/mssql/mssql-schema-designer-copilot?view=sql-server-ver17
- https://devblogs.microsoft.com/azure-sql/vscode-mssql-september2026/
- https://www.bytebase.com/pricing/
- https://www.bytebase.com/database-mcp-server/
- https://github.com/bytebase/bytebase
- https://www.bytebase.com/blog/database-rollback/
- https://docs.bytebase.com/changelog/bytebase-3-23-0
- https://atlasgo.io/pricing
- https://atlasgo.io/docs
- https://atlasgo.io/use-cases/ai-safe-migrations
- https://atlasgo.io/guides/ai-tools/agent-skills
- https://www.dbmaestro.com/pricing-release-automation/
- https://www.infoq.com/news/2026/04/dbmaestro-mcp-server/
- https://www.prnewswire.com/news-releases/dbmaestro-introduces-agentic-database-devops-with-mcp-server-302734745.html
- https://www.harness.io/products/database-devops
- https://www.harness.io/blog/harness-database-devops-adds-flyway-support
- https://www.harness.io/comparison-guide/harness-db-devops-vs-flyway-oss
- https://www.harness.io/comparison-guide/harness-db-devops-vs-redgate-flyway
- https://github.com/harness/mcp-server (README, Database DevOps toolset)
- https://documentation.red-gate.com/fd/feature-summary-165740620.html (state-based deployments on advanced-capability databases, for the Harness rebuttal)
- https://developer.harness.io/docs/platform/subscriptions-licenses/subscriptions/
- https://sqitch.org/download/
- https://github.com/sqitchers/sqitch
- https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying
- https://alembic.sqlalchemy.org/en/latest/autogenerate.html
- https://www.prisma.io/blog/orm-6-15-0-ai-safety-guardrails-for-destructive-commands-and-more
- https://www.prisma.io/docs/ai/tools/mcp-server
- Flyway capabilities: sibling files in this folder (editions-and-licensing.md, deployment-and-drift.md, code-analysis.md, ai-and-mcp.md, desktop-reference.md, release-status.md, sca-to-flyway-upgrade.md)

# Setup progress and decisions

Your AI assistant fills this in as you go, so you can stop and pick up later. Never put passwords, tokens or data here: this file is committed to Git.

## Progress

| Phase | Status | Notes |
|---|---|---|
| Welcome and Flyway check | done | Flyway Enterprise 13.12.2 (rc), signed in online |
| About your database | done | |
| Sandbox databases created | done | Created by `Scripts/CreateSandboxDatabases.sql`, run by the user |
| Flyway connected (`flyway.toml`) | done | Six environments, `US-SLS-49H24K4:1433` (SQLEXPRESS's fixed port), Windows sign-in |
| Schema model captured | done | 15 tables (incl. `foo`, `bar`, kept), 16 views, 7 procedures, all `dbo`; no filters |
| Baseline set (Test and Prod marked) | done | Shadow restored from the baseline and shows 001; user ran `flyway baseline -baselineVersion=001` on Test and Prod and reported success |
| First migration generated | done | `V002__add_customer_email.sql` + `U002__add_customer_email.sql` (adds nullable `Customers.Email`); self-check on Shadow found no differences |
| Workflows tried (deploy, check, undo, drift) | done | User reported trying all four (deploy, check, drift, undo) on Test, using Redgate's POC workflow page; Flyway Desktop installed and opened on this project |
| Pipeline (optional) | in progress | `.github/workflows/flyway.yml` copied from `pipelines/github-actions/`; no tailoring needed (Windows sign-in, env names `Test` and `Check` match) |
| Wrap-up | not started | |

## Choices

| Question | Answer |
|---|---|
| Starting point (new sandbox / existing project: its folder, target and report environments) | |
| Database platform (SQL Server / Oracle / PostgreSQL / MySQL / other: name it) | SQL Server |
| Server kind (machine or VM / Azure SQL MI / Azure SQL Database / other) | Own machine: `US-SLS-49H24K4\SQLEXPRESS` (SQL Server Express) |
| Sign-in (Windows / SQL or database login) | Windows |
| Source (database on the server / backup or dump file / sample) | Database on the server: `northwind_dev` |
| Large or complex? | No |
| Baseline method (Backup as Baseline / Data Pump / baseline script) | Backup as Baseline |
| Baseline backup or dump file (path as the server sees it) | `C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\NorthwindFW_FlywayBaseline.bak` |
| Database names | Prefix `NorthwindFW`: `_Dev`, `_Test`, `_Prod`, `_Shadow`, `_Check`, `_Build` |
| Things Flyway ignores (filters) | None (user chose to keep everything, including `foo` and `bar`) |
| Pipeline (tool; on this machine or the team's; where the code and the pipeline file live) | GitHub Actions, set up on this machine (self-hosted runner); code on GitHub; pipeline file in this project's repo |

## Decision log

Format: `YYYY-MM-DD - decision - why`

- 2026-11-10 - prefix `NorthwindFW` rather than `Northwind` - `Northwind_Dev` would clash with the existing `northwind_dev` (names aren't case-sensitive)
- 2026-11-10 - JDBC URLs use port 1433 instead of `instanceName=SQLEXPRESS` - SQL Server Browser is stopped and disabled, so the driver couldn't find the named instance; SQLEXPRESS listens on fixed port 1433

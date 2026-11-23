<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway editions and licensing

**How to use this file:** Laura sells Flyway Enterprise. Everything below is for (a) confirming a feature is in Enterprise before building on it, and (b) explaining what a prospect on Community, or an existing Teams customer, gains by moving to Enterprise. It is not for recommending another edition.

## What Enterprise adds (for prospects on Community or Teams)

| Area | Community | Legacy Teams | Enterprise |
|---|---|---|---|
| Versioned migrations, info/validate/repair/baseline | Yes | Yes | Yes |
| Undo, dry run, cherryPick, errorOverrides | No | Yes | Yes |
| State-based workflow: schema model, generate, diff | No | Partial (doc labels conflict) | Yes |
| prepare/deploy, snapshots, snapshot history | No | No | Yes |
| check -changes and -drift reports, drift detection | No | No | Yes |
| Custom code review rules and policies | SQLFluff defaults only | (unverified) | Yes |
| Secrets manager resolvers (Key Vault, Vault, GCP, Dapr) | No | Removed in 12.5.0 | Yes |
| Provisioners (shadow/build DBs, Docker) | No | No (doc label: Enterprise) | Yes |
| Flyway Desktop (full) | Preview | Per-user Teams only | Yes |
| Flyway Pipelines, MCP server | No | No | Yes |
| Support | Community forums | Redgate (unverified) | Redgate |

Detail and doc conflicts are in the tables below.

## Editions at a glance

| Edition | Status | Who | Notes |
|---|---|---|---|
| Community | Free | Individuals, simple environments | Foundational migrations on 60+ DB platforms. Community support only. |
| Enterprise | Sold (per user) | Teams and pipelines needing governance | Adds Redgate comparison engine features (generate, diff, drift, changes reports, state-based deploy, snapshots), secrets resolvers, custom code-review rules, MCP server. Advanced capabilities for SQL Server, Oracle, PostgreSQL, MySQL (and cloud variants); Databricks and Snowflake in preview. |
| Teams | Legacy | Existing customers only | Closed to new customers since 14 May 2025; existing customers can renew or buy more seats. Limited to 100 target (production) schemas. Docs still label some features "Teams". |
| Trial | 28 days | Prospects | Product site: "Try Flyway Enterprise free for 28 days". `flyway auth -startEnterpriseTrial` starts a trial from the CLI. |

"Foundational" vs "Advanced" capabilities: foundational = core commands on every supported DB; advanced = Redgate comparison-based features, only for SQL Server, Oracle, PostgreSQL, MySQL and cloud variants (per feature summary; Databricks/Snowflake advanced are preview).

Doc tier labels: docs mark features "Community", "Teams" or "Enterprise". A feature labelled Teams is also in Enterprise. Labels are not always consistent between pages; the table below flags conflicts.

## Command and feature by edition

"Commands page" = tier column on the Commands reference index. Where a command page or namespace table disagrees, both are shown.

| Command / feature | Commands page tier | Other doc labels | Practical answer |
|---|---|---|---|
| `init` | Community | | All editions |
| `add` | Community | | All |
| `info`, `validate`, `repair`, `baseline`, `migrate` | Community | | All |
| `clean` | Community | | All (blocked by default: `cleanDisabled = true`) |
| `list-engines` | Community | | All |
| `check -code` | Community | Check page: "All" | All; custom regex rules and non-SQLFluff policies are Enterprise (feature summary) |
| `undo` | Teams | Undo page: "Flyway Teams"; `undo` namespace table: Enterprise | Teams and Enterprise (undo migrations resolve in Community but cannot run) |
| `check -dryrun` | Teams | Check page: "Teams & Enterprise" | Teams and Enterprise |
| `dryRunOutput` (dry run via migrate) | | Teams | Teams and Enterprise |
| `cherryPick`, `errorOverrides`, `undoSqlMigrationPrefix`, `kerberosConfigFile`, `oracle.*` (sqlplus, wallet, kerberos cache), `sqlserver.kerberos.login.file` | | Teams | Teams and Enterprise |
| `auth` | Enterprise | Auth page flags are Community-labelled | Used to license Enterprise; runs on any install |
| `check -changes`, `check -drift` | Enterprise | | Enterprise |
| `diff`, `diffText` | Enterprise | Namespace table: Teams | Enterprise (per command pages) |
| `generate` | Enterprise | | Enterprise |
| `model` | Enterprise | Namespace table: Teams | Enterprise (per command page) |
| `prepare` | Enterprise | | Enterprise |
| `deploy` | Enterprise | Deploy page has no tier label; `deploy` namespace table: Community | Treat as Enterprise |
| `snapshot` | Enterprise | | Enterprise |
| `mcp` (Flyway MCP server) | Enterprise | | Enterprise |
| Provisioners (all) | | Provisioner setting page: Enterprise; clean provisioner has no label | Enterprise. Desktop uses `clean` for the shadow DB by default. |
| Resolvers: Azure Key Vault, Vault, Dapr, Google Cloud Secret Manager | | Enterprise | Enterprise ("Integration with secrets managers" Enterprise-only; removed from Teams in 12.5.0) |
| Resolvers: env, localSecret, localdb, placeholder, Entra interactive | | No tier label | All (unverified for Community; no restriction stated) |
| Git resolver | | Teams | Teams and Enterprise |
| Undo callbacks (`beforeUndo` etc.) | | Teams | Teams and Enterprise |
| Callbacks generally | | Feature summary: Community "limited" | Full callback support Teams+ |
| Static data tables (`redgateCompare.staticDataTables`) | | Teams; `excludedColumns` and `whereClause` Enterprise | |
| Flyway Desktop GUI | | Feature summary: Community "Preview", Teams and Enterprise full | Desktop requires per-user licensing, not legacy per-schema Teams |
| Flyway Pipelines (`publishResult`, `checkDriftOnMigrate`) | | Preview; need online auth. Community stopped recognising them in 13.2.0. `checkDriftOnMigrate` deprecated in 13.10.0 | Enterprise-licensed online auth |

Community users: Flyway runs Community features when no license is found; Enterprise-only commands fail with a licensing error (exit code 35).

## Default behaviour differences

No edition-specific defaults are documented for the settings checked. Defaults that matter in demos and POCs:

| Setting | Default | Note |
|---|---|---|
| `cleanDisabled` | `true` | Same in all editions. Set `false` per environment (e.g. build/shadow) via `[environments.X.flyway] cleanDisabled = false`. `check` honours this override (12.0.2+) when build env has no provisioner; otherwise fails with `CHECK_BUILD_NO_PROVISIONER`. |
| `communityDBSupportEnabled` | `true` | Set `false` to block community-supported DB connections. |
| `validateOnMigrate` | `true` | |
| `snapshot.historyLimit` | `5` (12.1.0+) | Enterprise feature. |
| `deploy.saveSnapshot` / `migrate.saveSnapshot` | `false` in CLI docs | Desktop 9.10.0+ saves a snapshot on deploy by default in the Desktop UI. |

## Licensing model (per-user)

- Enterprise and Teams are licensed per user contributing database changes to a pipeline (directly or by authoring scripts). Reviewers/approvers, report readers, pipeline maintainers and a service account used to generate a CI PAT do not need licences (Commercial Licensing FAQ, last updated Nov 2024).
- Any number of databases in the pipeline without extra cost. Redistribution outside the organisation needs sales involvement.
- "Redgate Pipeline" (anything using Enterprise capabilities or an Enterprise-licensed CLI) requires every contributor to hold Enterprise. Mixed editions on one pipeline are unsupported.
- Recommended pipeline guard: `flyway version -outputType=json | jq -e '.edition == "ENTERPRISE"'`
- The portal allocates two entitlements: "Desktop tools" (Flyway Desktop plus SQL Compare/Data Compare/Schema Compare for Oracle/Data Compare for Oracle) and "Flyway Engine" (CLI and Docker).
- Legacy per-schema Teams licences (pre-Sept 2022) do not include Flyway Desktop.

## Licensing methods (CLI / engine)

| Method | Use for | How | Refresh |
|---|---|---|---|
| Personal Access Token (PAT) | CI/CD | `email` + `token` settings, e.g. env vars `FLYWAY_EMAIL`, `FLYWAY_TOKEN` (fixed in 12.8.1), or `${env.X}` in TOML `[flyway] email/token`. Use a service account not tied to a person. | Online, automatic. Stores a permit in the Redgate app data folder. |
| Offline permit | Air-gapped | Download from `https://permits.red-gate.com/offline?productCode=63` (CLI), save to a file, point `offlinePermitPath` / `FLYWAY_OFFLINE_PERMIT_PATH` at it. | Manual. Expires after 365 days or at subscription end. Warns within 30 days of expiry (12.8.0+). |
| `flyway auth -IAgreeToTheEula` | Developer machines | Opens browser, Redgate ID login. Not for WSL, SSH, or CI. `-logout` removes stored permit. | Online, automatic via refresh token. After upgrading to 13.6.0 run `auth` once more. |
| Legacy licence key | Old setups | `licenseKey` / `FLYWAY_LICENSE_KEY` (FL01..., 516 chars). | Deprecated; manual yearly. |
| Flyway Desktop | GUI users | Sign in with Redgate ID; offline: Licensing menu > Manage offline license, permit from `https://permits.red-gate.com/offline?productCode=64`. | Desktop handles licensing for its bundled engine. |

Authorization precedence (highest first): offline permit, then online (PAT, then interactive `auth`), then legacy licence key.

Permit storage: Windows `%APPDATA%\Redgate\Flyway CLI`; macOS/Linux `~/.config/Redgate/Flyway CLI`.

Network: online methods contact red-gate.com. CLI and Docker inherit the OS proxy only when `FLYWAY_USE_SYSTEM_PROXIES=true` (opt-in from 13.9.0; 13.4.0 to 13.8.x did it automatically). The Nov 2024 FAQ line "Flyway does not call home" predates PAT/auth and is misleading for online methods.

Telemetry: `REDGATE_DISABLE_TELEMETRY` environment variable disables usage data.

## License error basics

| Symptom | Likely cause | Fix |
|---|---|---|
| Exit code `35` | Any licensing failure (unique exit code) | Check `flyway --version` edition, then the method in use. |
| Enterprise command fails, version shows Community | No licence found | Set PAT env vars or `offlinePermitPath`, or run `auth` locally. |
| PAT ignored on 12.8.0 | Bug in 12.8.0 | Upgrade to 12.8.1+. |
| `auth` hangs in CI / over SSH / WSL | Needs a browser | Use PAT or offline permit. |
| `auth` prompts for EULA | 12.11.0+ without flag | Add `-IAgreeToTheEula`. |
| Worked before upgrade, now Community on a dev machine | 13.6.0 changed cached credential handling | Run `flyway auth -IAgreeToTheEula` once. |
| Offline permit path not picked up after 11 to 12 upgrade | `REDGATE_LICENSING_PERMIT_PATH` removed from engine | Use `FLYWAY_OFFLINE_PERMIT_PATH`. |
| Permit expired | Offline permits do not refresh | Regenerate and replace the file. |
| Teams customer lost secrets resolvers | 12.5.0 removed Secret Manager from Teams | Enterprise or env-var resolver. |

## Sources

- https://documentation.red-gate.com/fd/reference/commands
- https://documentation.red-gate.com/fd/reference/commands/check
- https://documentation.red-gate.com/fd/reference/commands/undo
- https://documentation.red-gate.com/fd/reference/commands/deploy
- https://documentation.red-gate.com/fd/reference/commands/auth
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-resolvers-namespace
- https://documentation.red-gate.com/fd/azure-key-vault-resolver-342851662.html
- https://documentation.red-gate.com/fd/git-resolver-277578944.html
- https://documentation.red-gate.com/fd/reference/configuration/redgate-compare-namespace/redgate-compare-static-data-tables-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-clean-disabled-setting
- https://documentation.red-gate.com/fd/feature-summary-165740620.html
- https://documentation.red-gate.com/fd/licensing-164167730.html
- https://documentation.red-gate.com/fd/flyway-offline-permit-path-setting-314869837.html
- https://documentation.red-gate.com/fd/how-flyway-per-user-licensing-works-206605237.html
- https://documentation.red-gate.com/fd/commercial-licensing-faq-181633028.html
- https://documentation.red-gate.com/fd/reference/environment-variables
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://www.red-gate.com/products/flyway/ (the /editions/ URL redirects here)
- https://www.red-gate.com/products/flyway/community/
- https://www.componentsource.com/product/flyway/licensing (Teams closure date, via search snippet; page blocks direct fetch)
- https://documentation.red-gate.com/fd/reference/usage/network-troubleshooting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace (deprecated settings)

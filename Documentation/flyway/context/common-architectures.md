<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Flyway Enterprise reference architectures (index)

Each architecture is its own file with a complete `flyway.toml` and pipeline YAML. Read only the one you need, then tailor names, hosts and secret names to the customer. Test in non-production first.

## Which one to use

| File | Database | CI/CD | Workflow | Use when |
|---|---|---|---|---|
| `arch-sqlserver-github-migrations.md` | SQL Server | GitHub Actions (`red-gate/setup-flyway`) | Migrations (Desktop generates V/U scripts) | Most common Enterprise pattern; shared CI build DB; split read-only checks and approval-gated deploy |
| `arch-sqlserver-gitlab-migrations.md` | SQL Server | GitLab CI (`redgate/flyway` image) | Migrations | GitLab shops; throwaway SQL Server service container as build DB (`create-database` provisioner); exit-code helper for 12.9+; Insights publishing |
| `arch-sqlserver-azuredevops-state.md` | SQL Server | Azure DevOps | State-based (schema model, `prepare` / `deploy`) | Teams used to SQL Source Control or DACPAC "desired state"; deploy the exact reviewed script after approval |
| `arch-oracle-native-multischema.md` | Oracle (multi-schema) | GitHub Actions in the `-oracle` image | Migrations with Native Connectors (SQLcl) | SQL*Plus-heavy Oracle scripts; multiple schemas; Flashback restore points |
| `arch-postgres-shadow-gitlab.md` | PostgreSQL | GitLab CI | Migrations with shadow and build | PostgreSQL teams on GitLab; build DB is a `postgres` service container |
| `arch-mysql-docker.md` | MySQL | Azure DevOps | Migrations, Docker provisioner (preview) for shadow and build | No shared dev/CI databases; containers provisioned by Flyway |

Pick the closest match by CI system first, then by database: the YAML is the harder part to adapt. For a combination not listed (for example Oracle on Azure DevOps), take the database's TOML from one file and the CI system's YAML from another.

## Conventions used in every architecture

| Topic | Rule applied | Why |
|---|---|---|
| Credentials | `${env.VAR}` in TOML; CI secret store (GitHub secrets, ADO secret variables mapped into `env:`, GitLab masked/protected variables) in YAML | Env var resolver works in all TOML parameters (12.6.2+). Never hardcode passwords or tokens |
| Licensing | `FLYWAY_EMAIL` + `FLYWAY_TOKEN` (PAT, service account) as CI secrets; offline permit (`FLYWAY_OFFLINE_PERMIT_PATH`) for air-gapped agents | PAT env vars recognised from 12.8.1. Never run `flyway auth` in CI |
| Edition check | Fail fast if the run is not Enterprise (`flyway version` prints "Flyway Enterprise Edition") | A missing secret silently drops to Community and Enterprise verbs then fail |
| cleanDisabled | `true` globally, `false` only in `[environments.build.flyway]` / shadow | Clean can never hit test/prod by accident |
| outOfOrder / validateOnMigrate | Set explicitly per environment | Makes intent reviewable |
| Build database | Dedicated, disposable, with `provisioner = "clean"`, `create-database` or `docker` | `check -changes` resets it; without a provisioner or clean enabled you get `CHECK_BUILD_NO_PROVISIONER`. One pipeline at a time per shared build DB |
| Drift | `migrate` / `deploy` with `saveSnapshot=true`, then `check -drift` with `failOnDrift=true` before the next deploy | Embedded snapshot is the documented approach; first run has no snapshot and only warns |
| Exit codes | Any non-zero = fail; only special-case 35 (licensing). Never test `== 1` | 12.9.0: exit code derived from the error code. Numeric mapping unpublished |
| Chaining | Run `check -drift` and `check -code` as their own step, not chained before `migrate` | `failOnDrift` / `failOnError` do not stop subsequent chained verbs |
| Reports | `-reportFilename=reports/<step>.html`, publish `reports/` as an artifact on success and failure | Reports no longer keep history (12.0+); archive per run |
| Version pinning | Pin the Flyway version in the pipeline; upgrade deliberately | Behaviour changes by version; see `release-status.md` |

## `[flywayDesktop]` keys: which is correct

Use **`developmentEnvironment`** and **`shadowEnvironment`**:

```toml
[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"
```

- The Flyway MCP server prerequisites page requires exactly these keys, and its troubleshooting page covers the failure `error: No such environment` or missing `[flywayDesktop]` environments.
- Flyway Desktop writes these keys in the projects it creates (observed in Laura's Desktop-created demo project and in Redgate's public Flyway AutoPilot sample projects for SQL Server, Oracle and PostgreSQL).
- The `[flywayDesktop]` namespace reference pages (Development Setting, Shadow Setting) still document `development = "development"` and `shadow = "shadow"`. Treat those pages as out of step with the product. Whether Desktop still honours the short keys is (unverified); do not write them in new configs.
- Both named environments must exist under `[environments.*]` (they can live in the git-ignored `flyway.user.toml`). The MCP server needs both; a state-only project can omit `shadowEnvironment` unless developers use MCP.
- `[flywayDesktop] schemaModel` is deprecated; use `[flyway] schemaModelLocation`.

`databaseType` at the top of each TOML is used by Flyway Desktop and Flyway Insights. The values used here (`SqlServer`, `Oracle`, `PostgreSql`, `MySql`) match Desktop-generated files; the exact casing accepted by `flyway init -databaseType` is (unverified).

## Sources
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/fd/reference/commands/check/check-drift
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html
- https://documentation.red-gate.com/spaces/FD/pages/138347155 (MCP server troubleshooting)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace
- https://documentation.red-gate.com/spaces/FD/pages/277578965/Flyway+Desktop+Development+Setting
- https://documentation.red-gate.com/spaces/FD/pages/277578968/Flyway+Desktop+Shadow+Setting
- https://github.com/red-gate/Flyway-AutoPilot-FastTrack/blob/main/flyway.toml
- https://github.com/RG-AutoPilot/Flyway-AutoPilot-Oracle/blob/main/flyway.toml
- https://github.com/RG-AutoPilot/Flyway-AutoPilot-PostgreSQL/blob/main/flyway.toml
- https://documentation.red-gate.com/fd/flyway-publish-result-setting-277579025.html

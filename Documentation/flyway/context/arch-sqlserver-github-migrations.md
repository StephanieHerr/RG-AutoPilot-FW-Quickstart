<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Architecture: migration-based, GitHub Actions, SQL Server

Shared conventions (credentials via `${env.VAR}`, PAT licensing, per-environment `cleanDisabled`, disposable build database, drift via embedded snapshots, any non-zero exit = fail, one gate per step) are in `common-architectures.md`. Hostnames, database names, schema names and secret names are examples: rename them to the customer's and test in non-production first.


**When to use:** most common Flyway Enterprise pattern. Developers use Flyway Desktop to generate versioned (and undo) migrations; the pipeline builds from scratch on PR and deploys test then prod with an approval gate.

**Environments:** `development` (per developer, Desktop) -> `shadow` (per developer, Desktop, clean provisioner) -> Git PR -> `build` (shared CI database, cleaned every run) -> `test` -> `production` (reports job, then approval-gated deploy job).

**flyway.toml**
```toml
databaseType = "SqlServer"
id = "8abbf572-e93d-4fbe-81ff-015f008c893f"
name = "SalesDb"

[flyway]
locations = ["filesystem:migrations"]
validateMigrationNaming = true
errorOverrides = ["S0001:0:I-"]     # PRINT output as info, not warnings
cleanDisabled = true
mixed = false

[flyway.sqlserver.clean]
mode = "all"                        # only matters where clean is enabled (build/shadow)

[flywayDesktop]                    # Desktop and MCP server only; no effect on CI
developmentEnvironment = "development"
shadowEnvironment = "shadow"
# The development and shadow environments are per developer and live in the
# git-ignored flyway.user.toml (shape: see arch-postgres-shadow-gitlab.md).

[environments.build]
url = "jdbc:sqlserver://ci-sql01.corp.example:1433;databaseName=SalesDb_Build;encrypt=true;trustServerCertificate=false"
user = "${env.FLYWAY_BUILD_USER}"
password = "${env.FLYWAY_BUILD_PASSWORD}"
provisioner = "clean"
[environments.build.flyway]
cleanDisabled = false
outOfOrder = false
validateOnMigrate = true

[environments.test]
url = "jdbc:sqlserver://test-sql01.corp.example:1433;databaseName=SalesDb;encrypt=true;trustServerCertificate=false"
user = "${env.FLYWAY_TEST_USER}"
password = "${env.FLYWAY_TEST_PASSWORD}"
[environments.test.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true

[environments.production]
url = "jdbc:sqlserver://prod-sql01.corp.example:1433;databaseName=SalesDb;encrypt=true;trustServerCertificate=false"
user = "${env.FLYWAY_PROD_USER}"
password = "${env.FLYWAY_PROD_PASSWORD}"
[environments.production.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

**.github/workflows/salesdb.yml**
```yaml
name: salesdb-database
on:
  pull_request:
    branches: [main]
    paths: ["migrations/**", "flyway.toml"]
  push:
    branches: [main]
    paths: ["migrations/**", "flyway.toml"]
  workflow_dispatch:

concurrency: salesdb-build-db   # the build database must not be used by two runs at once

env:
  FLYWAY_VERSION: "13.8.0"

jobs:
  build:
    runs-on: [self-hosted, linux]          # needs network access to the SQL Servers
    env:
      FLYWAY_BUILD_USER: ${{ secrets.FLYWAY_BUILD_USER }}
      FLYWAY_BUILD_PASSWORD: ${{ secrets.FLYWAY_BUILD_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
      - uses: red-gate/setup-flyway@v3
        with:
          version: ${{ env.FLYWAY_VERSION }}
          edition: enterprise
          i-agree-to-the-eula: true
          email: ${{ secrets.FLYWAY_EMAIL }}
          token: ${{ secrets.FLYWAY_TOKEN }}
      - name: Code review (all migrations)
        run: flyway check -code -environment=build -check.scope=ALL "-check.code.failOnError=true" -reportFilename=reports/code-review.html
      - name: Build from empty
        run: |
          flyway clean -environment=build
          flyway migrate -environment=build
          flyway info -environment=build
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: build-reports, path: reports/ }

  test:
    if: github.event_name != 'pull_request'
    needs: build
    runs-on: [self-hosted, linux]
    environment: test
    env:
      FLYWAY_BUILD_USER: ${{ secrets.FLYWAY_BUILD_USER }}
      FLYWAY_BUILD_PASSWORD: ${{ secrets.FLYWAY_BUILD_PASSWORD }}
      FLYWAY_TEST_USER: ${{ secrets.FLYWAY_TEST_USER }}
      FLYWAY_TEST_PASSWORD: ${{ secrets.FLYWAY_TEST_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
      - uses: red-gate/setup-flyway@v3
        with:
          version: ${{ env.FLYWAY_VERSION }}
          edition: enterprise
          i-agree-to-the-eula: true
          email: ${{ secrets.FLYWAY_EMAIL }}
          token: ${{ secrets.FLYWAY_TOKEN }}
      - name: Drift check
        run: flyway check -drift -environment=test "-check.failOnDrift=true" -reportFilename=reports/test-drift.html
      - name: Change report and dry run
        run: flyway check -changes -dryrun -environment=test -buildEnvironment=build -reportFilename=reports/test-checks.html
      - name: Migrate and embed snapshot
        run: flyway migrate -environment=test -saveSnapshot=true
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: test-reports, path: reports/ }

  production-checks:
    needs: test
    runs-on: [self-hosted, linux]
    environment: production-read-only
    env:
      FLYWAY_BUILD_USER: ${{ secrets.FLYWAY_BUILD_USER }}
      FLYWAY_BUILD_PASSWORD: ${{ secrets.FLYWAY_BUILD_PASSWORD }}
      FLYWAY_PROD_USER: ${{ secrets.FLYWAY_PROD_READONLY_USER }}
      FLYWAY_PROD_PASSWORD: ${{ secrets.FLYWAY_PROD_READONLY_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
      - uses: red-gate/setup-flyway@v3
        with:
          version: ${{ env.FLYWAY_VERSION }}
          edition: enterprise
          i-agree-to-the-eula: true
          email: ${{ secrets.FLYWAY_EMAIL }}
          token: ${{ secrets.FLYWAY_TOKEN }}
      - name: Drift check
        run: flyway check -drift -environment=production "-check.failOnDrift=true" -reportFilename=reports/prod-drift.html
      - name: Change report and dry run
        run: flyway check -changes -dryrun -environment=production -buildEnvironment=build -reportFilename=reports/prod-checks.html
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: production-reports, path: reports/ }

  production-deploy:
    needs: production-checks
    runs-on: [self-hosted, linux]
    environment: production              # add required reviewers to this GitHub Environment
    env:
      FLYWAY_PROD_USER: ${{ secrets.FLYWAY_PROD_USER }}
      FLYWAY_PROD_PASSWORD: ${{ secrets.FLYWAY_PROD_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
      - uses: red-gate/setup-flyway@v3
        with:
          version: ${{ env.FLYWAY_VERSION }}
          edition: enterprise
          i-agree-to-the-eula: true
          email: ${{ secrets.FLYWAY_EMAIL }}
          token: ${{ secrets.FLYWAY_TOKEN }}
      - name: Re-check drift after approval
        run: flyway check -drift -environment=production "-check.failOnDrift=true" -reportFilename=reports/prod-drift-final.html
      - name: Migrate and embed snapshot
        run: flyway migrate -environment=production -saveSnapshot=true
```

**Notes**
- `[flywayDesktop]` keys: Desktop-generated projects, Redgate's sample projects and the MCP server docs all use `developmentEnvironment` / `shadowEnvironment`, so this file does too. The namespace reference page lists `development` / `shadow`; treat that page as out of step (whether Desktop also accepts the short keys is unverified). The MCP server needs both keys and both environments to exist (they can live in `flyway.user.toml`).
- Split read-only checks and gated deploy mirrors what Flyway Desktop's Automated Deployment page generates (`<step>-read-only` / `<step>-write` environments). A reviewer with no required reviewers configured means no gate.
- Existing production database with no history table: add `-baselineOnMigrate=true` to the first production migrate only (docs warn it removes a safety net).
- Alternative: official `red-gate/flyway-actions` (`migrations/checks`, `migrations/deploy`); keep all action versions the same.
- GitHub-hosted runners can only be used if the SQL Servers are reachable from the internet; most customers need self-hosted runners.

## Sources
- https://documentation.red-gate.com/x/TYSvEg (Common migrations-based deployment scripts)
- https://documentation.red-gate.com/x/U4VvF (Desktop-generated GitHub Actions workflow)
- https://github.com/red-gate/setup-flyway
- https://github.com/red-gate/flyway-actions
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/dYSLE https://documentation.red-gate.com/x/l4SLE https://documentation.red-gate.com/x/lISLE https://documentation.red-gate.com/x/loSLE https://documentation.red-gate.com/x/mYSLE (Check, drift, changes, code, dryrun)
- https://documentation.red-gate.com/x/ZoIbEQ (Check error codes)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/roSLE https://documentation.red-gate.com/x/v4SLE (Environment flyway namespace, env var resolver)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace (lists `development` / `shadow`)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html (MCP prerequisites: `developmentEnvironment` / `shadowEnvironment`)
- https://github.com/red-gate/Flyway-AutoPilot-FastTrack/blob/main/flyway.toml (Redgate sample project, Desktop-written keys)

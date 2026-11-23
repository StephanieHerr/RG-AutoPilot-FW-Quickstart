<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Architecture: Oracle with Native Connectors, multi-schema

Shared conventions (credentials via `${env.VAR}`, PAT licensing, per-environment `cleanDisabled`, disposable build database, drift via embedded snapshots, any non-zero exit = fail, one gate per step) are in `common-architectures.md`. Hostnames, database names, schema names and secret names are examples: rename them to the customer's and test in non-production first.


**When to use:** Oracle estates with heavy SQL*Plus-style scripts that the Flyway JDBC parser struggles with. Native Connectors hand migration execution to Oracle SQLcl; JDBC is still used for the schema history table and some operations. Oracle Native Connectors is marked **Preview** on the driver page.

**Environments:** `development` (Desktop, JDBC) -> `build` (CI PDB, cleaned) -> `test` -> `prod`. Two application schemas: `APP_OWNER` (tables, history table) and `APP_API` (packages, views).

**flyway.toml**
```toml
databaseType = "Oracle"
id = "c4232bfd-24ef-455c-a5a3-8fd9eb4680fc"
name = "OrdersOracle"

[flyway]
locations = ["filesystem:migrations"]
defaultSchema = "APP_OWNER"        # schema history table lives here
createSchemas = false              # DBA pre-creates schema users
cleanDisabled = true

[flyway.oracle]
sqlplus = true                     # Teams+; see notes on whether NC needs it

[redgateCompare.oracle]
filterFile = "Filter.scpf"

[redgateCompare.oracle.options.behavior]
includeDependencies = true

[environments.development]
url = "jdbc:oracle:thin:@//dev-ora01.corp.example:1521/DEVPDB"
user = "${env.ORA_DEV_USER}"
password = "${env.ORA_DEV_PASSWORD}"
schemas = ["APP_OWNER", "APP_API"]

[environments.build]
url = "jdbc:oracle:thin:@//ci-ora01.corp.example:1521/BUILDPDB"
user = "${env.ORA_BUILD_USER}"
password = "${env.ORA_BUILD_PASSWORD}"
schemas = ["APP_OWNER", "APP_API"]
provisioner = "clean"
[environments.build.flyway]
cleanDisabled = false
outOfOrder = false
validateOnMigrate = true

[environments.test]
url = "jdbc:oracle:thin:@//test-ora01.corp.example:1521/TESTPDB"
user = "${env.ORA_TEST_USER}"
password = "${env.ORA_TEST_PASSWORD}"
schemas = ["APP_OWNER", "APP_API"]
[environments.test.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true

[environments.prod]
url = "jdbc:oracle:thin:@//prod-ora01.corp.example:1521/PRODPDB"
user = "${env.ORA_PROD_USER}"
password = "${env.ORA_PROD_PASSWORD}"
schemas = ["APP_OWNER", "APP_API"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

**.github/workflows/orders-oracle.yml** (runs inside the `redgate/flyway` Oracle image, which ships SQLcl per the 13.2 release notes)
```yaml
name: orders-oracle
on:
  push:
    branches: [main]
    paths: ["migrations/**", "flyway.toml"]
  workflow_dispatch:

concurrency: orders-oracle-build

env:
  FLYWAY_NATIVE_CONNECTORS: "true"
  FLYWAY_EMAIL: ${{ secrets.FLYWAY_EMAIL }}
  FLYWAY_TOKEN: ${{ secrets.FLYWAY_TOKEN }}

jobs:
  build-and-test:
    runs-on: [self-hosted, linux]
    container: redgate/flyway:13.8.0-oracle
    environment: test
    env:
      ORA_BUILD_USER: ${{ secrets.ORA_BUILD_USER }}
      ORA_BUILD_PASSWORD: ${{ secrets.ORA_BUILD_PASSWORD }}
      ORA_TEST_USER: ${{ secrets.ORA_TEST_USER }}
      ORA_TEST_PASSWORD: ${{ secrets.ORA_TEST_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
      - name: Connectivity (JDBC and SQLcl)
        run: flyway testConnection -environment=build
      - name: Build from empty
        run: |
          flyway clean -environment=build
          flyway migrate -environment=build
      - name: Test drift, reports, migrate
        run: |
          flyway check -drift -environment=test "-check.failOnDrift=true" -reportFilename=reports/test-drift.html
          flyway check -changes -dryrun -environment=test -buildEnvironment=build -reportFilename=reports/test-checks.html
          flyway migrate -environment=test -saveSnapshot=true
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: test-reports, path: reports/ }

  prod:
    needs: build-and-test
    runs-on: [self-hosted, linux]
    container: redgate/flyway:13.8.0-oracle
    environment: production               # required reviewers
    env:
      ORA_BUILD_USER: ${{ secrets.ORA_BUILD_USER }}
      ORA_BUILD_PASSWORD: ${{ secrets.ORA_BUILD_PASSWORD }}
      ORA_PROD_USER: ${{ secrets.ORA_PROD_USER }}
      ORA_PROD_PASSWORD: ${{ secrets.ORA_PROD_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
      - name: Prod drift and reports
        run: |
          flyway check -drift -environment=prod "-check.failOnDrift=true" -reportFilename=reports/prod-drift.html
          flyway check -changes -dryrun -environment=prod -buildEnvironment=build -reportFilename=reports/prod-checks.html
      - name: Migrate and embed snapshot
        run: flyway migrate -environment=prod -saveSnapshot=true
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: prod-reports, path: reports/ }
```

**Notes**
- Native Connectors needs `FLYWAY_NATIVE_CONNECTORS=true` and SQLcl on the PATH. The 11.7 blog also required `oracle.sqlplus=true`; the current driver page lists only the env var and SQLcl. Setting both is harmless on Teams/Enterprise. The `redgate/flyway:<version>-oracle` tag exists (13.8.0-oracle on Docker Hub). Its public Dockerfile copies SQLcl to `/opt/sqlcl` and does not itself add it to `PATH`; whether the image finds SQLcl without a `PATH` change is (unverified). If NC fails to find SQLcl in the container, add `/opt/sqlcl/sqlcl/bin` to `PATH` (path inside the zip unverified). `flyway testConnection` checks both JDBC and the migration execution tool; NC mode fails early if the tool cannot connect (11.18+).
- NC limitations: no `&VAR` substitution from placeholders (script hangs if a variable is undefined), placeholders not replaced inside `@`-referenced scripts, `@@` behaves differently, no script migrations, no schema history locking (do not run parallel deploys), `group` has no effect, checksums differ from JDBC mode (run `repair` when switching).
- `deploy` supports NC from 12.6. Flashback restore points (Enterprise, NC only) need Flashback Database and `CREATE ANY RESTORE POINT` (or SYSDBA/SYSOPER); Flyway only creates/drops the restore point, the DBA flashes back manually.
- Multi-schema: keep schema names upper case in `schemas` (case-sensitive). Scripts must be schema-qualified. Snapshots and drift on Oracle need `schemas` set.
- See `oracle-reference.md` for grants and the schema history synonym behaviour.

## Sources
- https://documentation.red-gate.com/x/epc6EQ https://documentation.red-gate.com/x/AQCDEQ (Oracle Native Connectors)
- https://documentation.red-gate.com/fd/reference/commands/test-connection
- https://github.com/flyway/flyway/blob/main/flyway-docker/dockerfiles/oracle/Dockerfile (SQLcl copied to /opt/sqlcl)
- https://hub.docker.com/r/redgate/flyway (tag 13.8.0-oracle exists)
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/dYSLE https://documentation.red-gate.com/x/l4SLE https://documentation.red-gate.com/x/lISLE https://documentation.red-gate.com/x/loSLE https://documentation.red-gate.com/x/mYSLE (Check, drift, changes, code, dryrun)
- https://documentation.red-gate.com/x/ZoIbEQ (Check error codes)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/roSLE https://documentation.red-gate.com/x/v4SLE (Environment flyway namespace, env var resolver)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace (lists `development` / `shadow`)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html (MCP prerequisites: `developmentEnvironment` / `shadowEnvironment`)
- https://github.com/red-gate/Flyway-AutoPilot-FastTrack/blob/main/flyway.toml (Redgate sample project, Desktop-written keys)

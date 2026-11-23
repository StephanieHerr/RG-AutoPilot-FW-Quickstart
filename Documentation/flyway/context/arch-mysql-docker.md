<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Architecture: MySQL with containerised development (Docker provisioner), Azure DevOps

Shared conventions (credentials via `${env.VAR}`, PAT licensing, per-environment `cleanDisabled`, disposable build database, drift via embedded snapshots, any non-zero exit = fail, one gate per step) are in `common-architectures.md`. Hostnames, database names, schema names and secret names are examples: rename them to the customer's and test in non-production first.


**When to use:** MySQL teams that want zero shared dev/CI databases. Shadow and build databases are containers stood up by the Flyway `docker` provisioner (**Preview, Enterprise**), which detects engine and version and publishes on an ephemeral port.

**Environments:** `development` (local MySQL container run by the developer) -> `shadow` (docker provisioner, cloned engine/version from development) -> `build` (docker provisioner, explicit engine/version, in CI) -> `test` -> `prod`.

Developer one-off: `docker run -d --name shop-dev -e MYSQL_ROOT_PASSWORD=$MYSQL_DEV_PASSWORD -e MYSQL_DATABASE=shop -p 3306:3306 mysql:8.4`

**flyway.toml**
```toml
databaseType = "MySql"
id = "ae3b2892-13d4-4876-a50e-52dad9948142"
name = "ShopMySql"

[flyway]
locations = ["filesystem:migrations"]
cleanDisabled = true

[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"

[environments.development]
url = "jdbc:mysql://localhost:3306/shop?permitMysqlScheme=true"
user = "root"
password = "${env.MYSQL_DEV_PASSWORD}"
schemas = ["shop"]

[environments.shadow]
provisioner = "docker"               # no url/user/password: the provisioner supplies them
schemas = ["shop"]
[environments.shadow.resolvers.docker]
sourceEnvironment = "development"
[environments.shadow.flyway]
cleanDisabled = false

[environments.build]
provisioner = "docker"
schemas = ["shop"]
[environments.build.resolvers.docker]
databaseEngine = "mysql"
databaseEngineVersion = "8.4"
waitTimeout = "3m"
[environments.build.flyway]
cleanDisabled = false
outOfOrder = false
validateOnMigrate = true

[environments.test]
url = "jdbc:mysql://test-mysql01.corp.example:3306/shop?permitMysqlScheme=true&useSsl=true"
user = "${env.MYSQL_TEST_USER}"
password = "${env.MYSQL_TEST_PASSWORD}"
schemas = ["shop"]
[environments.test.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true

[environments.prod]
url = "jdbc:mysql://prod-mysql01.corp.example:3306/shop?permitMysqlScheme=true&useSsl=true"
user = "${env.MYSQL_PROD_USER}"
password = "${env.MYSQL_PROD_PASSWORD}"
schemas = ["shop"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

**azure-pipelines.yml** (variable group `shop-flyway`: `FLYWAY_EMAIL`, `FLYWAY_TOKEN`, `MYSQL_TEST_USER`, `MYSQL_TEST_PASSWORD`, `MYSQL_PROD_USER`, `MYSQL_PROD_PASSWORD`; ADO environment `shop-prod` with approval)
```yaml
trigger:
  branches: { include: [main] }
  paths: { include: [migrations/*, flyway.toml] }
pr:
  branches: { include: [main] }

variables:
  - group: shop-flyway

pool: ShopAgents          # self-hosted Linux pool: Flyway CLI on PATH and Docker running

stages:
  - stage: BuildAndTest
    jobs:
      - job: BuildAndTest
        steps:
          - bash: |
              set -euo pipefail
              flyway check -code -environment=build -check.scope=ALL "-check.code.failOnError=true" -reportFilename=reports/code-review.html
              flyway migrate -environment=build
              flyway info -environment=build
            displayName: Code review and build in a container
            env:
              FLYWAY_EMAIL: $(FLYWAY_EMAIL)
              FLYWAY_TOKEN: $(FLYWAY_TOKEN)
          - bash: |
              set -euo pipefail
              flyway check -drift -environment=test "-check.failOnDrift=true" -reportFilename=reports/test-drift.html
              flyway check -changes -dryrun -environment=test -buildEnvironment=build -reportFilename=reports/test-checks.html
              flyway migrate -environment=test -saveSnapshot=true
            displayName: Deploy to test
            condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
            env:
              FLYWAY_EMAIL: $(FLYWAY_EMAIL)
              FLYWAY_TOKEN: $(FLYWAY_TOKEN)
              MYSQL_TEST_USER: $(MYSQL_TEST_USER)
              MYSQL_TEST_PASSWORD: $(MYSQL_TEST_PASSWORD)
          - publish: $(System.DefaultWorkingDirectory)/reports
            artifact: test-reports
            condition: always()

  - stage: Prod
    dependsOn: BuildAndTest
    condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
    jobs:
      - deployment: DeployProd
        environment: shop-prod
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - bash: |
                    set -euo pipefail
                    flyway check -drift -environment=prod "-check.failOnDrift=true" -reportFilename=reports/prod-drift.html
                    flyway check -changes -dryrun -environment=prod -buildEnvironment=build -reportFilename=reports/prod-checks.html
                    flyway migrate -environment=prod -saveSnapshot=true
                  displayName: Prod drift, reports, migrate
                  env:
                    FLYWAY_EMAIL: $(FLYWAY_EMAIL)
                    FLYWAY_TOKEN: $(FLYWAY_TOKEN)
                    MYSQL_PROD_USER: $(MYSQL_PROD_USER)
                    MYSQL_PROD_PASSWORD: $(MYSQL_PROD_PASSWORD)
                - publish: $(System.DefaultWorkingDirectory)/reports
                  artifact: prod-reports
                  condition: always()
```

**Notes**
- `[flywayDesktop]` keys: Desktop-generated projects, Redgate's sample projects and the MCP server docs all use `developmentEnvironment` / `shadowEnvironment`, so this file does too. The namespace reference page lists `development` / `shadow`; treat that page as out of step (whether Desktop also accepts the short keys is unverified). The MCP server needs both keys and both environments to exist (they can live in `flyway.user.toml`).
- Setting `url`, `user` or `password` on a docker-provisioned environment is rejected (13.6+). Remove them when converting an existing environment.
- `keepAlive` defaults to `true`, so containers survive between Flyway commands and are reused. On developer machines clean them up with `docker ps` / `docker rm`, or set `keepAlive = false`.
- MySQL and PostgreSQL do not need `iAgreeToTheDBVendorsEula`; SQL Server and Oracle do.
- In this pipeline the prod reports run after approval (single gated job). For review-before-approval, split as in `arch-sqlserver-github-migrations.md`.
- MySQL DDL auto-commits: a failed migration is marked failed and may need manual cleanup plus `repair`. Keep one logical DDL change per migration.
- The CLI ships only the MariaDB driver; `permitMysqlScheme=true` is required for `jdbc:mysql:` URLs (10.7+), or add MySQL Connector/J to `drivers/`. How the provisioner-supplied URL handles this is (unverified).

## Sources
- https://documentation.red-gate.com/x/uoSLE https://documentation.red-gate.com/x/uYSLE (Docker and Clean provisioners)
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/mysql
- https://documentation.red-gate.com/x/cpGTEg (Common deployment scripts)
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/dYSLE https://documentation.red-gate.com/x/l4SLE https://documentation.red-gate.com/x/lISLE https://documentation.red-gate.com/x/loSLE https://documentation.red-gate.com/x/mYSLE (Check, drift, changes, code, dryrun)
- https://documentation.red-gate.com/x/ZoIbEQ (Check error codes)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/roSLE https://documentation.red-gate.com/x/v4SLE (Environment flyway namespace, env var resolver)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace (lists `development` / `shadow`)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html (MCP prerequisites: `developmentEnvironment` / `shadowEnvironment`)
- https://github.com/red-gate/Flyway-AutoPilot-FastTrack/blob/main/flyway.toml (Redgate sample project, Desktop-written keys)

<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Architecture: state-based, Azure DevOps, SQL Server

Shared conventions (credentials via `${env.VAR}`, PAT licensing, per-environment `cleanDisabled`, disposable build database, drift via embedded snapshots, any non-zero exit = fail, one gate per step) are in `common-architectures.md`. Hostnames, database names, schema names and secret names are examples: rename them to the customer's and test in non-production first.


**When to use:** teams that want "desired state" deployments (like SQL Source Control / DACPAC users). Developers save changes to the schema model in Flyway Desktop; the pipeline uses `prepare` to generate a deployment script for each target and `deploy` to run the reviewed script.

**Environments:** `development` (Desktop) -> schema model in Git -> `test` (prepare + deploy, automatic) -> `prod` prepare stage (reports + script artifact) -> approval on ADO environment -> `prod` deploy stage (deploys the exact reviewed script).

**flyway.toml**
```toml
databaseType = "SqlServer"
id = "f595fb6a-b2d0-4a94-acd9-08ef26c098c0"
name = "HrDb"

[flyway]
schemaModelLocation = "schema-model"
errorOverrides = ["S0001:0:I-"]
cleanDisabled = true

[flywayDesktop]
developmentEnvironment = "development"

[redgateCompare.sqlserver]
filterFile = "Filter.scpf"

[redgateCompare.sqlserver.options.behavior]
includeDependencies = true

[environments.development]
url = "jdbc:sqlserver://localhost:1433;databaseName=HrDb_Dev;encrypt=true;trustServerCertificate=true;integratedSecurity=true"

[environments.test]
url = "jdbc:sqlserver://test-sql01.corp.example:1433;databaseName=HrDb;encrypt=true;trustServerCertificate=false"
user = "${env.FLYWAY_TEST_USER}"
password = "${env.FLYWAY_TEST_PASSWORD}"
[environments.test.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true

[environments.prod]
url = "jdbc:sqlserver://prod-sql01.corp.example:1433;databaseName=HrDb;encrypt=true;trustServerCertificate=false"
user = "${env.FLYWAY_PROD_USER}"
password = "${env.FLYWAY_PROD_PASSWORD}"
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

**azure-pipelines.yml** (variable group `hrdb-flyway` holds `FLYWAY_EMAIL`, `FLYWAY_TOKEN`, `FLYWAY_TEST_USER`, `FLYWAY_TEST_PASSWORD`, `FLYWAY_PROD_USER`, `FLYWAY_PROD_PASSWORD` as secrets; ADO environments `hrdb-test` and `hrdb-prod`, with approval on `hrdb-prod`)
```yaml
trigger:
  branches: { include: [main] }
  paths: { include: [schema-model/*, flyway.toml, Filter.scpf] }
pr: none

variables:
  - group: hrdb-flyway

pool: HrDbAgents          # self-hosted pool, Flyway CLI on PATH (see install snippet in notes)

stages:
  - stage: Test
    jobs:
      - deployment: DeployTest
        environment: hrdb-test
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - bash: |
                    set -euo pipefail
                    flyway check -drift -environment=test "-check.failOnDrift=true" -reportFilename=reports/test-drift.html
                    flyway check -changes -changesSource=schemaModel -environment=test -reportFilename=reports/test-changes.html
                    flyway prepare -source=schemaModel -target=test -scriptFilename=deployments/D__test.sql
                    flyway check -code -scope=script -scriptFilename=deployments/D__test.sql -failOnError=true -reportFilename=reports/test-code.html
                    flyway deploy -scriptFilename=deployments/D__test.sql -environment=test -saveSnapshot=true
                  displayName: Drift, report, prepare, review, deploy
                  env:
                    FLYWAY_EMAIL: $(FLYWAY_EMAIL)
                    FLYWAY_TOKEN: $(FLYWAY_TOKEN)
                    FLYWAY_TEST_USER: $(FLYWAY_TEST_USER)
                    FLYWAY_TEST_PASSWORD: $(FLYWAY_TEST_PASSWORD)
                - publish: $(System.DefaultWorkingDirectory)/reports
                  artifact: test-reports
                  condition: always()

  - stage: ProdPrepare
    dependsOn: Test
    jobs:
      - job: Prepare
        steps:
          - bash: |
              set -euo pipefail
              flyway check -drift -environment=prod "-check.failOnDrift=true" -reportFilename=reports/prod-drift.html
              flyway check -changes -changesSource=schemaModel -environment=prod -reportFilename=reports/prod-changes.html
              flyway prepare -source=schemaModel -target=prod -types=deploy,undo -scriptFilename=deployments/D__prod.sql -undoFilename=deployments/DU__prod.sql
              flyway check -code -scope=script -scriptFilename=deployments/D__prod.sql -failOnError=true -reportFilename=reports/prod-code.html
            displayName: Drift, report, prepare, review
            env:
              FLYWAY_EMAIL: $(FLYWAY_EMAIL)
              FLYWAY_TOKEN: $(FLYWAY_TOKEN)
              FLYWAY_PROD_USER: $(FLYWAY_PROD_USER)
              FLYWAY_PROD_PASSWORD: $(FLYWAY_PROD_PASSWORD)
          - publish: $(System.DefaultWorkingDirectory)/deployments
            artifact: prod-scripts
          - publish: $(System.DefaultWorkingDirectory)/reports
            artifact: prod-reports
            condition: always()

  - stage: ProdDeploy
    dependsOn: ProdPrepare
    jobs:
      - deployment: DeployProd
        environment: hrdb-prod          # approval check configured on this environment
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - download: current
                  artifact: prod-scripts
                - bash: |
                    set -euo pipefail
                    flyway check -drift -environment=prod "-check.failOnDrift=true" -reportFilename=reports/prod-drift-final.html
                    flyway deploy -scriptFilename="$(Pipeline.Workspace)/prod-scripts/D__prod.sql" -environment=prod -saveSnapshot=true
                  displayName: Re-check drift, deploy reviewed script
                  env:
                    FLYWAY_EMAIL: $(FLYWAY_EMAIL)
                    FLYWAY_TOKEN: $(FLYWAY_TOKEN)
                    FLYWAY_PROD_USER: $(FLYWAY_PROD_USER)
                    FLYWAY_PROD_PASSWORD: $(FLYWAY_PROD_PASSWORD)
```

**Notes**
- `[flywayDesktop]` sets only `developmentEnvironment` because a state-based project does not need a shadow. If developers want the Flyway MCP server on this project, add `shadowEnvironment = "shadow"` and a disposable shadow environment (per developer, in `flyway.user.toml`): the MCP prerequisites require both. Key names: see `common-architectures.md`.
- The drift re-check at deploy time matters: the script was generated against prod as it was before approval. If prod drifted while waiting, fail and re-prepare.
- State-based deploys revert drift by default. You cannot "ignore" drift in state-based except by filtering it out.
- `prepare` comparison options and filters can only come from TOML, not the command line.
- `DU__prod.sql` is the rollback script. Keep it with the release artifacts.
- ADO secret variables must be mapped into each step's `env:`; they are not exported automatically.
- Microsoft-hosted agent instead of a self-hosted pool: add this step before the Flyway steps in every job (URL pattern verified for 13.8.0):
  `curl -fsSL "https://download.red-gate.com/maven/release/com/redgate/flyway/flyway-commandline/13.8.0/flyway-commandline-13.8.0-linux-x64.tar.gz" | tar -xz -C "$(Agent.TempDirectory)/flyway" --strip-components=1` (after `mkdir -p`), then `echo "##vso[task.prependpath]$(Agent.TempDirectory)/flyway"`.

## Sources
- https://documentation.red-gate.com/x/cpGTEg (Common state-based deployment scripts)
- https://documentation.red-gate.com/x/ioSLE https://documentation.red-gate.com/x/eYSLE (Prepare, Deploy)
- https://documentation.red-gate.com/x/r5GTEg (Code review on deployment script)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-scope-setting
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/dYSLE https://documentation.red-gate.com/x/l4SLE https://documentation.red-gate.com/x/lISLE https://documentation.red-gate.com/x/loSLE https://documentation.red-gate.com/x/mYSLE (Check, drift, changes, code, dryrun)
- https://documentation.red-gate.com/x/ZoIbEQ (Check error codes)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/roSLE https://documentation.red-gate.com/x/v4SLE (Environment flyway namespace, env var resolver)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace (lists `development` / `shadow`)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html (MCP prerequisites: `developmentEnvironment` / `shadowEnvironment`)
- https://github.com/red-gate/Flyway-AutoPilot-FastTrack/blob/main/flyway.toml (Redgate sample project, Desktop-written keys)

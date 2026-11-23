<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Architecture: PostgreSQL, shadow and build, GitLab CI

Shared conventions (credentials via `${env.VAR}`, PAT licensing, per-environment `cleanDisabled`, disposable build database, drift via embedded snapshots, any non-zero exit = fail, one gate per step) are in `common-architectures.md`. Hostnames, database names, schema names and secret names are examples: rename them to the customer's and test in non-production first.


**When to use:** PostgreSQL teams on GitLab. The build database is a throwaway `postgres` service container per job, so no shared CI database is needed.

**Environments:** `development` + `shadow` (developer laptop, Desktop) -> MR pipeline: code review + build from empty in a service container -> `test` -> `prod` checks -> manual `prod` deploy (GitLab protected environment).

**flyway.toml**
```toml
databaseType = "PostgreSql"
id = "eae5434c-5d78-4740-89aa-dfeb86e65a5c"
name = "BillingPg"

[flyway]
locations = ["filesystem:migrations"]
defaultSchema = "billing"
cleanDisabled = true
mixed = true                        # allow CREATE INDEX CONCURRENTLY etc. in their own migration

[flyway.postgresql]
transactional.lock = false          # needed for CREATE INDEX CONCURRENTLY

[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"

[environments.development]
url = "jdbc:postgresql://localhost:5432/billing_dev"
user = "${env.PG_DEV_USER}"
password = "${env.PG_DEV_PASSWORD}"
schemas = ["billing"]

[environments.shadow]
url = "jdbc:postgresql://localhost:5432/billing_shadow"
user = "${env.PG_DEV_USER}"
password = "${env.PG_DEV_PASSWORD}"
schemas = ["billing"]
provisioner = "clean"
[environments.shadow.flyway]
cleanDisabled = false

[environments.build]
url = "jdbc:postgresql://postgres:5432/flyway_build"
user = "${env.PG_BUILD_USER}"
password = "${env.PG_BUILD_PASSWORD}"
schemas = ["billing"]
provisioner = "clean"
[environments.build.flyway]
cleanDisabled = false
outOfOrder = false
validateOnMigrate = true

[environments.test]
url = "jdbc:postgresql://test-pg01.corp.example:5432/billing?sslmode=require"
user = "${env.PG_TEST_USER}"
password = "${env.PG_TEST_PASSWORD}"
schemas = ["billing"]
[environments.test.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true

[environments.prod]
url = "jdbc:postgresql://prod-pg01.corp.example:5432/billing?sslmode=verify-full"
user = "${env.PG_PROD_USER}"
password = "${env.PG_PROD_PASSWORD}"
schemas = ["billing"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

**.gitlab-ci.yml** (CI/CD variables, masked and protected: `FLYWAY_EMAIL`, `FLYWAY_TOKEN`, `PG_TEST_USER`, `PG_TEST_PASSWORD`, `PG_PROD_USER`, `PG_PROD_PASSWORD`)
```yaml
stages: [validate, test, prod-checks, prod-deploy]

variables:
  PG_BUILD_USER: flyway
  PG_BUILD_PASSWORD: flyway-build-only     # throwaway service container, never a real database
  POSTGRES_DB: flyway_build
  POSTGRES_USER: $PG_BUILD_USER
  POSTGRES_PASSWORD: $PG_BUILD_PASSWORD

.flyway:
  image:
    name: redgate/flyway:13.8.0
    entrypoint: [""]
  services:
    - name: postgres:17
      alias: postgres
  artifacts:
    when: always
    paths: [reports/]
    expire_in: 30 days

validate:
  extends: .flyway
  stage: validate
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  script:
    - flyway check -code -environment=build -check.scope=ALL "-check.code.failOnError=true" -reportFilename=reports/code-review.html
    - flyway migrate -environment=build
    - flyway info -environment=build

deploy-test:
  extends: .flyway
  stage: test
  environment: { name: test }
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  script:
    - flyway check -drift -environment=test "-check.failOnDrift=true" -reportFilename=reports/test-drift.html
    - flyway check -changes -dryrun -environment=test -buildEnvironment=build -reportFilename=reports/test-checks.html
    - flyway migrate -environment=test -saveSnapshot=true

prod-checks:
  extends: .flyway
  stage: prod-checks
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  script:
    - flyway check -drift -environment=prod "-check.failOnDrift=true" -reportFilename=reports/prod-drift.html
    - flyway check -changes -dryrun -environment=prod -buildEnvironment=build -reportFilename=reports/prod-checks.html

deploy-prod:
  extends: .flyway
  stage: prod-deploy
  environment: { name: production }        # protect this environment in GitLab settings
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  script:
    - flyway check -drift -environment=prod "-check.failOnDrift=true" -reportFilename=reports/prod-drift-final.html
    - flyway migrate -environment=prod -saveSnapshot=true
```

**Notes**
- `[flywayDesktop]` keys: Desktop-generated projects, Redgate's sample projects and the MCP server docs all use `developmentEnvironment` / `shadowEnvironment`, so this file does too. The namespace reference page lists `development` / `shadow`; treat that page as out of step (whether Desktop also accepts the short keys is unverified). The MCP server needs both keys and both environments to exist (they can live in `flyway.user.toml`).
- Jobs run from `$CI_PROJECT_DIR`, where Flyway picks up `flyway.toml`; add `-workingDirectory=...` if the project is in a subfolder.
- GitLab runs each `script` line with fail-on-error, so any non-zero Flyway exit stops the job. The entrypoint override is required because the image's entrypoint is `flyway` (documented GitLab pattern).
- Pin the `postgres` service major version to match production; build/prod version mismatch causes spurious differences in change reports.
- Extensions: create with `CREATE EXTENSION IF NOT EXISTS`; clean does not remove extension-owned objects.
- A migration using `CONCURRENTLY` must not share a script with transactional statements unless `mixed = true`; that whole script then runs without a transaction.

## Sources
- https://documentation.red-gate.com/x/zgDhCQ (GitLab Dockerized pipeline)
- https://documentation.red-gate.com/x/l4BUE https://documentation.red-gate.com/x/aoWLE (Transactions, PostgreSQL lock)
- https://documentation.red-gate.com/x/uoSLE https://documentation.red-gate.com/x/uYSLE (Docker and Clean provisioners)
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/dYSLE https://documentation.red-gate.com/x/l4SLE https://documentation.red-gate.com/x/lISLE https://documentation.red-gate.com/x/loSLE https://documentation.red-gate.com/x/mYSLE (Check, drift, changes, code, dryrun)
- https://documentation.red-gate.com/x/ZoIbEQ (Check error codes)
- https://documentation.red-gate.com/x/uoBUE (Shadow and build environments)
- https://documentation.red-gate.com/x/roSLE https://documentation.red-gate.com/x/v4SLE (Environment flyway namespace, env var resolver)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace (lists `development` / `shadow`)
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html (MCP prerequisites: `developmentEnvironment` / `shadowEnvironment`)
- https://github.com/red-gate/Flyway-AutoPilot-FastTrack/blob/main/flyway.toml (Redgate sample project, Desktop-written keys)

<!-- last-verified: 2026-09-25 | refreshed-by: troubleshooting hardening -->

# Architecture: migration-based, GitLab CI, SQL Server

Shared conventions are in `common-architectures.md` (credentials via `${env.VAR}`, PAT licensing, per-environment `cleanDisabled`, disposable build database, drift via embedded snapshots, any non-zero exit = fail, one gate per step). Hostnames, database names, schema names and CI variable names are examples: rename them to the customer's and test in non-production first.

**When to use:** SQL Server teams on GitLab (self-managed or GitLab.com with their own runners) using the Flyway Desktop migrations workflow. The build database is a throwaway SQL Server service container per job, so there is no shared CI database to corrupt or lock. Test and production are real servers on the corporate network.

**Environments:** `development` + `shadow` (per developer, Flyway Desktop, in `flyway.user.toml`) -> merge request pipeline: edition check, code review, build from empty in a service container -> `test` (drift, change report, dry run, migrate + snapshot) -> `production` checks (drift, change report, dry run; reports reviewed) -> manual, protected `production` deploy (re-check drift, migrate + snapshot).

**Enterprise features used:** `check -changes`, `check -drift` with `failOnDrift` and drift resolution scripts, `check.code.failOnError`, `saveSnapshot`, `create-database` provisioner (preview), Flyway Insights publishing (`publishResult`, preview). `check -dryrun` and `check -code` are also available below Enterprise.

## flyway.toml (committed)

```toml
databaseType = "SqlServer"
id = "3f6f2d0e-7a51-4c1b-9a53-2d8f0b6e4c11"
name = "SalesDb"

[flyway]
locations = ["filesystem:migrations"]
validateMigrationNaming = true
errorOverrides = ["S0001:0:I-"]     # PRINT output reported as info, not warnings
cleanDisabled = true
mixed = false
reportEnabled = true                # migrate also writes an HTML/JSON report

[flyway.check]
driftResolutionFolder = "reports/drift-resolution"   # 12.9+; contents replaced each run

[flywayDesktop]                    # Desktop and MCP server only; ignored by CI
developmentEnvironment = "development"
shadowEnvironment = "shadow"

# Build: throwaway SQL Server service container in each CI job.
# create-database (preview, Enterprise) creates SalesDb_Build on first use and resets it on re-provision.
[environments.build]
url = "jdbc:sqlserver://mssql:1433;databaseName=SalesDb_Build;encrypt=true;trustServerCertificate=true"
user = "sa"
password = "${env.MSSQL_BUILD_SA_PASSWORD}"
provisioner = "create-database"
[environments.build.flyway]
cleanDisabled = false
outOfOrder = false
validateOnMigrate = true

# Same container, master database: used only to wait until SQL Server accepts logins.
[environments.build_server]
url = "jdbc:sqlserver://mssql:1433;databaseName=master;encrypt=true;trustServerCertificate=true"
user = "sa"
password = "${env.MSSQL_BUILD_SA_PASSWORD}"

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

## flyway.user.toml (per developer, git-ignored, not used by CI)

Required so Flyway Desktop and the Flyway MCP server find the environments named in `[flywayDesktop]`.

```toml
[environments.development]
url = "jdbc:sqlserver://localhost:1433;databaseName=SalesDb_Dev;encrypt=true;trustServerCertificate=true;integratedSecurity=true"

[environments.shadow]
url = "jdbc:sqlserver://localhost:1433;databaseName=SalesDb_Shadow;encrypt=true;trustServerCertificate=true;integratedSecurity=true"
provisioner = "clean"
[environments.shadow.flyway]
cleanDisabled = false
```

Add `flyway.user.toml` to `.gitignore` (`flyway init` and Desktop create one). `integratedSecurity=true` on Windows needs the Microsoft JDBC auth DLL that ships with Flyway; if a developer uses SQL logins instead, use `${env.VAR}` or `${localSecret.KEY}` for the password.

## GitLab CI/CD variables

Settings > CI/CD > Variables. Mark every one **Masked**; mark the production ones **Protected** so only protected branches and tags can read them.

| Variable | Protected | Purpose |
|---|---|---|
| `FLYWAY_EMAIL` | No | PAT licensing (service account email) |
| `FLYWAY_TOKEN` | No | PAT licensing (Redgate personal access token) |
| `MSSQL_BUILD_SA_PASSWORD` | No | SA password for the throwaway build container. Must meet SQL Server complexity rules |
| `FLYWAY_TEST_USER`, `FLYWAY_TEST_PASSWORD` | No | Test deployment login |
| `FLYWAY_PROD_READONLY_USER`, `FLYWAY_PROD_READONLY_PASSWORD` | Yes | Read-only login for production drift and change reports |
| `FLYWAY_PROD_USER`, `FLYWAY_PROD_PASSWORD` | Yes | Production deployment login |

Protect the `production` environment (Settings > CI/CD > Protected environments) and add required approvers. Protect `main`.

## .gitlab-ci.yml

```yaml
stages: [verify, test, prod-checks, prod-deploy]

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_PIPELINE_SOURCE == "web"

variables:
  FLYWAY_VERSION: "13.8.0"            # pin; upgrade deliberately (see release-status.md)

.flyway:
  image:
    name: redgate/flyway:${FLYWAY_VERSION}
    entrypoint: [""]                  # image entrypoint is flyway; GitLab needs a shell
  tags: [flyway, docker]              # self-managed runner with a route to the SQL Servers
  services:
    - name: mcr.microsoft.com/mssql/server:2022-latest
      alias: mssql
      variables:
        ACCEPT_EULA: "Y"
        MSSQL_SA_PASSWORD: $MSSQL_BUILD_SA_PASSWORD
  before_script:
    - |
      # fw: run Flyway, explain the exit code, and fail the job on any non-zero code.
      # From 12.9.0 the CLI exit code is derived from the error code, so do not test for exactly 1.
      fw() {
        set +e
        flyway "$@"
        rc=$?
        set -e
        case "$rc" in
          0) ;;
          35) echo "FLYWAY EXIT 35: licensing failure. Check FLYWAY_EMAIL / FLYWAY_TOKEN, that the PAT is valid and the account holds an Enterprise licence." ;;
          *) echo "FLYWAY EXIT $rc: see the error code in the output above and the files in reports/." ;;
        esac
        return "$rc"
      }
    - mkdir -p reports
    - flyway version | tee reports/flyway-version.txt
    - grep -qi "Flyway Enterprise Edition" reports/flyway-version.txt || { echo "Not running as Enterprise; check licensing variables."; exit 35; }
    - |
      # wait for the build SQL Server container to accept logins (up to ~2 minutes)
      for i in $(seq 1 24); do
        flyway testConnection -environment=build_server >/dev/null 2>&1 && break
        echo "waiting for SQL Server service ($i)"; sleep 5
      done
  artifacts:
    when: always
    paths: [reports/]
    expire_in: 30 days

verify:
  extends: .flyway
  stage: verify
  script:
    - fw check -code -environment=build -check.scope=ALL -check.code.failOnError=true -reportFilename=reports/code-review.html
    - fw migrate -environment=build -reportFilename=reports/build-migrate.html
    - fw info -environment=build

deploy-test:
  extends: .flyway
  stage: test
  environment: { name: test }
  resource_group: salesdb-test         # one test deployment at a time
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  variables:
    FLYWAY_PUBLISH_RESULT: "true"      # Flyway Insights (preview); needs online licensing (PAT)
  script:
    - fw check -drift -environment=test -check.failOnDrift=true -reportFilename=reports/test-drift.html
    - fw check -changes -dryrun -environment=test -check.buildEnvironment=build -reportFilename=reports/test-checks.html
    - fw migrate -environment=test -saveSnapshot=true -reportFilename=reports/test-migrate.html

prod-checks:
  extends: .flyway
  stage: prod-checks
  environment: { name: production-read-only, action: prepare }
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  variables:
    FLYWAY_PROD_USER: $FLYWAY_PROD_READONLY_USER
    FLYWAY_PROD_PASSWORD: $FLYWAY_PROD_READONLY_PASSWORD
  script:
    - fw check -drift -environment=production -check.failOnDrift=true -reportFilename=reports/prod-drift.html
    - fw check -changes -dryrun -environment=production -check.buildEnvironment=build -reportFilename=reports/prod-checks.html

deploy-prod:
  extends: .flyway
  stage: prod-deploy
  environment: { name: production }    # protected environment with approvers
  resource_group: salesdb-production   # one production deployment at a time
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  allow_failure: false                 # later stages wait for this manual job
  variables:
    FLYWAY_PUBLISH_RESULT: "true"
  script:
    - fw check -drift -environment=production -check.failOnDrift=true -reportFilename=reports/prod-drift-final.html
    - fw migrate -environment=production -saveSnapshot=true -reportFilename=reports/prod-migrate.html
```

## Notes

- **Why a SQL Server service container for build:** `check -changes` needs a build environment it can reset. Without a provisioner or `cleanDisabled = false` you get `CHECK_BUILD_NO_PROVISIONER`. `clean` works only on a database that already exists; `create-database` creates it, which is what an empty container needs. If the customer prefers a shared build server, swap the URL, drop the service and `build_server`, use `provisioner = "clean"`, and add a `resource_group` to every job that uses it so two pipelines never share it.
- **Service container facts:** GitLab starts the service alongside each job and reaches it by `alias`. SQL Server opens its port before it accepts logins, so the wait loop uses `flyway testConnection` (supported verb) against `master`. `trustServerCertificate=true` is acceptable only because the container is throwaway with a self-signed certificate; test and prod keep `trustServerCertificate=false`.
- **Build image version should match production** (for example 2019 vs 2022) or change reports show spurious differences. Pin the tag (`2022-CU<n>-ubuntu-22.04`) rather than `latest` if reports must be reproducible.
- **Exit codes (12.9+):** CLI exit codes are derived from the error code. In the open-source 13.8.0 source every core error code (validate, migrate, configuration) still maps to 1, and licensing to 35; codes from Enterprise modules may differ and the mapping is unpublished (unverified). The `fw` helper therefore treats any non-zero as failure and only special-cases 35. Never write `if [ $? -eq 1 ]`.
- **Gates are separate lines:** `failOnDrift` and `code.failOnError` do not stop later verbs chained in the same command, so each gate is its own `fw` call. GitLab stops the job at the first failing line.
- **Drift:** first run against an environment with no snapshot succeeds with a warning. `migrate -saveSnapshot=true` embeds the snapshot used by the next drift check. Revert, incorporate and filter scripts land in `reports/drift-resolution/` (artifact) when drift is found (SQL Server gets a filter file too).
- **Read-only prod checks:** `prod-checks` overrides the prod credentials with a read-only login via job `variables`. It still uses the build container for `check -changes`.
- **Flyway Insights:** `FLYWAY_PUBLISH_RESULT=true` publishes migrate and deploy results (and drift results from 13.8.0). Preview; requires `databaseType`, `id` and `name` in `flyway.toml` (present above) and online licensing (PAT). Remove the variable if the customer has not opted in.
- **Existing production database with no history table:** add `-baselineOnMigrate=true -baselineVersion=<n>` to the first production migrate only, or run `flyway baseline` once per environment.
- **Runner:** needs the Docker executor (services), outbound HTTPS to Docker Hub, `mcr.microsoft.com` and Redgate licensing hosts, and a network route to test and prod. Behind a proxy, set `JAVA_ARGS` (`-Dhttps.proxyHost=... -Dhttps.proxyPort=...`) as a CI variable: on Linux and in the Docker images the JVM only uses an explicitly configured proxy.
- **MCP server:** developers can use `flyway mcp` against this project because `[flywayDesktop]` names both environments and `flyway.user.toml` defines them. The MCP server never runs in CI.

## Sources
- https://documentation.red-gate.com/fd/gitlab-165740750.html (GitLab example, `entrypoint: [""]` rationale)
- https://documentation.red-gate.com/fd/reference/commands/test-connection
- https://documentation.red-gate.com/fd/create-database-provisioner-291931544.html
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting/clean-provisioner
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/check-error-codes
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://github.com/flyway/flyway/blob/main/flyway-commandline/src/main/java/org/flywaydb/commandline/Main.java (exit code derivation)
- https://github.com/flyway/flyway/blob/main/flyway-core/src/main/java/org/flywaydb/core/api/CoreErrorCode.java (core codes exit 1)
- https://documentation.red-gate.com/fd/reference/commands/check/check-drift
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-fail-on-drift-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-drift-resolution-folder-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-scope-setting
- https://documentation.red-gate.com/fd/flyway-publish-result-setting-277579025.html
- https://documentation.red-gate.com/fd/flyway-mcp-server-350192418.html
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace
- https://documentation.red-gate.com/fd/reference/usage/network-troubleshooting
- https://hub.docker.com/r/redgate/flyway
- https://docs.gitlab.com/ci/services/
- https://docs.gitlab.com/ci/variables/
- https://docs.gitlab.com/ci/environments/protected_environments/

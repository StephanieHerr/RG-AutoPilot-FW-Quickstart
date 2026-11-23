<#
  Flyway sandbox pipeline for any CI/CD tool. The simplest version:
    1. Check:  a report built on the Check database: changes, drift on Test, code review, SQL to run.
    2. Deploy: applies pending migrations to Test and saves a snapshot for the next drift check.
  Set up: pipelines/other/README.md. Test and Check are environment names in flyway.toml.

  Run it from the project folder as one step:
    powershell -ExecutionPolicy Bypass -File pipelines/other/flyway-pipeline.ps1
  Environment variables, from your tool's secrets:
    FLYWAY_EMAIL, FLYWAY_TOKEN    your Redgate account email and a personal access token
    TARGET_DATABASE_USERNAME, TARGET_DATABASE_PASSWORD    only for a SQL or database login
  Publish the reports folder as an artifact. Stops at the first failure.
#>

flyway auth -IAgreeToTheEula "-email=$env:FLYWAY_EMAIL" "-token=$env:FLYWAY_TOKEN"
if ($LASTEXITCODE) { exit $LASTEXITCODE }

Write-Host '--- Check: report built on the Check database ---'
flyway check -dryrun -changes -drift -code -environment=Test "-user=$env:TARGET_DATABASE_USERNAME" "-password=$env:TARGET_DATABASE_PASSWORD" "-check.buildEnvironment=Check" "-environments.Check.user=$env:TARGET_DATABASE_USERNAME" "-environments.Check.password=$env:TARGET_DATABASE_PASSWORD" "-reportFilename=reports/Test-check.html"
if ($LASTEXITCODE) { exit $LASTEXITCODE }

Write-Host '--- Deploy to Test ---'
flyway info migrate info -environment=Test "-user=$env:TARGET_DATABASE_USERNAME" "-password=$env:TARGET_DATABASE_PASSWORD" "-migrate.saveSnapshot=true"
exit $LASTEXITCODE

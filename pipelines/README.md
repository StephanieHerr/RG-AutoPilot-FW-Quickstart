# Pipelines

Optional. Your AI assistant offers to set one up with you once the sandbox works. Every pipeline here does the same two things, for one downstream environment, **Test**:

1. **Check:** a report built on the scratch **Check** database. It shows what will change, any drift on Test, code-review findings and the exact SQL that would run.
2. **Deploy:** applies the pending migrations to Test, and saves a snapshot so the next run can spot drift.

Prod stays a manual step in the sandbox.

| Folder | Tool | Based on | Where the pipeline file must be |
|---|---|---|---|
| `github-actions/` | GitHub Actions | [Flyway AutoPilot](https://github.com/red-gate/Flyway-AutoPilot-BackUp) | Copied to `.github/workflows/flyway.yml`, because GitHub only runs workflows from there |
| `azure-devops/` | Azure DevOps | [Flyway AutoPilot](https://github.com/red-gate/Flyway-AutoPilot-BackUp) | Stays here. A new pipeline points at it |
| `jenkins/` | Jenkins | the simplest pipeline | Stays here. The job's **Script Path** points at it |
| `gitlab/` | GitLab CI/CD | the simplest pipeline | Stays here. The project's **CI/CD configuration file** points at it |
| `other/` | Anything else: TeamCity, Octopus Deploy, Bamboo, Bitbucket Pipelines, Harness and so on | the simplest pipeline | A PowerShell script any tool can run as one step |

Each folder's `README.md` covers two routes: setting the tool up on this machine, or using the tool your team already has.

## What every pipeline needs

- **A runner or agent:** a Windows machine with the Flyway CLI that can reach your database server. Cloud-hosted runners can't usually reach a server on your network. Running it as yourself, in a terminal window, means Windows sign-in works as it does for you.
- **Secrets:** `FLYWAY_EMAIL` and `FLYWAY_TOKEN`, your Redgate account email and a personal access token, created on [Redgate's token page](https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts) with the account that holds your Enterprise licence ([guide](https://documentation.red-gate.com/flyway/flyway-cli-and-api/tutorials/tutorial-personal-access-tokens)). For a SQL or database login, also `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD`. These are used for Test and Check. Never put them in a file.
- **The connections** come from `flyway.toml`, so there's nothing else to fill in. If your project's environments have other names, swap `Test` and `Check` in the pipeline file for yours.

Platform notes:
- **Oracle:** remove `-code` from the check command, and add `FLYWAY_CHECK_CONNECT` as a secret (see `.claude/skills/flyway-setup/oracle.md`).
- **PostgreSQL and MySQL:** use the login secrets.
- **Linux or macOS runners:** the same Flyway commands work in bash. AutoPilot has Linux versions.

More examples: [Flyway AutoPilot](https://documentation.red-gate.com/flyway/getting-started-with-flyway/first-steps-flyway-autopilot-a-beginners-guide) and [Redgate's sample pipelines](https://github.com/red-gate/Flyway-Sample-Pipelines).

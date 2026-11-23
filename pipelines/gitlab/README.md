# GitLab CI/CD

`flyway.gitlab-ci.yml` is the simplest pipeline: **check** (a report built on the Check database) then **deploy-test**. It stays in this folder; the project's CI/CD settings point at it. The code must be in a GitLab project.

## Set it up on this machine

GitLab.com hosts the project; the runner (the program that runs the jobs) runs on this machine as you.

1. **A project:** on GitLab.com, create a blank **private** project and untick "Initialize repository with a README". Your assistant commits this project, points it at the new one, and gives you the push command.
2. **Point it at the pipeline:** **Settings > CI/CD > General pipelines > CI/CD configuration file**: `pipelines/gitlab/flyway.gitlab-ci.yml`. Save.
3. **Secrets:** **Settings > CI/CD > Variables > Add variable**. Add `FLYWAY_EMAIL` and `FLYWAY_TOKEN`, with the token **Masked**. For the token, sign in on [Redgate's personal access token page](https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts) with the account that holds your Enterprise licence, create one and copy it straight away: it's shown only once ([Redgate's guide](https://documentation.red-gate.com/flyway/flyway-cli-and-api/tutorials/tutorial-personal-access-tokens)). For a SQL login, also add `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD` (masked).
4. **A runner:**
   1. **Settings > CI/CD > Runners > New project runner**. Tick **Run untagged jobs**, then **Create runner**.
   2. Download `gitlab-runner` for Windows ([GitLab's guide](https://docs.gitlab.com/runner/install/windows/)) into a folder outside this project, for example `C:\GitLab-Runner`.
   3. In PowerShell there, run the `register` command GitLab shows, choosing the **shell** executor.
   4. Start it with `.\gitlab-runner.exe run` and leave that window open.

   If jobs fail with "pwsh is not recognized", PowerShell 7 isn't installed. Either install it, or change `shell = "pwsh"` to `shell = "powershell"` in `config.toml` there and restart the runner.
5. **Run it:** **Build > Pipelines > Run pipeline**. The report is under the check job's **Job artifacts**.

## Use your team's GitLab

- **Runner:** a Windows shell runner that can reach the database server, with the Flyway CLI on its `PATH`. If it only takes tagged jobs, add `tags: [ <its tag> ]` to both jobs. With Windows sign-in, the runner's account needs access to the databases.
- **Variables and configuration file:** as in steps 2 and 3 above.
- **Pipeline file in a separate project:** the pipeline can still run in the code's project. Set its CI/CD configuration file to `pipelines/gitlab/flyway.gitlab-ci.yml@<group>/<pipelines project>`. The people running it need access to both projects.

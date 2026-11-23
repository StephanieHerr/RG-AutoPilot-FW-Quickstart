# GitHub Actions

`flyway.yml` is a two-job workflow based on [Flyway AutoPilot](https://github.com/red-gate/Flyway-AutoPilot-BackUp): **Check** (a report built on the Check database) then **Deploy to Test**. GitHub only runs workflows from `.github/workflows/`, so it's copied to `.github/workflows/flyway.yml`. The code must be in a GitHub repo.

## Set it up on this machine

GitHub hosts the repo; the runner (the program that runs the jobs) runs on this machine as you.

1. **A repo:** on github.com, create a new **private** repository with nothing in it (no README). Your assistant commits this project, points it at the new repo, and gives you the push command.
2. **Secrets:** in the repo, **Settings > Secrets and variables > Actions > New repository secret**. Add `FLYWAY_EMAIL` and `FLYWAY_TOKEN`. For the token, sign in on [Redgate's personal access token page](https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts) with the account that holds your Enterprise licence, create one and copy it straight away: it's shown only once ([Redgate's guide](https://documentation.red-gate.com/flyway/flyway-cli-and-api/tutorials/tutorial-personal-access-tokens)). For a SQL login, also add `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD`.
3. **A runner:** **Settings > Actions > Runners > New self-hosted runner > Windows**. Run the commands GitHub shows in a PowerShell window, in a folder outside this project (GitHub suggests `C:\actions-runner`). When `config.cmd` asks questions, accept the defaults. When it asks whether to run as a service, answer **N**. Then start it with `.\run.cmd` and leave that window open. It shows "Listening for Jobs" when it's ready.
4. **Run it:** **Actions > Flyway > Run workflow**. Open the run to watch it. The report is under **Artifacts**.

GitHub's guide: [Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners).

## Use your team's GitHub Actions

- **Runner:** a self-hosted Windows runner that can reach the database server, with the Flyway CLI (or set `FLYWAY_CLI_INSTALL_CHECK` to `'true'`). If your runners use labels, change `runs-on: self-hosted` to match. With Windows sign-in, the runner's account needs access to the databases.
- **Secrets:** as above, in the repo or your organisation.
- **Pipeline file in a separate repo:** a workflow runs in the repo that holds it. Keep `flyway.yml` in the code's repo if you can. If it must live elsewhere, give each `actions/checkout` step `repository: <owner>/<code repo>` and a `token` secret that can read it. It then runs from **Run workflow**, not on pushes to the code.

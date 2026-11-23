# Azure DevOps

`flyway-pipeline.yml` is a one-stage pipeline based on [Flyway AutoPilot](https://github.com/red-gate/Flyway-AutoPilot-BackUp): **Check** (a report built on the Check database) then **Deploy to Test**. It stays in this folder; the pipeline points at it. The code can be in Azure Repos or GitHub.

## Set it up on this machine

Azure DevOps hosts the project (free for small teams); the agent (the program that runs the jobs) runs on this machine as you.

1. **An organisation and project:** sign in at https://dev.azure.com, create an organisation if you don't have one, then a **private** project.
2. **The code:** either Azure Repos (**Repos > Files** shows how to push an existing repo) or a GitHub repo. Your assistant commits this project, points it at the repo, and gives you the push command.
3. **An agent:** **Project settings > Agent pools > Default > New agent > Windows**. Download it and extract it to a folder outside this project, for example `C:\agents`. In PowerShell there, run `.\config.cmd`. It asks for:
   - **Server URL:** `https://dev.azure.com/<your organisation>`.
   - **Authentication:** a personal access token with the **Agent Pools (Read & manage)** scope. Create it under **User settings > Personal access tokens**.
   - **Pool:** `Default`.
   - **Run as a service:** answer **N**.

   Then start it with `.\run.cmd` and leave that window open.
4. **Secrets:** **Pipelines > Library > + Variable group**, named `Flyway`. Add `FLYWAY_EMAIL` and `FLYWAY_TOKEN`, and click the lock on the token to make it secret. For the token, sign in on [Redgate's personal access token page](https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts) with the account that holds your Enterprise licence, create one and copy it straight away: it's shown only once ([Redgate's guide](https://documentation.red-gate.com/flyway/flyway-cli-and-api/tutorials/tutorial-personal-access-tokens)). For a SQL login, also add `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD` (secret). Save.
5. **The pipeline:** **Pipelines > New pipeline**, choose where the code is, pick the repo, then **Existing Azure Pipelines YAML file** and `/pipelines/azure-devops/flyway-pipeline.yml`. Click **Run**. The first run asks for permission to use the `Flyway` group and the `test` environment; click **Permit**. The report is under the run's **Artifacts**.

Microsoft's guide: [Self-hosted Windows agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/windows-agent). To keep even the Azure DevOps server on this machine, Redgate's samples include an [Azure DevOps Server setup](https://github.com/red-gate/Flyway-Sample-Pipelines/tree/main/Azure/Azure-Templatized-Hybrid-Flow/setup). It takes longer.

## Use your team's Azure DevOps

- **Agent:** a self-hosted Windows agent that can reach the database server, with the Flyway CLI (or set `FLYWAY_CLI_INSTALL_CHECK` to `'true'`). If it isn't in the `Default` pool, change `pool` in the YAML. With Windows sign-in, the agent's account needs access to the databases.
- **Variable group and pipeline:** as in steps 4 and 5 above.
- **Pipeline file in a separate repo:** add the code's repo under `resources: repositories` and change each `checkout: self` to `checkout: <its alias>`. Microsoft's guide: [Check out multiple repositories](https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/multi-repo-checkout).

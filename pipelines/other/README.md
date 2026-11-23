# Any other CI/CD tool

For TeamCity, Octopus Deploy, Bamboo, Bitbucket Pipelines, Harness or anything else that can run PowerShell. `flyway-pipeline.ps1` is the whole pipeline in one script: **Check** (a report built on the Check database) then **Deploy to Test**.

## Set it up in your tool

1. **Agent or runner:** a Windows machine that can reach the database server, with the Flyway CLI on its `PATH`. With Windows sign-in, its account needs access to the databases.
2. **Get the code:** the job checks out this project's repo. If the pipeline definition lives in a separate repo, check out this project's repo as well, and run the script from its folder.
3. **Secrets as environment variables:** `FLYWAY_EMAIL` and `FLYWAY_TOKEN`. For the token, sign in on [Redgate's personal access token page](https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts) with the account that holds your Enterprise licence, create one and copy it straight away: it's shown only once ([Redgate's guide](https://documentation.red-gate.com/flyway/flyway-cli-and-api/tutorials/tutorial-personal-access-tokens)). For a SQL login, also add `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD`. Mark them secret or masked.
4. **One step:** a PowerShell or command-line step, run from the project folder:
   ```
   powershell -ExecutionPolicy Bypass -File pipelines/other/flyway-pipeline.ps1
   ```
5. **Keep the report:** publish the `reports/` folder as an artifact, even when the step fails.
6. **Trigger:** run it by hand first. Then run it when a change to `migrations/` reaches `main`.

To pause for someone to read the report before deploying, split the script into its Check and Deploy parts with an approval in between, if your tool has one.

Redgate's [sample pipelines](https://github.com/red-gate/Flyway-Sample-Pipelines) include Bitbucket, Harness and AWS examples.

## No CI/CD tool on this machine yet?

Choose GitHub Actions, Azure DevOps, Jenkins or GitLab instead. Each folder has steps to set it up here.

# Jenkins

`Jenkinsfile` is the simplest pipeline: **Check** (a report built on the Check database) then **Deploy to Test**. It stays in this folder; the Jenkins job points at it. The code can be on any Git server, or only on this machine.

## Set it up on this machine

Everything runs here, as you, so Windows sign-in and Flyway work without extra setup.

1. **Java 21:** install a Java 21 runtime, for example Eclipse Temurin 21 from https://adoptium.net. Then check that `java -version` prints 21 or later in a new PowerShell window. Current Jenkins needs Java 21 or 25 ([Jenkins's Java support](https://www.jenkins.io/doc/book/platform-information/support-policy-java/)).
2. **Jenkins:** download the LTS `jenkins.war` from https://www.jenkins.io/download/ into a folder outside this project, for example `C:\Jenkins`.
3. **Start it** in its own PowerShell window and leave that window open:
   ```powershell
   java "-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" -jar C:\Jenkins\jenkins.war --httpPort=8080
   ```
   The `ALLOW_LOCAL_CHECKOUT` setting lets Jenkins read a repo on this machine. Keep it to this sandbox, and leave it out if the code is on a Git server.
4. **First sign-in:** open http://localhost:8080. Paste the password printed in that window (it's also in `%USERPROFILE%\.jenkins\secrets\initialAdminPassword`). Choose **Install suggested plugins**, then create your admin user.
5. **Secrets:** **Manage Jenkins > Credentials > System > Global credentials > Add Credentials**. Add two of kind **Secret text**: ID `FLYWAY_EMAIL` with your Redgate email, and ID `FLYWAY_TOKEN` with a personal access token. For the token, sign in on [Redgate's personal access token page](https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts) with the account that holds your Enterprise licence, create one and copy it straight away: it's shown only once ([Redgate's guide](https://documentation.red-gate.com/flyway/flyway-cli-and-api/tutorials/tutorial-personal-access-tokens)). For a SQL login, also add `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD`, and uncomment their two lines in the `Jenkinsfile`.
6. **The job:** **New Item**, name it `Flyway`, choose **Pipeline**, then OK. Under **Pipeline**, set:
   - **Definition:** **Pipeline script from SCM**, with SCM **Git**.
   - **Repository URL:** the repo's URL, or for a repo on this machine its folder, for example `C:\Code\Flyway-QuickStart`.
   - **Branch Specifier:** `*/main`.
   - **Script Path:** `pipelines/jenkins/Jenkinsfile`.

   Save.
7. **Run it:** **Build Now**. After that, Jenkins checks for new commits every 5 minutes. The report is under the run's **Artifacts**.

Jenkins runs what's committed, so commit each new migration.

## Use your team's Jenkins

- **Agent:** a Windows agent that can reach the database server, with the Flyway CLI on its `PATH`. With Windows sign-in, the agent's account needs access to the databases. To pin the pipeline to it, change `agent any` to `agent { label '<its label>' }`.
- **Secrets and job:** as in steps 5 and 6 above. Jenkins needs the Pipeline, Git and Credentials Binding plugins (all in the suggested set).
- **Pipeline file in a separate repo:** point the job at the pipelines repo and its path to this file. Then add a first step to the Check stage that fetches the code into the workspace, for example `git url: '<code repo URL>', branch: 'main'`.

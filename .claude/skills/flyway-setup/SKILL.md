---
name: flyway-setup
description: Guided setup of a Flyway project on the user's own SQL Server, Oracle, PostgreSQL or MySQL database, starting from a dataless (structure-only) backup (Backup as Baseline on SQL Server, a Data Pump dump on Oracle, a schema-only dump plus a Flyway-written baseline script on PostgreSQL and MySQL), then hands-on tests of deploy, check, drift and undo. Use when the user says "start", "get started", "set up Flyway", "next" or "where am I", or asks to continue the setup.
---

# Flyway sandbox setup

Goal: someone new to Flyway sets up a Flyway project on **their own database**, using a **backup as the baseline**. Then they deploy, check, catch drift and roll back a change themselves. About an hour. The shape follows Redgate's Flyway AutoPilot (Backup & Running) and POC checklist, cut to the minimum. All rules in `AGENTS.md` apply throughout.

How it fits together (explain only when it helps):
- A dataless backup of their database (structure only, no data) is the **baseline**: the starting point Flyway builds on.
- Dev, Test and Prod are restored from it, so they start identical.
- Shadow, Check and Build are scratch databases. Flyway restores them from the same backup whenever it needs a clean start.
- Their changes in Dev become migrations on top of the baseline.

## Detect state first

**Right folder?** `AGENTS.md` and `flyway.toml` must be at the top of your working folder. If they're in a subfolder, stop and ask them to open that folder itself in their AI tool and say *start* again. Its instructions and the Flyway MCP server load from there, and every path in this playbook is relative to it.

Read `Documentation/project-profile.md`, the `[environments.*]` in `flyway.toml`, `schema-model/` and `migrations/`.
- Fresh: go to Welcome.
- Partway: welcome them back, say in one line what's done and what's next, ask to carry on. If the profile says they started from an existing project, carry on with "If they already have a Flyway project".
- Invoked again mid-conversation: continue from the last unanswered question. Don't greet again.

Never call a step done because a file exists. At the end of each phase, update `project-profile.md`: edit rows in place, record true facts only, no secrets.

**PowerShell:** wrap every Flyway argument that contains a dot in double quotes (`"-diff.source=development"`), or Windows PowerShell splits it. Run commands from this project folder.

**When they run something,** tell them first what success looks like, so a plain *done* is enough. Then check for yourself where you can: read what it wrote (every report has a `.json` file of the same name next to its `.html`), or run your own read-only command against development or shadow. Ask them to paste output only if it shows an error or doesn't match what you said they'd see.

**Reports open themselves.** End any command you give them that writes a report with `; Invoke-Item <report>`, so it opens in their default browser as soon as Flyway finishes. On macOS use `; open <report>`, and on Linux `; xdg-open <report>`. Afterwards, read its `.json` and walk them through what it found.

## 1. Welcome

Short and warm. Cover:
- We'll set up Flyway on a copy of **your own database's structure** (no data), on a server you control. Nothing touches your real databases.
- By the end, you'll have a Flyway project and a migration Flyway wrote for you, ready for you to try deploying, checking, drift and undo yourself. A pipeline is an optional extra.
- Progress is saved, so you can stop any time, and questions are welcome at any point.

Ask: "Do you already have a Flyway Enterprise project set up?
1. No, let's set one up (default)
2. Yes, take me straight to setting up a pipeline for it
3. Yes, but I'd still like to try the sandbox"

- **1 or 3:** carry on. Don't mention pipelines again until the end.
- **2:** check Flyway as below, then go to "If they already have a Flyway project".

## 2. Check Flyway (quietly)

Say you're checking Flyway is installed, then run `flyway --version`.
- **Not found:** ask them to run this in PowerShell in this folder. It installs the Flyway CLI to `C:\FlywayCLI` for their user. Then restart the terminal and the AI tool:
  `$env:FLYWAY_PATH_LOCATION='User'; .\Scripts\Flyway_DownloadAndInstallCLI.ps1`
- **Says Community, or asks to sign in:** they run `flyway auth -IAgreeToTheEula`. It opens a browser to sign in with the Redgate account that holds their Enterprise licence. Backup as Baseline needs Enterprise (library file 04).
- **Complains about a setting in `flyway.toml`:** their Flyway is too old. They update it. Don't edit the file.

On Windows, also run the Flyway Desktop lookup from step 9 and note in the profile whether it's installed. If it isn't, say in one line that you'll download it for them when it's useful (it's needed for SQL logins and handy for trying things in a UI), and that they can say *desktop* any time. If everything's fine, just say "Flyway's installed and ready" and move on.

## 3. About your database (one question per message)

Accept bundled answers and skip anything already answered.

1. **Platform:** "Which platform is your database on?
   1. SQL Server (default), including Azure SQL, Amazon RDS and Google Cloud
   2. Oracle, including Autonomous Database, RAC/Exadata and Amazon RDS
   3. PostgreSQL or compatible: Aurora, Azure, Google Cloud, Amazon RDS, EnterpriseDB, YugabyteDB, TimescaleDB, CockroachDB, Aurora DSQL
   4. MySQL or compatible: MariaDB, Aurora, Azure, Google Cloud, Amazon RDS, Percona, SkySQL, SingleStore, TiDB, OceanBase
   5. Data warehouse or analytics: Snowflake, Databricks, Redshift, BigQuery, Azure Synapse, Microsoft Fabric, ClickHouse
   6. Another relational database: Db2 (LUW or z/OS), SAP HANA, Sybase ASE, Informix, Firebird, Google Cloud Spanner, SQLite, H2, HSQLDB, Derby, Ignite
   7. NoSQL: MongoDB or Atlas, Amazon DocumentDB, Cassandra, Couchbase"
   - **1:** carry on.
   - **2:** also read `oracle.md` in this folder and follow it alongside these steps.
   - **2, 3 or 4:** say in one line that their platform is fully guided here, so they don't need SQL Server.
   - **3 or 4:** also read `postgresql-mysql.md` in this folder and follow it alongside these steps; it replaces parts of steps 3 to 7. On EnterpriseDB Extended Server, say first that Flyway's support there is preview. CockroachDB, Aurora DSQL, SingleStore, TiDB and OceanBase are Foundational only, so treat them as 5 to 7.
   - **5 to 7:** if it isn't clear which product, ask. Then say kindly that this sandbox's guided setup covers SQL Server, Oracle, PostgreSQL and MySQL, and tell them what Flyway offers on theirs, per Redgate's supported databases page (https://documentation.red-gate.com/flyway/getting-started-with-flyway/system-requirements/supported-databases-and-versions; check their version there):
     - **Advanced** (Flyway compares databases and writes the migrations, plus checks and drift): Snowflake and Databricks. Preview: Couchbase. In development: Fabric SQL Database.
     - **Foundational only** (Flyway deploys migrations that people write; it doesn't write them or catch drift): everything else on the list.

     Offer two ways on: their Redgate SE can set up a proof of concept on their platform, or they learn the workflows here first on a free SQL Server Developer Edition with a sample database, since the ideas carry over. For the second, record the platform as "SQL Server, for learning (real platform: <theirs>)" and use option 4 under "Your database".
2. **Sandbox server:** "Which SQL Server should the sandbox databases go on? Pick one where you're an administrator and can create and delete databases. SQL Server Developer Edition on your own machine is ideal, and free; a dev/test server is fine too. Never production. What's its name, and do you sign in with Windows or a SQL login?" Note the kind. Azure SQL Database and Managed Instance can't back up to disk, so use "If a backup isn't possible" at the end. Amazon RDS and Google Cloud SQL don't give the sysadmin rights the script needs, so suggest Developer Edition on their own machine, with a backup of their database (option 3 below).
3. **Your database:** "Which existing database should the sandbox start from? It's only the source: Flyway reads its structure once and never changes it. The setup copies that structure, never the data, into a new **Dev** database: the development database, where you make changes and Flyway picks them up. How shall we bring it in?
   1. It's already on that server
   2. I have a backup file (`.bak`) of it
   3. It's on another server
   4. I'd rather use a sample database"
   - **1:** ask for its exact name, calling it the source database, never the dev database. For example: "What's the exact name of the database to copy from, as SSMS shows it? It's only read. Your dev database will be a new copy of it." Never guess or shorten a name: samples carry a year, such as `AdventureWorks2022`. If the name is wrong, the script lists similar ones.
   - **2:** ask them to move the `.bak` into the sandbox server's **default backup folder** and tell you its exact file name, copied rather than typed. Then fill in the file name alone. To find the folder in SSMS: right-click the server in Object Explorer, **Properties**, **Database Settings**, then **Backup** under **Database default locations**. It looks like `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup`, and Windows asks for administrator permission to copy into it. A full path elsewhere works only if it's on the server (not their PC, unless their PC is the server) and the SQL Server service account can read it. Their Downloads folder almost never qualifies.
   - **3:** they back it up the usual way (in SSMS: right-click the database, Tasks, Back Up), or ask their DBA. Then they copy the `.bak` to the sandbox server and continue as in 2. If the data is sensitive, a DBA can make a dataless backup on the source server instead, following Redgate's guide (https://documentation.red-gate.com/flyway/learn-more-about-flyway/how-to-articles/use-a-sql-server-backup-to-baseline-a-database). The script treats it the same.
   - **4:** say you'll start the download of Microsoft's AdventureWorks sample in their browser, then run:
     `Start-Process https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2016.bak`
     `AdventureWorks2016.bak` restores on every SQL Server the script supports (2016 SP2 and later). Microsoft's other versions are on https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure; their file names all carry a year. Then continue as in 2, with `AdventureWorks2016.bak` as the file name.

   It must have real tables. Never create an empty Dev database.
4. **Size:** "Is it large or complex? For example thousands of objects, several filegroups, or references to other databases or linked servers. (1 yes, 2 no, 3 not sure)" Backup as Baseline handles both; it's built for this. Use the answer to set expectations:
   - **Large:** copying and restoring take longer.
   - **Complex:** after the capture, look for objects that depend on other databases or linked servers, and ask whether to leave them out.
   - If they mention a simpler database too, say it makes an easier first run (Redgate's POC advice), but don't push.
5. **Names:** propose `<Name>_Dev`, `_Test`, `_Prod`, `_Shadow`, `_Check` and `_Build`, and ask whether those are OK. One line each: Dev is the development database, a copy of their source database: developers make changes there, and Flyway reads those changes to write migrations. Test and Prod are pretend deployment targets. Shadow, Check and Build are scratch databases Flyway restores from your baseline.

## 4. Create the sandbox databases (they run it)

Fill in the values at the top of `Scripts/CreateSandboxDatabases.sql`:
- `@SourceDatabase` **or** `@SourceBackupFile`
- `@Prefix`
- `@BaselineBackupFile` (default `<Prefix>_FlywayBaseline.bak`, which lands in the server's default backup folder)

Tell them you did. Then ask them to open it in SSMS or Azure Data Studio, connect to the sandbox server and run it. Explain in a few lines:
- It makes a **dataless backup** of their database: a structure-only copy made with `DBCC CLONEDATABASE`, backed up to a file. That's the baseline Flyway restores whenever it needs a clean starting point. Point them to Redgate's guide to using a backup as a baseline, which this step follows: https://documentation.red-gate.com/flyway/learn-more-about-flyway/how-to-articles/use-a-sql-server-backup-to-baseline-a-database
- It restores the baseline as Dev, Test and Prod, and creates empty Shadow, Check and Build.
- Starting from a `.bak` with data, it restores that temporarily, copies the structure, then drops it.
- It never changes their database or backup file, and never overwrites an existing database.

Success ends with "Done." in the Messages tab. Ask them to say *done*, or paste the error. You don't need the baseline path it prints: step 5 uses the `@BaselineBackupFile` value you filled in. If it fails, start with the simplest cause:
- **Needs sysadmin:** use a server where they're an administrator, or a DBA runs it.
- **`@SourceDatabase was not found`:** use the exact name; the message lists similar names on the server.
- **Can't read the `.bak`** ("Cannot open backup device"): operating system error 2 means no file by that name, so check the exact name, year included. Error 5 means SQL Server can't read that folder (usually Downloads). Either way, move the file into the default backup folder and use the file name alone.
- **"Cannot open backup device" on the baseline:** use a file name alone, or a folder the service account can write to.
- **Backup from a newer SQL Server version:** they need a sandbox server of the same version or newer.
- **Encrypted (TDE) backup, or not enough disk space for the temporary restore:** ask a DBA for a dataless backup instead.

## 5. Connect Flyway

Say: "I'll add your databases to `flyway.toml` so Flyway knows where they are." Replace the commented template at the bottom with all six environments in one go, then list what you added. SQL Server URL: `jdbc:sqlserver://<server>;databaseName=<db>;encrypt=optional;integratedSecurity=true;trustServerCertificate=true` (leave out `integratedSecurity=true` for SQL logins).

| Environment | Database | Settings |
|---|---|---|
| `development` | Dev | none |
| `shadow`, `Check`, `Build` | Shadow, Check, Build | `provisioner = "backup"` plus the block below |
| `Test`, `Prod` | Test, Prod | none, ever |

Add this under each of shadow, Check and Build. Use single quotes so Windows paths need no escaping:
```toml
[environments.shadow.resolvers.backup]
backupFilePath = '<the @BaselineBackupFile value>'
backupVersion = "001"
sqlserver.generateWithMove = true
```
A file name alone (the default) works: SQL Server looks for it in its default backup folder, which is where the script saved it. Keep these environment names, because the pipelines use them.

**SQL login:** say no passwords go in project files, and ask: "Do you use the same login for all these databases? (1 yes, 2 no)". These steps need Flyway Desktop: if it isn't installed, download it for them first, as in step 9. Then give these steps, in exactly these words:
1. Open **Flyway Desktop**. On its home screen, under **Open existing project**, click **Open local file** (older versions: **Open project...**). Go to this folder, `<this folder>`, and choose `flyway.toml`.

   Fill in the full path. On Windows, first copy it to their clipboard as in step 9, and add: "The path is on your clipboard: paste it into the **File name** box and press Enter."
2. **Ignore "Start here".** Click **Environments** in the left-hand menu.
3. Click **development**, enter the username and password, and save. If they answered 2, repeat for every environment.

If they answered 1, once development is saved, copy its `user` and `password` lines in `flyway.user.toml` (git-ignored) under each other environment there. The password line is only a reference to Desktop's secret store. Tell them you did.

## 6. Capture your database (the schema model)

Say: "I'll read your Dev database and save its structure as files in `schema-model/`. It only reads Dev and takes a minute or two." Run:
```powershell
flyway diff model "-diff.source=development" "-diff.target=schemaModel"
```
Summarise in plain words: roughly how many tables, views and procedures, and anything odd (for complex databases, objects that reference other databases or linked servers). Ask: "Does that look right? Anything Flyway should ignore, like another team's schema?" If yes, add it to `Filter.scpf` and run it again. If nothing was captured, Dev has no tables, so go back and fix the source. Never create objects yourself.

**SQL Server: permissions and made-up names.** Watch for two kinds of noise, here and in every later comparison:
- `GRANT` or `DENY` permissions they didn't expect. Permissions usually differ between Dev, Test and Prod, and a DBA or a separate script manages them.
- Differences where only a constraint or index name differs, like `DF__Orders__Creat__19B5BC39`. SQL Server makes these names up when a constraint is created without one, so they differ in every database. Naming constraints explicitly is the long-term fix.

If either shows up, offer to have Flyway ignore it. With their OK, set `ignorePermissions` or `ignoreSystemNamedConstraintAndIndexNames` to `true` under `[redgateCompare.sqlserver.options.ignores]` in `flyway.toml`, then run the comparison again. Users and role memberships are already ignored.

(If the Flyway MCP server is connected, you may use its develop-migrations tools for this and step 8 instead.)

## 7. Set the baseline

Explain in one line: "Your baseline backup is the starting point, so Flyway only deploys changes from here on."
1. **Prove Flyway can use the backup.** Say: "I'll ask Flyway to restore your baseline into the Shadow database. It only touches Shadow and takes a minute or two." Run `flyway info -environment=shadow`. It should show Shadow at version 001. If it fails, the usual causes are a `backupFilePath` the SQL Server can't read (it's a path on the server) or a login that can't restore databases. See the troubleshoot skill.
2. **Mark Test and Prod.** They were restored from the same backup, so they're already at the starting point and only need marking. Ask them to run this in PowerShell in this folder, not SSMS. "It records that each database is at the baseline. It changes no tables."
   ```powershell
   flyway baseline -environment=Test -baselineVersion=001
   flyway baseline -environment=Prod -baselineVersion=001
   ```
   Success says "Successfully baselined schema with version: 001" for each. When they say *done*, carry on.

## 8. Your first migration

Ask them to make one small, harmless change in **Dev**, such as adding a nullable column or a new table. Offer to write the SQL for them to run. When they say done:
1. **Capture:** run `flyway diff model "-diff.source=development" "-diff.target=schemaModel"` and show the change.
2. **Generate:** say "Flyway now restores the shadow from your baseline, compares it with your schema model, and writes the migration and its undo script. It takes a couple of minutes." Run:
   ```powershell
   flyway diff generate "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow" "-generate.types=versioned,undo" "-generate.description=<short_name>"
   ```
   If `migrations/` has no `V` scripts yet, add `"-generate.version=002"` so it lands above the baseline (001).
3. **Show** the new `V` and `U` files and explain each in a sentence: "Flyway wrote these, not us."
4. **Self-check:** run `flyway diff "-diff.source=schemaModel" "-diff.target=migrations" "-diff.buildEnvironment=shadow"`. It should find no differences. That proves the baseline plus the migration rebuild Dev's structure. It shows the script runs, not that it's safe at production volume.

If something fails, follow the troubleshoot skill. Common causes: invalid objects, or objects that depend on another database or a filtered object.

## 9. Try the workflows yourself

Don't walk them through the commands one by one. Say: "If you want to test out the workflows, here is a sequence of commands you can test out: https://documentation.red-gate.com/fd/flyway-poc-worfkflow-325421946.html"
- Add one line on what fits their project: the target here is `Test`, where the page uses `test`, and the `target` and `cherryPick` versions are their own, such as `002`.
- They run the commands themselves.
- If they deploy from Flyway Desktop, warn them in one sentence first: if Desktop offers to "baseline and continue", stop and tell you rather than accept it. Test and Prod are already baselined, so that prompt means Desktop can't see their history, and accepting it could baseline at the wrong version (library file 08, section 18). If it appears, treat it as a problem and follow the troubleshoot skill.
- If they ask about one, explain it.

**In the same message, offer Flyway Desktop,** because the page works in it. First find out whether it's installed: on Windows, run the lookup below; on macOS or Linux, ask. Then offer the right thing:
- **Installed:** "Would you like me to start Flyway Desktop, Redgate's app for Flyway, and help you open your project in it? The project is already set up for it. 1 Yes (default) 2 Not now"
- **Not installed:** "Flyway Desktop, Redgate's app for Flyway, isn't installed yet. Shall I download it for you? Your project is already set up for it. 1 Yes, start the download (default) 2 Not now". Put the installers page in the message too, so they have the link whatever they choose: https://documentation.red-gate.com/fd/installers-172490864.html

**The lookup (Windows).** It reads the installed-programs list, the one exception to "don't search the machine":
```powershell
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object DisplayName -like 'Flyway Desktop*' | Select-Object -First 1 -ExpandProperty InstallLocation
```
No output means it isn't installed. Otherwise the app is `<InstallLocation>\flyway-desktop\Flyway Desktop.exe`.

- **Start the download:** say you're starting it in their browser, then run:
  - Windows: `Start-Process https://download.red-gate.com/Flyway_Desktop.exe`
  - macOS: `open https://download.red-gate.com/FlywayDesktopDarwinArm64.dmg` (Apple silicon) or `open https://download.red-gate.com/FlywayDesktopDarwinX64.dmg` (Intel)
  - Linux: give them the installers page.

  They run the installer from their Downloads folder and sign in with their Redgate account. Never run the installer yourself. When they say *done*, run the lookup again and open it.
- **Open it:** Flyway Desktop ignores a project path given on its command line, so it can't load the project by itself. Get them as close as you can:
  1. Say you're starting Flyway Desktop and copying the path of this project's `flyway.toml` to their clipboard. On Windows, run `Set-Clipboard -Value '<this folder>\flyway.toml'`, then `Start-Process "<app>"`. Some AI tools close programs they start when the command ends. If it doesn't stay open, start it with `Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = '"<app>"' }`, or ask them to start it from the Start menu. On macOS or Linux, they start it themselves.
  2. Tell them how to open the project, printing the full paths: "On Flyway Desktop's home screen, under **Open existing project**, click **Open local file** (older versions: **Open project...**). Go to this folder, `<this folder>`, and choose `flyway.toml`." On Windows, add: "The full path is on your clipboard, so you can paste it into the **File name** box and press Enter." If Desktop asks them to sign in, they use their Redgate account. If a page says "Start here", they can ignore it.
  3. Ask them to say *done* once the project is open. Never say it's loaded until they confirm.
- **Once it's open:** **Schema model** compares Dev with `schema-model/` and **Generate migrations** writes migrations, the same work you did in step 8. Desktop and the command line share this project's files.
- **Not now:** they can say *desktop* any time, and the link is in your message.

Once Desktop is sorted, end with: "Work through the workflow page at your own pace, in Flyway Desktop or in PowerShell, and ask me about anything along the way. When you're ready, reply:
1. Done, and tell me which ones you tried: deploy, check, drift, undo (default)
2. Set up a pipeline now, and come back to the workflows later"
- **1:** note what they tried in the profile, celebrate, then offer the pipeline (step 10).
- **2:** note in the profile that they skipped ahead, then go to step 10. They've already said yes, so ask its first question without *Not now*.

## 10. Pipeline (optional)

Offer this once step 8 works and they've finished with step 9, or straight away if they chose to skip ahead to it there. Coming from "If they already have a Flyway project", start at the first question without *Not now*. Work in their project folder: the pipeline files go there, with `Test` and `Check` swapped for their environment names. Everything for it is in `pipelines/`: read `pipelines/README.md`, then the chosen tool's `README.md`, and follow it. The pipeline is deliberately basic. It builds a report on the **Check** database (changes, drift, code review and the SQL to run), then deploys to one downstream environment, **Test**. Prod stays manual.

1. **Offer:** "Would you like help with a pipeline, so each new migration gets a report and is deployed to Test automatically?
   1. Yes, on this machine. I can set the whole thing up for you, out of the box: the pipeline, the repo, and step-by-step help installing the tool (default)
   2. Yes, with the CI/CD tool my team already uses
   3. Not now"

   If 3, go to the wrap-up.
2. **Tool:**
   - **After 1:** "Which shall we set up? 1 GitHub Actions: code on GitHub, runner on this machine (default) 2 Azure DevOps: a free online organisation, agent on this machine 3 Jenkins: everything on this machine, no online account 4 GitLab: GitLab.com, runner on this machine"
   - **After 2:** "Which tool does your team use? 1 GitHub Actions 2 Azure DevOps 3 Jenkins 4 GitLab 5 Something else (name it)". Option 5 uses `pipelines/other/`.
3. **Where things live:** the code and the pipeline are sometimes in different places, so ask about each, one at a time.
   - **Code:** "Where will this project's code live?" Offer only the places the tool supports, with its own as the default:
     - GitHub Actions: GitHub only, so don't ask.
     - GitLab: GitLab only, so don't ask.
     - Azure DevOps: Azure Repos or GitHub.
     - Jenkins and other tools: any Git server. With Jenkins they can also keep it only on this machine, which is the default after 1.
   - **Pipeline (after 2 only):** "Will the pipeline file live in this project's repo, or in a separate repo your team keeps pipelines in? 1 This project's repo (default) 2 A separate repo (name it)". The tool's README says what changes for a separate repo.

   Record the tool, the route, and where the code and the pipeline live in the Pipeline row of `project-profile.md`.
4. **Build it.** Do everything that doesn't need their accounts, secrets or admin rights, and tell them what you did:
   - **The pipeline file:**
     - For GitHub Actions, copy `pipelines/github-actions/flyway.yml` to `.github/workflows/flyway.yml`. The other tools' files stay where they are.
     - Tailor it from `flyway.toml` and the profile. For a SQL login in Jenkins, uncomment the login lines; the other tools pick the login secrets up once they're set. For Oracle, remove `-code` and pass `FLYWAY_CHECK_CONNECT` from a secret. For a separate pipeline repo, a runner label or another agent pool, make the change the README describes.
   - **A repo of its own:** this folder is a clone of the sandbox repo, so it needs a home of its own, unless the code stays only on this machine. An existing project that already has a remote (`git -C <folder> remote -v`) skips this. Still ask before committing there.
     - First ask: "May I commit your project so it can be pushed? It includes `flyway.toml` (server and database names, no passwords), the schema model, the migrations and the pipeline. 1 Yes (default) 2 I'll commit it myself".
     - They create an empty private repo and send you its URL.
     - You run `git remote rename origin sandbox` and `git remote add origin <url>`.
     - They run `git push -u origin main`, which may ask them to sign in.
   - **The Redgate token:** when you reach the secrets step, say you'll open Redgate's personal access token page in their browser, then run `Start-Process 'https://identityprovider.red-gate.com/personaltokens?returnUrl=https%3A%2F%2Fportal.red-gate.com%2Fproducts'` (macOS: `open`, Linux: `xdg-open`). Put the link in your message too. They sign in with the Redgate account that holds their Enterprise licence, create a token and copy it straight away, because it's shown only once. Then they paste it into the `FLYWAY_TOKEN` secret themselves. Never ask to see it.
   - **After 1:** walk them through the README's "Set it up on this machine", one step per message. They run the installers and registration commands and enter every secret themselves. Never run an installer yourself, and never see a token. The runner or agent runs in a terminal window as them, so Windows sign-in and Flyway work as they do now.
   - **After 2:** walk them through the README's "Use your team's…" section, one step per message. If someone else runs the tool, offer to write a short note for them listing the runner, secrets and pipeline path it needs.
5. **First run:** they start it by hand. Nothing is pending, so it only proves the runner, licence, connections and report; they open the report from the run's artifacts. Then the real thing:
   - In the sandbox, they make another small change in Dev, and you capture it and generate the next migration as in step 8. In an existing project, they generate one the way they usually do.
   - With their OK, you commit it, and they push.
   - The pipeline builds the report on Check and deploys to Test.
   - They confirm with `flyway info -environment=Test`.

   Prod stays manual.

If a run fails, follow the troubleshoot skill. The usual causes are:
- a runner that can't reach the server, or whose account has no access to the databases
- a missing secret
- Flyway not on the runner's `PATH`

The baseline backup must be readable by the SQL Server the pipeline connects to. On the same server, that's already the case.

## 11. Wrap-up

Congratulate them. Summarise what they have in a few lines: a Flyway project on their own database, a baseline backup, the migrations, what they tested and the pipeline. Update `project-profile.md`. Remind them kindly that this was a sandbox. For real use, they build the project with their DBAs and their Redgate SE, taking the baseline from their real production structure. Offer follow-ups: another change, a filter, reference data tables, a QA stage, or the pipeline if they skipped it.

## If they already have a Flyway project

They skip the sandbox and go straight to a pipeline. Say in one line: "Great, we'll set up a pipeline for your project. I'll only read its settings, and change nothing until you agree."
1. **Where it is:** "What's the full path of the folder that contains your project's `flyway.toml`? If it's only in a remote repo, clone it first." From here on, you may also work in that folder.
2. **Read it:** read its `flyway.toml`, never `flyway.user.toml`. Note:
   - the database platform
   - the environment names, and which ones have a `provisioner`
   - whether the URLs use Windows sign-in (`integratedSecurity=true`) or need a login

   Summarise in two or three plain lines. If the file holds a password, don't repeat it, and suggest moving it to a secret. The check report and drift need Flyway Enterprise.
3. **Where to deploy:** "Which environment should the pipeline deploy to?" List their environments, numbered, with a test one as the default. It must be a test environment. If they pick production, or one with real customer data, stop kindly (rule 1).
4. **The report's scratch database:** the change report needs an environment Flyway can rebuild (one with a `provisioner`), other than development and shadow, which belong to the developers. If they have one, offer it as the default. Otherwise ask: "The report needs an empty scratch database Flyway can rebuild. 1 I'll add a Check environment: you create an empty database, and I add it to `flyway.toml`, set up like your shadow (default) 2 Leave out the change report; you still get drift, code review and the SQL to run"
   - **1:** they create the empty database on the target's server; give them the one-line `CREATE DATABASE`. When they say *done*, and once they agree to the change, add `[environments.Check]` with its URL and the same `provisioner` and resolver block as their shadow.
   - **2:** in the pipeline file, remove `-changes`, `"-check.buildEnvironment=Check"` and the Check login arguments.
5. **Record and go on:** in `project-profile.md`, note the starting point (existing project at its path), the target and the report environment. Then go to the Pipeline step.

## If a backup isn't possible (Azure SQL Database or Managed Instance)

Use a baseline script instead and say so in one line: "Your platform can't back up to a file, so Flyway will write the starting point as a SQL script instead." The changes:
- **Step 4:** they create Dev, Test and Prod as copies of their database in their usual way (for example the portal's Copy), plus empty Shadow, Check and Build. Copies include data, so the source must hold nothing sensitive.
- **Step 5:** shadow, Check and Build get `provisioner = "clean"` and no resolver block.
- **Step 7, item 1:** instead, say "I'll write the baseline script into `migrations/`. It only reads Dev." Then run:
  ```powershell
  flyway diff generate "-diff.source=development" "-diff.target=empty" "-generate.types=baseline" "-generate.description=Baseline" "-generate.version=001"
  ```
  Show the `B001…` file and summarise it. If Flyway added a timestamp to its version, use that full version, quoted, in the `baseline` commands. Item 2 is unchanged.

## Commands the user can type

`done`, `where am I`, `next`, `back`, `skip`, `desktop` (open the project in Flyway Desktop, downloading it first if needed), `pipeline` (set up a pipeline), `problem` (switch to the troubleshoot skill), `more` (fuller detail), `end`.

## Where to look for detail

- Library `Documentation/FlywayAIDump/` (SQL Server): concepts 02, install and licence 04, POC plan 05, baselines and Backup as Baseline 07, developer workflows 08, `flyway.toml` 10, pipelines 11 and 12, checks 13, drift and undo 14, MCP server 20, errors 22 and 23.
- Redgate: Backup as Baseline (https://documentation.red-gate.com/flyway/learn-more-about-flyway/how-to-articles/use-a-sql-server-backup-to-baseline-a-database) and the POC checklist (https://documentation.red-gate.com/fd/poc-checklist-317493040.html).
- Oracle: `oracle.md`. PostgreSQL and MySQL: `postgresql-mysql.md`. Each lists the Redgate pages it relies on.
- Pipelines: `pipelines/README.md` and each tool's `README.md`. Redgate: Flyway AutoPilot (https://documentation.red-gate.com/flyway/getting-started-with-flyway/first-steps-flyway-autopilot-a-beginners-guide) and the sample pipelines (https://github.com/red-gate/Flyway-Sample-Pipelines).

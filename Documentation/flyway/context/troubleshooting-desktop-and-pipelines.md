<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# Flyway troubleshooting: Desktop and CI/CD pipelines

Entry point: `troubleshooting-patterns.md`. Quoted messages are verbatim from docs or engine source unless marked "(field report)". Owner key: **Dev**, **DBA**, **DevOps**, **SE** (Laura), **Support** (Redgate support), **Network** (customer network/security team).

## Flyway Desktop

### D1. Desktop will not start, or reports JSON parse errors from the CLI
- **Symptom (field reports):** "Failed to parse the response from the flyway CLI as json.: Failed to parse result 'Error occurred during initialization of VMFailed setting boot class path.'", "Failed to parse result '' as json: Unexpected end of JSON input", "Invalid file descriptor to ICU data received".
- **Likely causes:** (1) corrupted install or half-applied auto-update; (2) antivirus quarantining the bundled JRE or CLI.
- **Ask:** Desktop version (Help > About)? Did it update recently? Any endpoint protection?
- **Check:** Desktop logs (see D8); whether the bundled CLI runs from a terminal.
- **Fix (user-confirmed):** uninstall, delete `C:\Program Files\Red Gate\Flyway Desktop` and `%localappdata%\Temp\Redgate\Flyway Desktop\updates`, reinstall (https://productsupport.red-gate.com/hc/en-us/community/posts/24974470985373 , https://productsupport.red-gate.com/hc/en-us/articles/22173309816733).
- **Owner:** Dev; Support if it recurs.
- **Escalate when, and collect:** verbose logs zipped, OS version, Desktop version.

### D2. Desktop licensing or sign-in
- **Symptom:** sign-in loop, browser does not open, features greyed out, AI features missing.
- **Causes / fix:** Desktop activates with a Redgate ID and needs a Desktop tools entitlement; firewall must allow red-gate.com (and the licensing hosts in `troubleshooting-enterprise.md` E5). Browser cannot open: copy the sign-in link (9.5.3+). Air-gapped: User icon > Licensing > Manage offline license with a productCode=64 permit. Desktop AI needs org admin opt-in and access to `api.prod.prompt.redgate-platform.com` (see `ai-and-mcp.md`).
- **Owner:** Dev; Licensing for entitlement.

### D3. Project and configuration errors
- **Symptom:** "ERROR: Failed to configure parameters: ... Environment 'development' not found. Check that this environment exists in your configuration." (field report, https://github.com/flyway/flyway/issues/4008); Desktop prompts for connection details every time; "Caused by: Error reading secret: Element not found." after "Unable to get local secret" (KB field report, https://productsupport.red-gate.com/hc/en-us/articles/31765416438685).
- **Likely causes:** (1) `flyway.toml` sets `environment = "development"` but the environment lives only in another user's `flyway.user.toml`; (2) `[flywayDesktop]` names an environment that does not exist (Desktop then prompts); (3) `${localSecret.X}` values are machine-specific, so a project copied from another machine cannot read them; (4) a `.conf` project.
- **Fix:** define the environment in your `flyway.user.toml`; use `developmentEnvironment` / `shadowEnvironment` keys (see `common-architectures.md`); re-enter credentials so Desktop re-creates the local secret; open `.conf` projects in Desktop to auto-upgrade to TOML (backup kept) or `flyway init -from=<conf> -fromType=Conf`.
- **Owner:** Dev.

### D4. Git inside Desktop
- **Symptom:** Git features missing or "Download Git" shown; "Running git push failed: fatal: 'origin' does not appear to be a git repository" (field report, staff: https://productsupport.red-gate.com/hc/en-us/community/posts/24974251058333); push rejected; master/main mismatch.
- **Fix:** install Git and put it on PATH (9.9.1 gives a clearer error); add the remote; on push rejected use "Pull changes" (9.5.10); set `git config --global init.defaultBranch main` (staff advice, field report). Non-Git VCS: save in Desktop, commit with your own client. Merge conflicts are per object file in the schema model.
- **Owner:** Dev.

### D5. Schema model shows wrong, missing or unreadable objects
- **Symptom:** objects missing; "--No text is available" for an object (KB: encrypted object or insufficient permissions, grant db_owner or equivalent, https://productsupport.red-gate.com/hc/en-us/articles/31743554958493); "Error running flyway diff Failed to find parameter Schemas.: Failed to find parameter Schemas." (field report, unresolved Feb 2026, https://productsupport.red-gate.com/hc/en-us/community/posts/34286967624477); "Exception while reading from stream" on PostgreSQL after an update (field report, unanswered).
- **Likely causes:** filters excluding the object (users and certificates are excluded by default on SQL Server); dependencies pulled in even when filtered; permissions to read definitions; schema list (`schemas`) not including the schema.
- **Check:** `Filter.scpf` / Oracle `IgnoreRules.scpf`; environment `schemas`; run the equivalent CLI ("View command") with `-X`.
- **Fix:** adjust filters (SQL Server LIKE needs `[_]` to match a literal underscore); set `schemas`; grant VIEW DEFINITION.
- **Owner:** Dev / DBA. **Escalate when, and collect:** verbose Desktop log, the CLI command and `-X` output, filter file.

### D6. Filters not behaving
- Filters apply after comparison (no speed gain); Oracle ignore rules apply before (faster). Filters apply to schema model, generation and drift; override drift filtering with `check.filterFile`. Unsupported expressions from imported files show read-only in the UI. Drift resolution can generate a filter file (SQL Server, Oracle).
- **Owner:** Dev.

### D7. Shadow database problems in Desktop
- **Symptom:** generate is slow, fails on shadow, or shadow keeps re-provisioning.
- **Causes / fix:** Desktop re-provisions when checksums change, the shadow is ahead of scripts, names mismatch, a previous run failed, or only repeatables exist. Keep one shadow per developer per project on the same server as dev (cross-database references). Baseline script will not build (invalid or externally dependent objects): use "find invalid objects before baselining", filters, or a `backup`/`snapshot` provisioner. Docker provisioner in Desktop only for SQL Server, Oracle, PostgreSQL, MySQL projects; Docker-provisioned connection details are not saved (9.8.2). Test connection started a second container: fixed 9.9.1.
- **Owner:** Dev.

### D8. UI state, caching and logs
- Desktop pins an engine build per release (for example Desktop 9.10.1 ships engine 13.8.0). A CLI on the agent older than Desktop can fail on project files Desktop wrote (`COMPARISON_ENGINE_UPDATE_REQUIRED`). Align versions.
- Upstream changes are checked on window focus (9.8.3); refresh comparisons after pulling.
- **Logs:** Settings (cog) > logging level "verbose"; logs at `%USERPROFILE%\AppData\Local\Red Gate\Logs\Flyway Desktop`, with a link in settings to open the folder. From Desktop 9.10.3, log files older than a month are deleted when Desktop starts; for an older incident, change Settings > Log retention before the logs age out. macOS/Linux paths are not documented (unverified). From Desktop 8.5.13, verbose also writes Flyway CLI debug logs.
- A Desktop diagnostic/support bundle feature is not documented (unverified): zip the logs folder.

## CI/CD pipelines

### P1. Exit codes changed in 12.9
- **Symptom:** pipeline treats a failure as success or retries wrongly after upgrading past 12.9.0; script checked `$LASTEXITCODE -eq 1`.
- **Facts:** docs list 0, 1 (uncategorised) and 35 (licensing). 12.9.0: "Flyway CLI now exits with a distinct exit code derived from the error code when a FlywayException is thrown". In the 13.8.0 open-source source, all core error codes (validate, migrate, configuration, connection) still return 1 and licensing returns 35; codes defined in Enterprise modules may return others, and no mapping is published (unverified).
- **Fix:** any non-zero = fail; branch only on 35; use `-outputType=json` and read `error.errorCode` for logic. Historical: 12.2.0 fixed exit 0 on failed migrations when multiple report generators loaded; a Maven-assembled CLI missing `flyway-reports` showed exit 0 on failure (field report, https://github.com/flyway/flyway/issues/4026).
- **Owner:** DevOps.

### P2. `flyway` not found or wrong version on the agent
- **Causes / fix:** not installed or not on PATH; different agents with different versions; Desktop-generated scripts assume Desktop's engine. Pin the version (setup action `version:`, Docker tag, or download URL) and print `flyway version` at the start of every job.
- **Owner:** DevOps.

### P3. GitHub Actions
- `red-gate/setup-flyway@v3` inputs: `version`, `edition` (required: community, teams, enterprise), `i-agree-to-the-eula` (required), `email`, `token`, `max-auth-attempts`, `architecture`, `platform`, `clean-old-cached-versions`.
- `red-gate/flyway-actions` (v2): `migrations/checks`, `migrations/deploy`, `migrations/generate`, `migrations/undo`, `state/prepare`, `state/deploy`; outputs include `exit-code`, `drift-detected`. Keep all action versions aligned.
- Typical failures: secrets not available to workflows from forks; GitHub-hosted runners cannot reach on-prem databases (use self-hosted); environments without required reviewers mean no gate; two runs sharing a build DB (add `concurrency:`).
- **Owner:** DevOps.

### P4. Azure DevOps
- Secret variables are not exported automatically: map each into the step `env:`.
- `redgate/flyway:*-azure` images have no entrypoint: commands must start with `flyway` (docs). Field report: "ERROR: Invalid flag: flyway" from a `latest-azure` regression, fixed 11.13.2; pin tags (https://github.com/flyway/flyway/issues/4139). "Invalid flag" generally means a parameter and value were split by quoting (KB, https://productsupport.red-gate.com/hc/en-us/articles/9862660044317).
- PowerShell tasks: "ERROR: Invalid argument: -check" (dotted args split). Quote: `"-check.buildEnvironment=build"`. URLs with `;` or `&`: PowerShell `-url='"jdbc:..."'`.
- **Owner:** DevOps.

### P5. GitLab CI
- Image entrypoint must be overridden: `entrypoint: [""]` ("Gitlab... is expecting to talk to some kind of shell", docs).
- Protected variables are empty on unprotected branches: a job on a feature branch runs as Community or fails to connect. Check the variable's Protected flag.
- Service containers are reached by `alias`, not localhost. Key files (Snowflake key-pair) are not visible inside job containers unless provided as file variables (field report, https://github.com/flyway/flyway/issues/4041).
- Worked example: `arch-sqlserver-gitlab-migrations.md`.
- **Owner:** DevOps.

### P6. Jenkins
- No Redgate-published Jenkins plugin for Flyway; run the CLI or Docker image from `sh`/`bat` steps (general practice, unverified as a documented Redgate pattern). Inject `FLYWAY_EMAIL`, `FLYWAY_TOKEN` and database passwords with the Credentials Binding plugin; Jenkins masks bound values. `bat` returns the process exit code, so the non-zero rule in P1 applies. Serialise deploys with `lock` (Lockable Resources plugin) or `disableConcurrentBuilds()`.
- **Owner:** DevOps.

### P7. Docker images
- Variants: base (`redgate/flyway:<v>`), `-alpine`, `-azure` (no entrypoint), `-mongo` (mongosh), `-oracle` (SQLcl in `/opt/sqlcl`, Redgate base only). Mount the project and pass `-workingDirectory=project`. Redgate images include SQLFluff and .NET dependencies for comparison; custom images must install them. JRE 25 in images from 13.6.0. Images upgrade ca-certificates at build time (13.11.0) and block distrusted CA certificates in the Java trust store (13.11.1). Pin tags; `latest` regressions have happened (field reports: 10.7.1 SCRAM password ignored, fixed 10.7.2, https://github.com/flyway/flyway/issues/3837; 10.8.0 PostgreSQL `SHOW VARIABLES` error, fixed 10.8.1, https://github.com/flyway/flyway/issues/3841).
- **Owner:** DevOps.

### P8. Agent platform problems
- Comparison features need a supported OS (.NET 8; RHEL 7 unsupported) and bundled SQLFluff needs GLIBC 2.35+. Docker provisioner needs Docker on the agent and the agent user in the `docker` group. Parallel pipelines must not share a build database (`check -changes` assumes exclusive use).
- **Owner:** DevOps.

### P9. Network, proxy and TLS
- 13.9.0+: OS proxy inheritance is off by default; set `FLYWAY_USE_SYSTEM_PROXIES=true` to make CLI and Docker pass `-Djava.net.useSystemProxies=true` (13.4.0 to 13.8.x did this automatically). Likely symptom after upgrading to 13.9.0 (inferred from the network troubleshooting page): Flyway can no longer reach licensing or other internet hosts that worked on 13.4.0 to 13.8.x, while the browser still works. Windows WPAD/PAC lookup costs about 90-100 ms per run when enabled. On Linux and in Docker only a manually configured proxy is used.
- Explicit proxy: `JAVA_ARGS=-Dhttps.proxyHost=... -Dhttps.proxyPort=... -Dhttp.nonProxyHosts=*.corp.example` (covers HTTP and HTTPS). Maven/Gradle: `MAVEN_OPTS`/`GRADLE_OPTS`. `-X` logs the proxy detected.
- TLS inspection: "PKIX path building failed" on licensing or database connections means the JVM does not trust the CA; add it to a truststore and pass `-Djavax.net.ssl.trustStore=...` in `JAVA_ARGS`. From Flyway 13.11.1 distrusted CA certificates are blocked in the Java trust store of the bundled JREs and Docker images; a certificate error that starts right after upgrading to 13.11.1 may mean the server or proxy certificate chains to one of those CAs (inferred, not stated in the notes).
- **Owner:** Network / DevOps.

### P10. Wrong environment, config or paths
- `environment` defaults to `default`: always pass `-environment=<id>`. Relative paths resolve from the working directory: pass `-workingDirectory`. `-configFiles` replaces auto-discovery. "Unable to connect to the database. Configure the url, user and password!" usually means no config was loaded. `-X` (13.5+) prints each effective setting and its origin. 13.2.0 fixed environment-level settings (custom history table, default schema) being lost when switching environment.
- **Owner:** DevOps.

### P11. Gate did not stop the deploy
- `check -drift -failOnDrift` and `check -code -failOnError` do not stop later verbs chained in the same command. One gate per step. Namespaced params: use full form (`-check.failOnDrift=true`) in scripts.
- **Owner:** DevOps.

## Sources
- https://documentation.red-gate.com/fd/licensing-164167730.html
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/flyway-desktop-8-release-notes-294781518.html
- https://documentation.red-gate.com/spaces/FD/pages/138347156 (Flyway Desktop logging)
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace
- https://documentation.red-gate.com/flyway/flyway-concepts/database-comparisons/comparison-filtering
- https://documentation.red-gate.com/flyway/reference/filter-formats/sql-server-filter-format
- https://documentation.red-gate.com/flyway/flyway-concepts/environments/shadow-and-build-environments
- https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes
- https://github.com/flyway/flyway/blob/main/flyway-commandline/src/main/java/org/flywaydb/commandline/Main.java
- https://github.com/flyway/flyway/blob/main/flyway-core/src/main/java/org/flywaydb/core/api/CoreErrorCode.java
- https://github.com/red-gate/setup-flyway
- https://github.com/red-gate/flyway-actions
- https://documentation.red-gate.com/spaces/FD/pages/165740750 (GitLab)
- https://documentation.red-gate.com/spaces/FD/pages/160727137 (Azure DevOps)
- https://documentation.red-gate.com/spaces/FD/pages/321585710 (Flyway Docker)
- https://github.com/flyway/flyway/tree/main/flyway-docker (image variants and Dockerfiles)
- https://hub.docker.com/r/redgate/flyway
- https://documentation.red-gate.com/spaces/FD/pages/360186420 (Network troubleshooting)
- https://documentation.red-gate.com/fd/reference/usage/command-line
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://www.jenkins.io/doc/pipeline/steps/credentials-binding/
- Field reports linked inline (GitHub issues and Redgate community/KB)

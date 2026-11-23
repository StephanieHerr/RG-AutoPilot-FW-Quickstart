<!-- last-verified: 2026-10-12 | refreshed-by: weekly refresh routine -->

# flyway.toml configuration reference

Source of truth for generating customer config. Every key below was checked against its Redgate reference page on the date above. If a key is not here, look it up before using it; do not guess. TOML keys are case-sensitive.

## File structure

```toml
databaseType = "SqlServer"          # root-level project keys (written by init / Desktop)
id = "<guid>"
name = "MyProject"

[flyway]                            # engine settings, apply to all environments
[flyway.placeholders]               # user placeholders
[flyway.<command>]                  # command namespaces: check, check.code, deploy, prepare, snapshot, generate, migrate, diff, diffText, model, add, init
[flyway.<db>]                       # DB namespaces: oracle, sqlserver, sqlserver.clean, postgresql, clickhouse, db2z

[environments.<id>]                 # connection: url, user, password, schemas, provisioner ...
[environments.<id>.flyway]          # per-environment override of [flyway] settings
[environments.<id>.jdbcProperties]  # driver properties
[environments.<id>.resolvers.<r>]   # resolver / provisioner config

[flywayDesktop]                     # Desktop-only settings (no engine effect)
[redgateCompare]                    # comparison options, filters, static data (Enterprise features)
```

Root-level keys: `databaseType`, `id`, `name` are what Desktop-generated projects contain (observed in a real project). The `init` reference says it sets `databaseType` and `projectName`; no dedicated reference page for root keys was found. Docs say not to change these after creation except the name.

Namespace rules:
- Command namespaces are distinct from root keys: `diff.target` is not `target`.
- `[environments.X.flyway]` can override any `[flyway]` setting that is configurable in TOML **except** `environment`, `cherryPick`, `email`, `token`, `licenseKey`, `undoSqlMigrationPrefix`. Child namespaces (e.g. `flyway.oracle`) **cannot** be overridden per environment. No env-var form exists for overrides.
- Flyway 13.10.0 release notes: plugin parameters "such as `undoSqlMigrationPrefix` and `check.buildEnvironment`" can now be set per environment under `[environments.<name>.flyway]`. The environment Flyway namespace page still lists `undoSqlMigrationPrefix` as excluded and child namespaces as not overridable (checked 2026-10-12 and again 2026-10-19). Test on 13.10.0+ before relying on a per-environment plugin setting.
- Environment is selected with `environment` (singular); defined under `environments` (plural). Default environment name: `default`. Flyway 13.10.1+ prints the name of the environment it is working on and warns when environment names differ only by case.
- Legacy `url`/`user`/`password` at root map onto an environment named `default`.

## Files and precedence

Load order of TOML files (later wins): `{installDir}/conf/`, `{userhome}/`, `{executionDir}/`, `{workingDirectory}/`. In each folder `flyway.user.toml` overrides `flyway.toml`. `flyway init` adds `*.user.toml` to `.gitignore`. Desktop stores dev and shadow connection details in `flyway.user.toml` by default.

Setting precedence (highest first): command-line args, environment variables, standard input (`-configFiles=-`), config files, defaults.

TOML vs legacy `.conf`: TOML wins. Specifying both in `-configFiles` is an error. `-configFiles` or `FLYWAY_CONFIG_FILES` replaces auto-discovery. Upgrade `.conf` with `flyway init -fromType=Conf`.

Debug where a value came from: `flyway info -X` (13.5.0+ prints each final value and its origin).

## Resolvers

Syntax `${resolverName.key}`. Can be inlined inside strings. Escape with `$${a.b}` or wrap whole value in `!{ ... }`. Filter characters with `${r.key:AD}` (`A` letters, `a` ASCII letters, `D` digits, `d` ASCII digits). Nesting not allowed. A resolver that depends on another must be configured after it.

| Resolver | Syntax | Config table | Edition | Notes |
|---|---|---|---|---|
| Environment variable | `${env.VAR}` | none | All | Works in all parameters (12.6.2+), not just environment properties. Preferred for CI secrets. |
| Azure Key Vault (12.5+) | `${azureKeyVault.secret-name}` | `[environments.X.resolvers.azureKeyVault]` `vaultUrl` (required) | Enterprise | Auth mechanism to Azure not described on the page (unverified). |
| HashiCorp Vault | `${vault.path/to/secret/key}` | `[environments.X.resolvers.vault]` `url`, `token`, `engineName`, `engineVersion` (all required) | Enterprise | Only API v1 URLs. |
| Dapr | `${dapr.key}` | `[environments.X.resolvers.dapr]` `url` | Enterprise | |
| Google Cloud Secret Manager | `${googlesecrets.key}` | `[environments.X.resolvers.gcsm]` `project` | Enterprise | |
| Local secret | `${localSecret.key}` | none | All | OS store (Windows Credential Manager Generic Credential, macOS keychain service `Flyway`, libsecret). Not for CI. |
| Git | `${git.branch}`, `commit`, `user`, `email` | none | Teams+ | e.g. per-branch dev DB name. |
| Local DB | `${localdb.pipeName}` | `[environments.X.resolvers.localdb]` `instanceName` | All | SQL Server LocalDB via jTDS only. |
| Placeholder | `${placeholder.NAME}` | uses `[flyway.placeholders]` | All | User placeholders only, not `${flyway:...}`. |
| Microsoft Entra interactive | `${entraId.token}` into `jdbcProperties.accessToken` | `[environments.X.resolvers.entraId]` `tenantId`, `clientId` | All (no tier stated) | Alias of `azureAdInteractive` (12.0.1+). |
| Lakebase (Flyway 13.10.0) | `${lakebase.user}`, `${lakebase.token}` | `[environments.X.resolvers.lakebase]` `workspaceUrl`, `project` (required); `branch`, `compute` (default `production` / `primary`), `redirectUri` | Not stated | Databricks Lakebase via interactive Databricks sign-in (browser); no stored secret. Not suitable for automation. |
| Databricks (Flyway 13.10.1) | `${databricks.tokenCachePassPhrase}` into `jdbcProperties.TokenCachePassPhrase` | none | Not stated | Browser-based OAuth to Databricks (`AuthMech=11;Auth_Flow=2`): generates a per-user passphrase for the driver token cache and stores it in the OS secret store. |
| Redgate Clone | | | | Deprecated; removed from Desktop 9. Do not use. |

Environment-variable config (no TOML): `FLYWAY_<SETTING>` for `[flyway]` keys (e.g. `FLYWAY_LOCATIONS`), `environments_<env>_<setting>` for environments (e.g. `environments_prod_password`, nested: `environments_prod_jdbcProperties_accessToken`). Prefix case-insensitive (13.1.0+); nested `jdbcProperties` keys keep exact case.

## Parameter table

Namespace `flyway` = `[flyway]` table (and CLI `-name=`). Edition column uses doc tier labels; blank = Community.

### Connection (in `[environments.X]`)

| Name | Type | Default | Notes |
|---|---|---|---|
| `url` | String | required | JDBC URL. |
| `user` | String | none | |
| `password` | String | none | Use a resolver. |
| `schemas` | String array | `[]` | Case-sensitive. Flyway creates missing ones and cleans in list order. First is default schema if `defaultSchema` unset. |
| `displayName` | String | none | Desktop only. |
| `driver` | String | auto from url | |
| `connectRetries` | Integer | `0` | |
| `connectRetriesInterval` | Integer (s) | `120` | |
| `initSql` | String | none | **Deprecated 12.5.0**; use `afterConnect` callback. PostgreSQL session role changes (e.g. `SET ROLE`) made in `afterConnect` persist into migrations from Flyway 13.11.0 (Issue 4286), matching `initSql`. |
| `provisioner` | String | `none` | See Provisioners. Enterprise. |
| `jdbcProperties.<key>` | String | none | e.g. SQL Server `accessToken` (cannot go in URL). |

### Locations, naming, reading

| Name | Namespace | Type | Default | Notes |
|---|---|---|---|---|
| `locations` | flyway | String array | CLI: `filesystem:sql` | Use `filesystem:` prefix; relative to working directory. Do not rely on default. |
| `callbackLocations` | flyway | String array | none (init adds `filesystem:callbacks`) | If unset, callbacks scanned from `locations`. `deploy` callbacks only from here. |
| `callbacks` | flyway | String array | `["db/callback"]` | Java callback classes/packages only. |
| `failOnMissingLocations` | flyway | Boolean | `false` | |
| `sqlMigrationPrefix` / `repeatableSqlMigrationPrefix` / `baselineMigrationPrefix` | flyway | String | `V` / `R` / `B` | |
| `undoSqlMigrationPrefix` | flyway | String | `U` | Teams. |
| `sqlMigrationSeparator` | flyway | String | `__` | |
| `sqlMigrationSuffixes` | flyway | String array | `[".sql"]` | |
| `validateMigrationNaming` | flyway | Boolean | `false` | `true` fails fast on badly named files. |
| `encoding` | flyway | String | `UTF-8` | |
| `detectEncoding` | flyway | Boolean | `false` | |
| `placeholderReplacement` | flyway | Boolean | `true` | |
| `placeholderPrefix` / `placeholderSuffix` / `placeholderSeparator` | flyway | String | `${` / `}` / `:` | |
| `placeholders.<key>` | flyway.placeholders | String | none | Case-insensitive match. Built-ins: `${flyway:defaultSchema}`, `user`, `database`, `timestamp`, `filename`, `workingDirectory`, `table`, `environment`. |
| `jarDirs` | flyway | String array | `<install>/jars` | |

### Execution and history

| Name | Namespace | Type | Default | Notes |
|---|---|---|---|---|
| `environment` | flyway | String | `default` | Target environment. |
| `defaultSchema` | flyway | String | first of `schemas`, else DB default | Holds schema history table. |
| `table` | flyway | String | `flyway_schema_history` | |
| `tablespace` | flyway | String | DB default | |
| `createSchemas` | flyway | Boolean | `true` | |
| `cleanDisabled` | flyway | Boolean | `true` | Set `false` only on disposable envs via `[environments.X.flyway]`. |
| `baselineOnMigrate` | flyway | Boolean | `false` | |
| `baselineVersion` | flyway | String | `"1"` | |
| `baselineDescription` | flyway | String | `<< Flyway Baseline >>` | |
| `outOfOrder` | flyway | Boolean | `false` | No effect on undo. |
| `validateOnMigrate` | flyway | Boolean | `true` | |
| `ignoreMigrationPatterns` | flyway | String array | `"*:future"` | `type:status`, e.g. `"repeatable:missing"`. |
| `target` | flyway | String | `latest` (migrate), `current` (undo) | |
| `cherryPick` | flyway | String array | `[]` | Teams. Not overridable per env. |
| `group` | flyway | Boolean | `false` | Not for Native Connectors. |
| `mixed` | flyway | Boolean | `false` | PostgreSQL, SQL Server, SQLite. |
| `executeInTransaction` | flyway | Boolean | `true` | |
| `batch` | flyway | Boolean | `false` | |
| `stream` | flyway | Boolean | `false` | |
| `lockRetryCount` | flyway | Integer | `50` | `-1` = forever. |
| `installedBy` | flyway | String | DB user | |
| `outputQueryResults` | flyway | Boolean | `true` | |
| `skipExecutingMigrations` | flyway | Boolean | `false` | Marks as applied without running. |
| `errorOverrides` | flyway | String array | `[]` | Teams. Format `STATE:CODE:ACTION` e.g. `"STATE:12345:W"`; `*` wildcards. `deploy` supports it (11.13+). |
| `dryRunOutput` | flyway | String | executes directly | Teams. File path for dry run script. |
| `skipDefaultCallbacks` / `skipDefaultResolvers` | flyway | Boolean | `false` | |
| `migrationResolvers` | flyway | String array | `[]` | Custom Java resolvers. |
| `reportEnabled` | flyway | Boolean | `false` | |
| `reportFilename` | flyway | String | `report.html` | JSON written alongside. |
| `communityDBSupportEnabled` | flyway | Boolean | `true` | |
| `provisionMode` | flyway | String | `provision` | Use on CLI (`-provisionMode=reprovision`), not in TOML. |
| `kerberosConfigFile` | flyway | String | none | Teams. Not for Native Connectors. |
| `email` / `token` | flyway | String | none | PAT licensing. Use `${env.FLYWAY_EMAIL}` etc. |
| `offlinePermitPath` | flyway | String | none | Offline licence permit file. |
| `licenseKey` | flyway | String | none | Deprecated. |
| `publishResult` / `checkDriftOnMigrate` / `pipelineId` | flyway | Boolean/Boolean/String | `false`/`false`/none | Flyway Pipelines, preview. Community ignores (13.2.0+). `checkDriftOnMigrate` deprecated (Flyway 13.10.0, logs a warning). |
| `loggers` | flyway | String array | `["auto"]` | |

Callbacks: SQL callback files named after events, e.g. `afterConnect.sql`, `beforeMigrate.sql`, `afterMigrate.sql`, `beforeCreateSchema.sql` (`createSchema` deprecated), `beforeDeploy.sql`. Undo callbacks are Teams. `afterConnect` reliable on the migration connection from 13.1.0.

### check (`[flyway.check]`, Enterprise except code review and dryrun)

| Name | Type | Default | Notes |
|---|---|---|---|
| `buildEnvironment` | String | `default_build` | Build DB env id for changes/drift. Needs provisioner or `cleanDisabled=false`. |
| `buildUrl` / `buildUser` / `buildPassword` | String | none / `user` / `password` | Inline build DB. |
| `deployedSnapshot` | String | `snapshotHistory:current` | Prefix `filesystem:` or `snapshotHistory:`. |
| `nextSnapshot` | String | none | |
| `appliedMigrations` | String array | none | From `info -migrationIds`. |
| `changesSource` | String | `migrations` | `migrations` or `schemaModel`. |
| `failOnDrift` | Boolean | `false` | Error code `CHECK_DRIFT_DETECTED`. |
| `generateDriftResolutionScripts` | Boolean | `true` | |
| `driftResolutionFolder` (12.9+) | String | `drift-resolution` | Contents replaced each run. |
| `filterFile` | String | named filter files auto-detected | Backwards compat; prefer `[redgateCompare]`. |
| `generateReport` (12.0.2+) | Boolean | `true` | |
| `scope` | String | pending if URL given, else all | `DEFAULT`, `ALL`, `PENDING`, `SCRIPT`. |
| `scriptFilename` | String | `prepare.scriptFilename` | For `scope = SCRIPT`. |
| `rulesLocation` / `rulesConfig` / `rulesDialect` | String | install `rules` / `conf/sqlfluff.cfg` / auto | Code review. |
| `regexEnabled` / `sqlfluffEnabled` | Boolean | `true` / `true` | |
| `sqlfluffCustomRulesPath` (12.7+) | String | none | Page title says "Custom Rules Location"; key shown is `sqlfluffCustomRulesPath`. |
| `code.failOnError` | Boolean | `false` | `[flyway.check.code] failOnError`. |
| `code.noqaSeverity` (12.2+) | String | `WARNING` | `DISABLED`, `WARNING`, `ERROR`. |
| `code.profiles` (13.6+) | Table of string arrays | empty | `[flyway.check.code.profiles] preCommit = ["layout"]`. Built-in `schemaModel` profile. |
| `code.profile` (13.6+) | String | none | Normally passed per run on CLI. |

### deploy, prepare, snapshot, migrate, generate, diff

| Name | Namespace | Type | Default | Notes |
|---|---|---|---|---|
| `scriptFilename` | flyway.deploy | String | `prepare.scriptFilename` | |
| `saveSnapshot` | flyway.deploy / flyway.migrate | Boolean | `false` | Usually CLI; TOML applies to all envs. `undo -saveSnapshot` also exists. |
| `source` | flyway.prepare | String | none | env id, `schemaModel`, `migrations` (`env:` prefix to disambiguate). |
| `target` | flyway.prepare | String | `environment` when source is schemaModel/migrations | |
| `scriptFilename` / `undoFilename` | flyway.prepare | String | `deployments/D__deployment.sql` / `deployments/DU__undo.sql` | |
| `types` | flyway.prepare | String array | `["deploy"]` | `deploy`, `undo`. |
| `abortOnWarningSeverity` | flyway.prepare | String | `None` | `None`, `High`, `Medium`, `Low`. |
| `force` / `artifactFilename` / `changes` | flyway.prepare | | `false` / diff artifact / all | |
| `filename` | flyway.snapshot | String | required for `snapshot` | File path or `snapshotHistory:<name>`. |
| `source` | flyway.snapshot | String | current `environment` | env, `empty`, `schemaModel`, `migrations`. |
| `historyTable` / `historyLimit` | flyway.snapshot | String / Integer | `flyway_snapshot_history` / `5` | |
| `buildEnvironment` / `buildVersion` / `buildCherryPick` / `rebuild` | flyway.snapshot, flyway.diff | | none / none / `[]` / `false` | When source is `migrations`. |
| `types` | flyway.generate | String array | `["versioned"]` | `versioned`, `undo`, `baseline` (baseline cannot combine). |
| `location`, `description`, `version`, `force`, `timestamp` (`auto`), `usePlaceholders` (`false`) | flyway.generate | | | Mostly CLI. |
| `source` / `target` | flyway.diff | String | required | env, `empty`, `schemaModel`, `migrations`, `snapshot:<path>`, `snapshotHistory:<name>`. |
| `artifactFilename` | flyway.diff | String | `%temp%/flyway.artifact.diff` | |
| `includeFlywayObjects` | flyway.diff | Boolean | `false` | |
| `schemaModelLocation` | flyway | String | `schema-model` in working dir | |
| `schemaModelSchemas` | flyway | String array | matches other side | Map schemas when source/target differ. |

### Database namespaces

| Name | Namespace | Type | Default | Edition |
|---|---|---|---|---|
| `sqlplus` / `sqlplusWarn` | flyway.oracle | Boolean | `false` | Teams |
| `walletLocation` | flyway.oracle | String | none | Teams. Not supported for comparison features (diff, check, prepare, snapshot, Desktop). |
| `kerberosCacheFile` | flyway.oracle | String | none | Teams |
| `checksumIncludeReferencedScripts` (12.4+) | flyway.oracle (per release notes) | unverified | unverified | No reference page found; confirm before use. |
| `kerberos.login.file` | flyway.sqlserver | String | none | Teams. Path to `SQLJDBCDriver.conf`. Also set `kerberosConfigFile`. |
| `mode` | flyway.sqlserver.clean | String | `default` | `default`, `schema`, `all` |
| `schemas.exclude` | flyway.sqlserver.clean | String array | `[]` | With `mode = "all"` |
| `transactional.lock` | flyway.postgresql | Boolean | `true` | Set `false` for `CREATE INDEX CONCURRENTLY` |
| `clusterName`, `zookeeperPath` | flyway.clickhouse | String | none | |
| `databaseName`, `sqlId` | flyway.db2z | String | none | |

No `flyway.mysql` engine namespace is documented. MySQL settings exist only under `[redgateCompare.mysql]` (comparison options).

### Provisioners (`provisioner = "..."` in `[environments.X]`, Enterprise)

| Provisioner | Config table | Keys | Notes |
|---|---|---|---|
| `clean` | none | | Re-provision only, via clean. Desktop default for shadow. |
| `create-database` (preview) | `[environments.X.resolvers.create-database]` | `reprovisionMethod` = `CLEAN` (default), `DROP`, `NONE` | SQL Server, MySQL, PostgreSQL. DB name from URL. |
| `backup` (preview) | `[environments.X.resolvers.backup]` | `backupFilePath` (required, server-side path), `backupVersion`; SQL Server `sqlserver.generateWithMove` (default true), `[[...backup.sqlserver.files]]` `logicalName`/`filePath`; Oracle `connectionIdentifier` (required), `importContent` (`METADATA_ONLY` default, `ALL`), `parFilePath` | SQL Server `.bak`, Oracle Data Pump `.dmp` (needs `impdp`). More Oracle keys on the page. |
| `snapshot` (preview) | `[environments.X.resolvers.snapshot]` | `filename`, `snapshotVersion` (required), `cleanOnReprovision` | Schema only. |
| `docker` (preview, 12.10+) | `[environments.X.resolvers.docker]` | `sourceEnvironment`, `databaseEngine` + `databaseEngineVersion`, `waitTimeout` (`2m`), `keepAlive` (`true`), `iAgreeToTheDBVendorsEula` (required `true` for SQL Server/Oracle) | Do **not** set `url`/`user`/`password` (error 13.6+). |
| `docker-compose` (preview) | `[environments.X.resolvers.docker-compose]` | `composeFile`, `services`, `waitTimeout` (all required) | Formerly `docker`. |

### Desktop and comparison (`[flywayDesktop]`, `[redgateCompare]`)

| Name | Namespace | Type | Default | Notes |
|---|---|---|---|---|
| `developmentEnvironment` / `shadowEnvironment` | flywayDesktop | String | `development` / `shadow` | Use `developmentEnvironment` / `shadowEnvironment`: Desktop writes these, Redgate sample projects use them and the MCP docs require them. The namespace reference pages still show `development` / `shadow` (out of step; whether Desktop accepts them is unverified). See `common-architectures.md`. |
| `showDeploymentDecision` | flywayDesktop | Boolean | `false` (true for new projects) | |
| `schemaModel` | flywayDesktop | String | `schema-model` | Deprecated; use `[flyway] schemaModelLocation`. |
| `undoScripts` | flywayDesktop.generate | Boolean | `false` | Desktop only. |
| `repeatableTypes` | flywayDesktop.generate | String array | `[]` | |
| `filterFile` | redgateCompare | String | `filter.rgf` | Not for SQL Server/Oracle. |
| `filterFile` | redgateCompare.sqlserver / redgateCompare.oracle | String | `Filter.scpf` | Oracle filters apply after comparison; ignore rules pre-filter. `init` no longer writes the root `redgateCompare.filterFile` for SQL Server and Oracle projects (Flyway 13.9.0). |
| `staticDataTables` | redgateCompare | Object array | `[]` | `[[redgateCompare.staticDataTables]]` `table`, `schema` (Teams), `excludedColumns`, `whereClause` (SQL Server) (Enterprise). PK required. |
| Behaviour/ignore/data options | `redgateCompare.<db>.options.behavior`, `.options.ignores`, `redgateCompare.sqlserver.data.options.{mapping,comparison,deployment}` | Boolean | mostly `false` | e.g. `addObjectExistenceChecks`, `addOnlineOnWhenCreatingIndexesOrAlteringColumns`, Oracle `includeOnlineIndexCreation` (13.0+), Oracle `preserveIdentifierCase` (Preview, Flyway 13.9.0), PostgreSQL `disableConstraintsForStaticData` (12.11+). One page per option. |

Comparison options, filters and static data can only be set in TOML, not overridden on the CLI (prepare docs).

## Annotated example

```toml
# Root keys (normally written by `flyway init` or Flyway Desktop; do not hand-edit id)
databaseType = "SqlServer"
name = "Inventory"

[flyway]
environment = "test"                           # default target; override with -environment=prod
locations = ["filesystem:migrations"]
callbackLocations = ["filesystem:callbacks"]   # afterConnect.sql etc. live here
defaultSchema = "dbo"
validateMigrationNaming = true                 # fail on badly named scripts
validateOnMigrate = true                       # default, shown for clarity
cleanDisabled = true                           # default; only relaxed per env below
schemaModelLocation = "schema-model"
email = "${env.FLYWAY_EMAIL}"                  # PAT licensing (service account)
token = "${env.FLYWAY_TOKEN}"

[flyway.placeholders]
appUser = "inventory_app"                      # used as ${appUser} in scripts

[flyway.check]
buildEnvironment = "build"                     # used by check -changes / -drift
failOnDrift = true
driftResolutionFolder = "drift-resolution"     # 12.9+

# Build DB for check/diff: reset between runs
[environments.build]
url = "jdbc:sqlserver://ci-sql:1433;databaseName=Inventory_Build;encrypt=true;trustServerCertificate=true"
user = "${env.BUILD_DB_USER}"
password = "${env.BUILD_DB_PASSWORD}"
provisioner = "clean"                          # Enterprise; alternatively cleanDisabled=false below

[environments.build.flyway]
cleanDisabled = false                          # safe: disposable database

[environments.test]
url = "jdbc:sqlserver://test-sql:1433;databaseName=Inventory;encrypt=true;trustServerCertificate=true"
user = "${env.TEST_DB_USER}"
password = "${env.TEST_DB_PASSWORD}"
displayName = "Test"

[environments.prod]
url = "jdbc:sqlserver://prod-sql:1433;databaseName=Inventory;encrypt=true"
user = "${env.PROD_DB_USER}"
password = "${env.PROD_DB_PASSWORD}"
displayName = "Production"

[environments.prod.flyway]
outOfOrder = false                             # per-env override of a [flyway] setting
```

Key Vault variant for prod password (Enterprise, 12.5+):

```toml
[environments.prod]
password = "${azureKeyVault.prod-db-password}"

[environments.prod.resolvers.azureKeyVault]
vaultUrl = "https://my-vault.vault.azure.net"
```

## Sources

- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace (and each linked `.../flyway-namespace/<setting>` page)
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace (and linked setting pages)
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-flyway-namespace
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-jdbc-properties-namespace
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-resolvers-namespace
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting/clean-provisioner
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-provisioner-setting/create-database-provisioner
- https://documentation.red-gate.com/fd/backup-provisioner-277578935.html
- https://documentation.red-gate.com/fd/snapshot-provisioner-277578940.html
- https://documentation.red-gate.com/fd/docker-provisioner-277578938.html
- https://documentation.red-gate.com/fd/docker-compose-provisioner-346163424.html
- https://documentation.red-gate.com/fd/azure-key-vault-resolver-342851662.html
- https://documentation.red-gate.com/fd/environment-variable-resolver-277578943.html
- https://documentation.red-gate.com/fd/local-secret-resolver-277578947.html
- https://documentation.red-gate.com/fd/git-resolver-277578944.html
- https://documentation.red-gate.com/fd/local-db-resolver-277578946.html
- https://documentation.red-gate.com/fd/placeholder-resolver-284066385.html
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-resolvers-namespace/vault-resolver
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-resolvers-namespace/dapr-resolver
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-resolvers-namespace/google-cloud-secret-manager-resolver
- https://documentation.red-gate.com/fd/reference/configuration/environments-namespace/environment-resolvers-namespace/microsoft-entra-interactive-resolver
- https://documentation.red-gate.com/fd/flyway-check-drift-resolution-folder-setting-346162210.html (and sibling `flyway-check-*` pages)
- https://documentation.red-gate.com/fd/flyway-offline-permit-path-setting-314869837.html
- https://documentation.red-gate.com/fd/reference/configuration/flyway-desktop-namespace
- https://documentation.red-gate.com/fd/reference/configuration/redgate-compare-namespace (and linked option pages)
- https://documentation.red-gate.com/fd/reference/configuration-precedence
- https://documentation.red-gate.com/fd/flyway-projects-271585108.html
- https://documentation.red-gate.com/flyway/flyway-concepts/flyway-projects/configuration-namespaces
- https://documentation.red-gate.com/fd/reference/callback-events
- https://documentation.red-gate.com/fd/reference/commands/init
- https://documentation.red-gate.com/fd/reference/commands/prepare
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/lakebase-resolver-370507868.html
- https://documentation.red-gate.com/fd/databricks-resolver-370509043.html
- https://documentation.red-gate.com/x/iIWLE (Oracle behavior options)

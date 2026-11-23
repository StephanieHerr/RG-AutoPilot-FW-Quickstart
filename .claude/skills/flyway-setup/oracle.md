# Oracle notes for the setup

Read this alongside `SKILL.md` when the user is on Oracle. The flow is the same; the baseline is a Data Pump dump instead of a `.bak`. The library in `Documentation/FlywayAIDump/` covers SQL Server only. For Oracle, rely on these Redgate pages and say plainly when something isn't covered:
- POC checklist: https://documentation.red-gate.com/fd/poc-checklist-317493040.html
- Data Pump dump as baseline (**preview**): https://documentation.red-gate.com/flyway/learn-more-about-flyway/how-to-articles/use-an-oracle-data-pump-export-dump-file-to-baseline-a-database

## Databases (SKILL.md steps 3 and 5)

Redgate recommends one pluggable database (PDB) per environment, each holding the same schema: `<NAME>_DEV`, `_TEST`, `_PROD`, `_SHADOW`, `_CHECK` and `_BUILD`.
- Creating PDBs needs a DBA, or an instance they own; Oracle Database Free works for a local sandbox.
- Start with one schema. The user that connects to Dev must own that schema.
- Shadow, Check and Build stay empty, but the schema user must exist in each.

## Bring in their database with Data Pump (they run it; SKILL.md step 4)

They need `expdp` and `impdp` on the machine they run them from (Oracle Instant Client Tools; see "Install Oracle Data Pump Tools" on the page above). Leave the password out of the command so Data Pump prompts for it. Never put it in a file.

1. In each PDB, create a directory object for the same folder on the database server, and grant access to it:
   ```sql
   CREATE DIRECTORY FLYWAY_DUMP AS '<folder on the database server>';
   GRANT READ, WRITE ON DIRECTORY FLYWAY_DUMP TO <user>;
   ```
2. Get a dump of their schema into that folder:
   - **Export it now, structure only** (`CONTENT=METADATA_ONLY` means no table rows):
     ```
     expdp <user>@//<host>:<port>/<source service> SCHEMAS=<SCHEMA> DIRECTORY=FLYWAY_DUMP DUMPFILE=flyway_baseline.dmp CONTENT=METADATA_ONLY
     ```
   - **Or use a dump file they already have:** they copy it into the folder, and you use its file name below.
3. Import the structure into Dev, Test and Prod, so all three start identical. `CONTENT=METADATA_ONLY` leaves any rows behind, even from a full dump:
   ```
   impdp <user>@//<host>:<port>/<NAME>_DEV SCHEMAS=<SCHEMA> DIRECTORY=FLYWAY_DUMP DUMPFILE=flyway_baseline.dmp CONTENT=METADATA_ONLY
   ```
   Repeat for `_TEST` and `_PROD`.

## flyway.toml for Oracle (SKILL.md step 5)

The shipped `flyway.toml` is for SQL Server. With the user's agreement, replace everything above the environments section with this. Keep the existing `id`, and drop the `[flyway.sqlserver…]` and `[redgateCompare.sqlserver…]` sections:
```toml
databaseType = "Oracle"
id = "<keep the existing id>"
name = "Flyway Setup Sandbox"

[flyway]
locations = [ "filesystem:migrations" ]
mixed = true
outOfOrder = false
schemaModelLocation = "schema-model"
schemas = [ "<SCHEMA>" ]
validateMigrationNaming = true

  [flyway.check]
  buildEnvironment = "Check"

[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"

  [flywayDesktop.generate]
  undoScripts = true

[redgateCompare]
filterFile = "filter.rgf"
```

Environment URLs: `jdbc:oracle:thin:@//<host>:<port>/<NAME>_DEV`, and so on. Oracle logins always go through Flyway Desktop (`SKILL.md` step 5).

Add this to each of shadow, Check and Build, with their own variable name:
```toml
provisioner = "backup"

  [environments.shadow.resolvers.backup]
  backupFilePath = "FLYWAY_DUMP:flyway_baseline.dmp"
  backupVersion = "001"
  oracle.connectionIdentifier = "${env.FLYWAY_SHADOW_CONNECT}"
  oracle.importContent = "METADATA_ONLY"
```
- The connection identifier carries a password (`user/password@host:port/<NAME>_SHADOW`, or an Oracle Wallet alias). So the user sets `FLYWAY_SHADOW_CONNECT`, `FLYWAY_CHECK_CONNECT` and `FLYWAY_BUILD_CONNECT` as environment variables themselves, and it never goes in a file.
- Per Redgate's page, the importing user also needs `IMP_FULL_DATABASE` and read/write on `FLYWAY_DUMP`.
- Not from Redgate docs: using `${env.…}` here. `SKILL.md` step 7 (`flyway info -environment=shadow`) confirms it works.

## Differences in the later steps

- No `Filter.scpf`: to leave objects out, use Flyway Desktop's filter, which writes `filter.rgf`.
- `Rules/` and `sqlfluff.cfg` are T-SQL rules. Leave `-code` out of the `check` commands unless their SE has set up Oracle rules.
- If they try the drift check from the POC workflow, the manual change is an `ALTER TABLE … ADD` run in SQL Developer or SQL*Plus.
- If Data Pump isn't available to them, use the baseline-script fallback at the end of `SKILL.md`, with `provisioner = "clean"` on shadow, Check and Build.
- **Pipeline:** remove `-code` from the check command. Add `TARGET_DATABASE_USERNAME` and `TARGET_DATABASE_PASSWORD` as secrets, and `FLYWAY_CHECK_CONNECT` too, passed to the check step as an environment variable, so Data Pump can restore Check.

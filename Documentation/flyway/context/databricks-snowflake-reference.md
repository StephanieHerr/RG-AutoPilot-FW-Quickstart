<!-- last-verified: 2026-10-19 | refreshed-by: weekly refresh routine -->

# Databricks and Snowflake reference for Flyway (demo prep)

Both platforms have foundational (migrations) support plus **advanced capabilities in public preview**. Preview features change fast: re-check the preview pages before every customer demo. Version tags are Flyway engine (CLI) or Flyway Desktop (FD) versions.

## At a glance

| | Databricks Lakehouse (Unity Catalog) | Databricks Lakebase | Snowflake | Snowflake Postgres |
|---|---|---|---|---|
| Foundational (migrate, info, validate, repair, baseline; undo Teams+) | Supported | Supported | Supported | Supported |
| Advanced (schema model, generate, change report, drift) | Preview, Enterprise | Preview, Enterprise | Preview, Enterprise | Preview, Enterprise |
| Advanced model | Redgate model for Lakehouse objects (list below) | "Aligns with" PostgreSQL advanced capabilities | Redgate model for Snowflake objects (list below) | "Aligns with" PostgreSQL advanced capabilities |
| Driver | Databricks JDBC (`com.databricks:databricks-jdbc`, ships with CLI) | PostgreSQL JDBC | Snowflake JDBC (`net.snowflake:snowflake-jdbc` 4.0.2+, ships with CLI) | PostgreSQL JDBC |
| Native Connectors | No (JDBC) | No | No (JDBC) | No |
| Engine recognition | Long-standing | PostgreSQL derivative, public preview (13.1) | Long-standing | PostgreSQL derivative (13.6) |
| Snapshot history (embedded snapshots for drift/rollback) | 13.1+ | Via PostgreSQL support (unverified specifically) | 13.8+ | Via PostgreSQL support (unverified specifically) |
| Flyway Desktop | Advanced preview FD 9.6.0; renamed "Databricks Lakehouse (Unity Catalog)" FD 9.6.3; dedicated hostname/port/HTTP path/catalog fields FD 9.8.4 | Distinct project type FD 9.6.3; filter editor FD 9.8.1 | Advanced preview FD 9.9.0 | Distinct project type FD 9.8.4 |
| Preview toggle | On by default. FD: Settings > Preview features > Databricks | same | On by default. FD: Settings > Preview features > Snowflake | same |

The Databricks preview page says "Make sure you're on Flyway Desktop v9.9.0 or later" for connecting. Use current Desktop and CLI for demos.

Advanced capabilities listed for both preview pages: understand changes made to a dev schema; script them out per object (object-level history in Git); optionally generate versioned and undo migrations accounting for dependencies; change reports in CI/CD with side-by-side diff; drift checks. State-based `prepare`/`deploy` is described as "the same state and migrations workflows you already use".

---

## Databricks Lakehouse (Unity Catalog)

### Objects covered (preview)
- Schemas: comment, owner, default collation, `DBPROPERTIES`, tags, predictive-optimization setting
- Tables: including partitioning, and table rebuilds where a change cannot be made in place
- Columns: data types, `NOT NULL`, `DEFAULT`, `GENERATED` / identity
- Views, stored procedures
- Primary keys, foreign keys, check constraints
- Comments at schema, view and column level
- Risky change warnings before deploy: adding `NOT NULL` without a default; rebuilding a table with an identity column (IDs regenerated)

### Limitations
- Unity Catalog only; legacy `hive_metastore` not supported
- DELTA managed tables only: no external, non-managed or non-DELTA tables
- Not yet: functions, materialized views, streaming tables, volumes, foreign tables, shallow clones
- Unmodelled properties of supported objects (for example row filters, column masks) are ignored, not captured or deployed

### Connection and auth

| Method | URL properties | Source |
|---|---|---|
| Personal access token | `AuthMech=3;UID=token;PWD=<token>` | Flyway driver page and Databricks docs |
| OAuth M2M (service principal) | `AuthMech=11;Auth_Flow=1;OAuth2ClientId=<app-id>;OAuth2Secret=<secret>` | Databricks JDBC docs; Flyway page says "Personal access token or OAuth token" without detail (unverified end to end) |
| OAuth token pass-through | `AuthMech=11;Auth_Flow=0;Auth_AccessToken=<token>` | Databricks JDBC docs (unverified with Flyway) |
| Browser-based OAuth (interactive) | `AuthMech=11;Auth_Flow=2` plus `[environments.X.jdbcProperties] TokenCachePassPhrase = "${databricks.tokenCachePassPhrase}"` | Flyway Databricks resolver page; resolver shipped in Flyway 13.10.1. The resolver generates a per-user passphrase, stores it in the OS secret store and the driver reuses the cached sign-in. Interactive, so for dev machines and demos, not CI. Desktop: choose 'OAuth Interactive Sign-In' from the Authentication dropdown in the connection dialog (FD 9.10.6) |

- Flyway URL format: `jdbc:databricks://host:port/default;transportMode=http;ssl=1;httpPath=path;EnableArrow=0;AuthMech=3;UID=token;PWD=personal-access-token`.
- `EnableArrow=0` (or JVM `--add-opens java.base/java.lang=ALL-UNNAMED`) is required on Java 16+ or the driver throws a formatting error.
- Default catalog: Databricks property `ConnCatalog` (driver default is `SPARK`). Desktop has a catalog field; the TOML key Desktop writes is (unverified), so this doc uses the URL property.
- Flyway identifies itself via `UserAgentEntry` as `Redgate_Flyway` (13.8+): useful for workspace audit/query history filters.
- Flyway no longer modifies the `jdbcProperties` passed to it for Databricks connections, or fails when they are immutable (fixed Flyway 13.10.1).
- Secrets: the env var resolver works inside the URL string (12.6.2+). Flyway prints the connection URL at startup; check whether `PWD=` values are masked in your logs before recording a demo (unverified).

### Minimal flyway.toml (Lakehouse)
```toml
databaseType = "Databricks"          # Desktop-only field; let Desktop write the exact value (unverified)
id = "0d5c3a2e-7f41-4d0b-9a55-3b8e2c1f9a01"
name = "LakehouseDemo"

[flyway]
locations = ["filesystem:migrations"]
schemaModelLocation = "schema-model"
cleanDisabled = true

[environments.dev]
url = "jdbc:databricks://adb-1234567890123456.7.azuredatabricks.net:443/default;transportMode=http;ssl=1;httpPath=/sql/1.0/warehouses/abc123def456;EnableArrow=0;ConnCatalog=demo_dev;AuthMech=3;UID=token;PWD=${env.DATABRICKS_TOKEN}"
schemas = ["sales"]

[environments.prod]
url = "jdbc:databricks://adb-1234567890123456.7.azuredatabricks.net:443/default;transportMode=http;ssl=1;httpPath=/sql/1.0/warehouses/abc123def456;EnableArrow=0;ConnCatalog=demo_prod;AuthMech=3;UID=token;PWD=${env.DATABRICKS_TOKEN}"
schemas = ["sales"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```

### Fixed issues worth knowing
- Identifiers containing a backtick produced invalid SQL (fixed 13.1)
- Migrations could fail at unlock with Delta `ConcurrentAppendException` (fixed 13.1)
- Dry run failed with "Unable to switch connection to read-only" (fixed 13.1)
- databricks-jdbc upgraded to 3.4.2 (13.7)

---

## Databricks Lakebase (PostgreSQL)

- Create a Desktop project of type **Databricks Lakebase (PostgreSQL)**. Advanced behaviour follows Flyway's PostgreSQL support (see postgres-reference.md), including the PostgreSQL filter editor (FD 9.8.1).
- Get the connection string from Lakebase with the connection type set to **Java**.
- Auth (Databricks docs): OAuth-derived database credentials expire after 60 minutes (checked at login only), or native Postgres roles with passwords that do not expire hourly. For pipelines and demos, a native Postgres role is simpler; for OAuth you need a step that mints a fresh credential before each Flyway run.
- Database name in Databricks examples: `databricks_postgres`; port 5432.
- `lakebase` resolver (Flyway 13.10.0): interactive Databricks sign-in that fetches a fresh database credential on every connect, so no secret is stored. Set `user = "${lakebase.user}"` (the Postgres role for the signed-in identity, which is the user's email) and `password = "${lakebase.token}"`, with `[environments.X.resolvers.lakebase]` `workspaceUrl` and `project` (required) and optional `branch` / `compute` (default `production` / `primary`) and `redirectUri`. Opens a browser and the Databricks SDK caches the token. The docs say it is not suitable for automation: use it for dev and demos, and a native Postgres role in pipelines.
- Flyway Desktop: Lakebase connections can sign in to Databricks interactively through the browser (FD 9.10.6).

### Minimal flyway.toml (Lakebase)
```toml
databaseType = "PostgreSql"          # Desktop-only field; Desktop may write a Lakebase-specific value (unverified)
id = "5b7e9d10-2c3f-4a6e-8b1d-7f0a9c4e2d33"
name = "LakebaseDemo"

[flyway]
locations = ["filesystem:migrations"]
schemaModelLocation = "schema-model"
cleanDisabled = true

[environments.dev]
url = "jdbc:postgresql://instance-abc123.database.cloud.databricks.com:5432/databricks_postgres?sslmode=require"
user = "${env.LAKEBASE_USER}"
password = "${env.LAKEBASE_PASSWORD}"
schemas = ["app"]
[environments.dev.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```
Hostname pattern above is illustrative; copy the real host from the Lakebase Java connection string.

---

## Snowflake

### Objects covered (preview)
- Schemas (create and drop only)
- Tables and columns: basic data types, `NOT NULL`; add, drop, retype, nullability switch
- Views (dependency-aware creation order)
- Functions and stored procedures: SQL-language bodies, scalar returns, parameter defaults; overloads treated as distinct objects
- Views, functions and procedures deployed with `CREATE OR REPLACE`

### Behaviour to call out
- Where Snowflake cannot alter a column type in place (narrowing `VARCHAR`, changing `NUMBER` scale either way) Flyway **drops and recreates the column: data in that column is lost**.
- Deployment scripts are **not** currently checked for risky changes (no warning on dropped tables/columns). Review scripts.
- No transactions: Snowflake commits before DDL and DDL cannot roll back. Desktop hides "run in a transaction" for Snowflake. A failed deploy leaves earlier statements applied.
- `CREATE OR REPLACE VIEW` does not preserve grants.

### Limitations (preview)
- Not yet: constraints (PK/FK/check), streams, tasks, sequences, materialized views, Iceberg/Hybrid/External/Dynamic/temporary/transient tables
- SQL-language routines only (no JavaScript, Python, Java, Scala; no table-returning routines)
- No static data comparison, grants, masking or row access policies
- No comments, tags, owners, `CLUSTER BY`, column defaults, computed columns; renames deploy as drop + create
- Unmodelled properties are lost if an object is recreated (for example `CLUSTER BY`)
- Parallel migrations are unavailable on Snowflake (foundational limitation)

### Connection and auth

| Method | How | Source |
|---|---|---|
| Username/password (+MFA) | Add `authenticator=username_password_mfa`; enable `ALLOW_CLIENT_MFA_CACHING` on the account to reduce prompts | Flyway Snowflake preview page |
| Programmatic access token (PAT) | Put the PAT in the password field; URL unchanged. Good for MFA-enforced accounts | Flyway Snowflake preview page |
| Key-pair | `authenticator=snowflake_jwt&private_key_file=<absolute path to .pem>`; public key assigned with `ALTER USER`. Encrypted keys may need `JAVA_OPTS='-Dnet.snowflake.jdbc.useBundledBouncyCastleForPrivateKeyDecryption=true'` | Flyway Snowflake driver page |
| OAuth | Snowflake JDBC supports `authenticator=oauth` with a token | Snowflake docs only (unverified with Flyway) |

- URL: `jdbc:snowflake://<account>.snowflakecomputing.com/?db=<db>&warehouse=<wh>&schema=<schema>&role=<role>&JDBC_QUERY_RESULT_FORMAT=JSON`.
- For advanced capabilities the URL **must** include `db`, `warehouse` and `schema` (Flyway takes database and compute context from the URL). `role` optional.
- `JDBC_QUERY_RESULT_FORMAT=JSON`: from Flyway 13.10.1, when Flyway creates the connection from a JDBC URL it always sets `JDBC_QUERY_RESULT_FORMAT=JSON` (any other value you set is ignored), so Java 16+ connections no longer fail without it. Keeping it in the URL is harmless. Before 13.10.1, add it (or the `--add-opens` JVM flag) to avoid a Java 16+ error. If you pass Flyway your own DataSource (for example Spring Boot), set it on the DataSource yourself.
- Flyway sets `application=Redgate_Flyway` on Snowflake connections unless you set `application` yourself (Flyway 13.10.1): useful for Snowflake query history filters.
- Flyway Desktop strips surrounding double quotes from JDBC URLs pasted into connection dialogs, such as those copied from the Snowflake website (FD 9.10.5).
- Default schema is `PUBLIC`; if it does not exist, set the schema explicitly (connectivity failure when PUBLIC is missing fixed in 12.4).
- Driver class is `net.snowflake.client.api.driver.SnowflakeDriver`; older drivers using the legacy class could not connect (fixed 13.7).
- Parser fixes: nested `IF` (12.0), `AGENT IF EXISTS` (13.4).

### Minimal flyway.toml (Snowflake, key-pair)
```toml
databaseType = "Snowflake"           # Desktop-only field; let Desktop write the exact value (unverified)
id = "9c1f4b7a-3e2d-4c88-a6f0-1d5e7b2a8c44"
name = "SnowflakeDemo"

[flyway]
locations = ["filesystem:migrations"]
schemaModelLocation = "schema-model"
cleanDisabled = true

[environments.dev]
url = "jdbc:snowflake://myorg-myaccount.snowflakecomputing.com/?db=DEMO_DEV&warehouse=DEMO_WH&schema=SALES&role=FLYWAY_DEV&JDBC_QUERY_RESULT_FORMAT=JSON&authenticator=snowflake_jwt&private_key_file=${env.SNOWFLAKE_KEY_PATH}"
user = "${env.SNOWFLAKE_USER}"
schemas = ["SALES"]

[environments.prod]
url = "jdbc:snowflake://myorg-myaccount.snowflakecomputing.com/?db=DEMO_PROD&warehouse=DEMO_WH&schema=SALES&role=FLYWAY_DEPLOY&JDBC_QUERY_RESULT_FORMAT=JSON&authenticator=snowflake_jwt&private_key_file=${env.SNOWFLAKE_KEY_PATH}"
user = "${env.SNOWFLAKE_USER}"
schemas = ["SALES"]
[environments.prod.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```
If the CLI prompts for a password in an interactive terminal when `password` is omitted, add `&user=...` to the URL and drop the TOML `user`, or run non-interactively (prompt behaviour not documented for these drivers; unverified). For PAT instead of key-pair: drop the two `authenticator`/`private_key_file` parameters and add `password = "${env.SNOWFLAKE_PAT}"`.

---

## Snowflake Postgres

- Recognised as a PostgreSQL derivative (13.6); Desktop project type **Snowflake Postgres** (FD 9.8.4). Advanced behaviour aligns with PostgreSQL support.
- Desktop flow: new project > Snowflake Postgres > Schema model > Start here > paste the **Host name** from the Snowflake Postgres account, then database, schemas, username, password > optional filters and static data > Finish.

### Minimal flyway.toml (Snowflake Postgres)
```toml
databaseType = "PostgreSql"          # Desktop-only field; Desktop may write a Snowflake Postgres value (unverified)
id = "2e8a6c4d-9b1f-4f37-8c02-6a3d5e9b1f55"
name = "SnowflakePostgresDemo"

[flyway]
locations = ["filesystem:migrations"]
schemaModelLocation = "schema-model"
cleanDisabled = true

[environments.dev]
url = "jdbc:postgresql://<host-from-snowflake-postgres-account>:5432/postgres?sslmode=require"
user = "${env.SFPG_USER}"
password = "${env.SFPG_PASSWORD}"
schemas = ["app"]
[environments.dev.flyway]
cleanDisabled = true
outOfOrder = false
validateOnMigrate = true
```
Replace the host placeholder with the account's host name. Database name `postgres` and `sslmode=require` are assumptions (unverified): copy what the account's connection details show.

---

## What works where (summary for customer questions)

| Capability | Lakehouse | Lakebase | Snowflake | Snowflake Postgres |
|---|---|---|---|---|
| `migrate` versioned/repeatable | Yes | Yes | Yes | Yes |
| Schema model capture (Desktop) | Preview | Preview | Preview | Preview |
| `generate` versioned + undo | Preview | Preview | Preview | Preview |
| `prepare` / `deploy` (state-based) | Preview (stated generally) | Preview | Preview (stated generally) | Preview |
| `check -changes` report | Preview | Preview | Preview | Preview |
| `check -drift` | Preview | Preview | Preview | Preview |
| Embedded snapshots | 13.1+ | (unverified) | 13.8+ | (unverified) |
| Transactions around DDL | Not stated for Lakehouse (unverified) | PostgreSQL rules | No | PostgreSQL rules |
| Risky-change warnings | Yes (two cases) | PostgreSQL rules | No | PostgreSQL rules |
| Static data | Not stated (unverified) | PostgreSQL rules | No | PostgreSQL rules |

---

## Demo tips

**Set up before the call**
- Separate dev and "prod" catalogs/databases so drift and change reports have somewhere to point. For Databricks use a small SQL warehouse; for Snowflake an XS warehouse with auto-suspend.
- Snowflake: use key-pair or PAT so MFA prompts do not interrupt the demo. Lakebase: use a native Postgres role, not an hourly OAuth credential.
- Run `flyway testConnection -environment=dev` first; it checks both the Flyway engine and comparison engine connections.
- Keep demo objects inside the supported lists. Avoid Snowflake sequences, constraints, streams/tasks, and Databricks functions/matviews/volumes: they will be silently ignored, which looks like a bug on screen.

**Story to show (about 10 minutes)**
1. Desktop: create project, link dev, capture the schema model. Show one file per object in Git.
2. Make a change in the dev database (add a column, change a view). Refresh, save to the schema model, commit. Show object-level history (Enterprise, on by default since FD 9.8.3; GA in FD 9.10.7).
3. Generate a versioned migration plus undo script from the model.
4. CLI or pipeline: `flyway check -changes` (report with side-by-side diff), then `flyway migrate -environment=prod -saveSnapshot=true`.
5. Make an out-of-band change in prod, run `flyway check -drift -environment=prod`, open the drift report.
6. Databricks only: trigger a risky change warning (add a `NOT NULL` column with no default) to show guardrails.

**Honest talking points**
- "Preview" means Enterprise feature, on by default, not feature-complete; feedback shapes the roadmap (survey/email links on the preview pages).
- Snowflake: explain the column drop/recreate case and the lack of risky-change checks before someone finds it.
- Databricks: Unity Catalog and DELTA managed tables only.
- Redgate has a Databricks end-to-end Storylane walkthrough linked from the preview page: https://redgate.storylane.io/share/i2lbpyd81aob

## Sources
- https://documentation.red-gate.com/flyway/getting-started-with-flyway/system-requirements/supported-databases-and-versions
- https://documentation.red-gate.com/flyway/learn-more-about-flyway/preview-components/advanced-capabilities-for-databricks
- https://documentation.red-gate.com/x/hwAjFQ (Advanced capabilities for Snowflake)
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/databricks
- https://documentation.red-gate.com/flyway/reference/database-driver-reference/snowflake
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/x/AwWoEw (Flyway Desktop 9 release notes)
- https://documentation.red-gate.com/x/v4SLE (Environment variable resolver)
- https://documentation.red-gate.com/x/QQArEw (Test Connection)
- https://docs.databricks.com/aws/en/integrations/jdbc-oss/authentication
- https://docs.databricks.com/aws/en/integrations/jdbc-oss/properties
- https://docs.databricks.com/aws/en/oltp/projects/postgres-clients
- https://learn.microsoft.com/en-us/azure/databricks/oltp/oauth
- https://developers.databricks.com/docs/lakebase/development
- https://documentation.red-gate.com/fd/lakebase-resolver-370507868.html
- https://documentation.red-gate.com/fd/databricks-resolver-370509043.html
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html (object level history GA, 9.10.7)

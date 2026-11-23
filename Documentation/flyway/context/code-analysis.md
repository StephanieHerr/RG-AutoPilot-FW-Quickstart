<!-- last-verified: 2026-09-25 | refreshed-by: initial rebuild -->

# Flyway code analysis (code review)

Scope: `flyway check -code`, the SQLFluff and regex engines, every Redgate RG rule, severity and failure configuration, custom rules, report formats, Desktop code review policies, edition gating. Output text renamed "Code Analysis" to "Code Review" in 12.2.0; docs use both terms.

## 1. Edition gating

| Capability | Community | Enterprise |
|---|---|---|
| `check -code` with your own locally installed SQLFluff | Yes (install Python + SQLFluff yourself) | Yes |
| Bundled "Redgate Bundle" SQLFluff (no Python install) | No | Yes, used by default when licensed and present |
| Redgate SQLFluff rules RG01 to RG23 | No (bundle only) | Yes |
| Regex rules engine | No | Yes |
| Fail the pipeline on Error-level violations (`check.code.failOnError`) | No (setting is Enterprise) | Yes |
| `--noqa` usage reporting (`check.code.noqaSeverity`) | No | Yes |
| Code review profiles (`check.code.profile`, `check.code.profiles`) | No | Yes (13.6+) |
| Custom SQLFluff Python rules (`check.sqlfluffCustomRulesPath`) | Page badge says Teams; requires Redgate Bundle SQLFluff | Yes (12.7+) |
| Desktop code review panel and policies tab | n/a | Desktop 9.2+ (panel, preview), 9.7+ (policies) |

- Force your own SQLFluff install regardless of edition: `FLYWAY_ENV_NATIVE_SQLFLUFF=false`.
- If the bundled engine is missing, Flyway warns and falls back to your own SQLFluff (and no default config is loaded).
- Bundled SQLFluff on Linux needs GLIBC 2.35+ (Ubuntu 22.04+, Debian 12+, RHEL/Rocky/Alma 9.1+). Older distros fail with `version 'GLIBC_2.35' not found`.
- The CLI prints e.g. `SqlFluff version x.y.z (Redgate Bundle)` when the bundle is active.

## 2. Running it

```
flyway check -code
flyway check -code "-check.code.failOnError=true"
flyway check -code -scope=script -scriptFilename="D__deployment.sql" -failOnError=true
```

| Parameter (namespace `check`) | Purpose |
|---|---|
| `rulesLocation` | Folder containing regex rule `.toml` files (honours `workingDirectory`) |
| `rulesConfig` | Path to the SQLFluff config file (for example a project `sqlfluff.cfg`) |
| `rulesDialect` | Explicit SQL dialect. Otherwise derived from the JDBC URL, else ANSI |
| `scope` | `DEFAULT`, `ALL`, `PENDING`, `SCRIPT`. Default: PENDING if a URL is given, else ALL |
| `scriptFilename` | Script to analyse when `scope=SCRIPT` |
| `regexEnabled` / `sqlfluffEnabled` | Turn each engine on or off (11.9+) |
| `code.failOnError` | Fail when any Error-severity violation is found. Default false |
| `code.noqaSeverity` | `DISABLED`, `WARNING` (default), `ERROR` for use of `--noqa` |
| `code.profile` | Name a profile that excludes rules for this run (13.6+) |
| `code.profiles` | Table of profile name to excluded rules/groups (13.6+); entries can also name regex rule codes (Flyway 13.11.0) |
| `sqlfluffCustomRulesPath` | Directory of custom SQLFluff rule plugin (12.7+) |
| `reportFilename` (root) | HTML report path. JSON uses the same base name |

Where to run it:
- Migrations-based: on migration scripts at dev time (Desktop) and in CI.
- State-based: on the generated deployment script after `prepare`, before `deploy`.
- Chained verbs continue after a failOnError failure. Run the next verb as a separate step.
- SQLFluff is not called if there are no pending migrations.

## 3. Severity model

| Severity | Effect |
|---|---|
| Error | Reported; fails the command when `check.code.failOnError=true` |
| Warning | Reported only |
| Disabled | Not evaluated |

SQLFluff mapping: rules are Error by default; add to `[sqlfluff] warnings` for Warning; add to `exclude_rules` for Disabled. Regex rules: `severity = "error" | "warning" | "disabled"` in each rule file.

Removed in 12.0.0: `majorRules`, `minorRules`, `majorTolerance`, `minorTolerance` (and Desktop 9.0 removed them from advanced parameters). Old pipelines using them must move to severities plus `failOnError`.

## 4. Redgate SQLFluff rules

All belong to the `redgate` group (except RG18 and RG19, which are in `all` only). Configuration keys are under `[sqlfluff:rules:redgate.<name>]` where shown.

| Rule | Name | Checks | Dialects | Config |
|---|---|---|---|---|
| RG01 | Drop Table | DROP TABLE statements (data loss) | all | |
| RG02 | Table column count | CREATE TABLE exceeding max columns (create only) | all | `max_columns` default 20 |
| RG03 | DROP DATABASE | DROP DATABASE statements | all | |
| RG04 | Multi Part naming | Object references exceed allowed name parts | all | `parts_allowed` default 1,2 |
| RG05 | Indexes in a separate script | Index creation mixed with other changes | all | |
| RG06 | Delete without Where | DELETE with no WHERE | all | |
| RG07 | GRANT statements | GRANTs (privilege escalation path) | all | |
| RG08 | ALTER USER statements | ALTER USER | postgres, snowflake | |
| RG09 | Update without Where | UPDATE with no WHERE | all | |
| RG10 | Modify Data Type | Data type change in ALTER TABLE | all | |
| RG11 | CREATE ROLE statements | CREATE ROLE | all | |
| RG12 | ALTER PUBLIC ROLE | Changes to PUBLIC role privileges | all | |
| RG13 | TRUNCATE Statement | TRUNCATE | all | |
| RG14 | Drop Column | DROP COLUMN | all | |
| RG15 | CREATE TABLE without PRIMARY KEY | Tables created with no PK | all | |
| RG16 | Drop PARTITION | DROP PARTITION | MySQL | |
| RG17 | CREATE TABLE without MS DESCRIPTION | No MS_Description extended property | TSQL | |
| RG18 | TABLE names should be pluralized | Suffix heuristic for plural names | all | Mutually exclusive with RG19 |
| RG19 | TABLE names should be singular | Table names ending in "s" (12.2+) | all | Mutually exclusive with RG18 |
| RG20 | Unbracketed object names | Object names not in square brackets (12.2+) | TSQL | |
| RG21 | Object prefix naming convention | Required prefix per object type (12.2+) | all (proc/function varies) | `redgate.prefix_naming`: `required_table_prefix`, `required_view_prefix`, `required_procedure_prefix`, `required_function_prefix`, `required_schema_prefix` (regex, case-insensitive) |
| RG22 | CREATE and DROP same table | Same table created and dropped in one script (12.3+) | all | `redgate.create_drop_table_order` `mode` = `CreateThenDrop`, `DropThenCreate`, `Both` (default) |
| RG23 | Forbidden alias names | Table or column aliases in a forbidden list (12.4+) | all | `redgate.forbidden_aliases` `forbidden_aliases` comma list, default empty |

History: RG01 to RG08 first released 11.14.1. RG18/RG19 bracketed identifier fix 12.3.0.

Plus the standard SQLFluff rule library (groups such as `ambiguous`, `convention`, `structure`, `layout`, `capitalisation`; codes like AM01, CV09, CP02, AL02). The shipped `conf/sqlfluff.cfg` enables only a subset plus Redgate rules.

## 5. Configuring SQLFluff

Which config is used (Flyway resolves at most one file and never merges):

| Situation | Config used | Local SQLFluff files (.sqlfluff, pyproject.toml, tox.ini, setup.cfg, pep8.ini) |
|---|---|---|
| `rulesConfig` set | That file only (must exist or error) | Ignored |
| Unset, Redgate Bundle active, `conf/sqlfluff.cfg` present | `conf/sqlfluff.cfg` in the Flyway install | Ignored |
| Unset, your own SQLFluff, or bundle active but no `conf/sqlfluff.cfg` | None from Flyway | SQLFluff's normal discovery applies |

- Flyway passes `--config` and `--ignore-local-config` when it resolves a file.
- Dialect always comes from Flyway (`--dialect`), so `dialect =` in the file has no effect.
- Recommended: copy `conf/sqlfluff.cfg` into the project, commit it, point `rulesConfig` at it. Redgate recommends listing rules explicitly (`rules = ...`) rather than `rules = redgate` plus `exclude_rules`, so upgrades do not silently add new rules.

```ini
[sqlfluff]
rules = ambiguous,convention,structure,RG01,RG02,RG06,RG09,RG15
warnings = RG02
exclude_rules = RG04

[sqlfluff:rules:redgate.prefix_naming]
required_table_prefix = ^tbl_

[sqlfluff:rules:convention.blocked_words]
blocked_words = TODO
```

Gotcha: `rules = RG01,RG02` with `exclude_rules = redgate` excludes the whole group.

Local overrides with SQLFluff `noqa`:
- File: `-- noqa: disable=AM01`
- Range: `-- noqa: disable = AL02` ... `-- noqa: enable = AL02`
- Line: `... ; -- noqa: CP02,CP03`
- Enterprise flags each noqa as a "Policy Overrides" violation (Warning by default, `check.code.noqaSeverity`).

Profiles (13.6+): a profile only excludes rules for one run. A `schemaModel` profile drops DML, script-shape, data-loss DDL, ALTER-only and formatting rules that are noise on schema model files. Desktop names it automatically when analysing schema model SQL. The 13.6.0 release notes say a built-in `schemaModel` profile is included, but the profiles setting page (updated 2026-10-21) now says "Flyway doesn't ship any profiles, so every profile you name must be defined here", gives `schemaModel` as an example to copy, and says naming an undefined profile fails the command. Define the profiles you use, including `schemaModel`:
```toml
[flyway.check.code.profiles]
schemaModel = ["capitalisation", "layout", "RG01", "RG03", "RG05", "RG06", "RG09", "RG10", "RG13", "RG14", "RG16", "RG22"]
preCommit = ["layout", "RX001"]
```
Run with `"-check.code.profile=preCommit"`. Reports do not record which profile ran. Profile names are matched case-insensitively. From Flyway 13.11.0 a profile can exclude individual regex rules by rule code (codes matched case-insensitively, written in full); rule groups and wildcards such as `LT*` apply to SQLFluff only. An entry that matches no rule logs a warning (when SQLFluff is enabled) and never fails the run. Excluding a regex rule in a profile affects only that run, unlike setting its severity to `disabled`.

## 6. Regex rules (Enterprise)

- One TOML file per rule in `rulesLocation`. File name `A__B.toml`: A = default code, B = default description.
- Fields: `code`, `dialects` (text, bigquery, db2, mysql, oracle, postgres, redshift, snowflake, sqlite, tsql), `rules` (Java regex array), `description`, `severity`.
- `TEXT` dialect applies to all databases. Rules for other dialects apply only when the JDBC URL matches.
```toml
code = "RX001"
dialects = ["TEXT"]
rules = ["(?i)(^|\\s)TO\\s+DO($|\\s|;)"]
description = "Phrase 'to do' remains in the code"
severity = "error"
```
- 12.0.0: Flyway no longer ships the default Redgate regex ruleset; `passOnRegexMatch` removed (deprecated 11.10.4).
- 12.2.0: regex engine no longer converts line endings before matching. Check `\r\n` handling in patterns.
- 11.16.0: all violations reported, not only the first.
- Desktop policies tab does not edit regex rules; edit files by hand.

## 7. Custom SQLFluff rules (12.7+)

```toml
[flyway.check]
sqlfluffCustomRulesPath = "/code-review-rules"
```
- Directory must exist and contain `__init__.py` (a SQLFluff plugin package), else `check -code` aborts with a clear error.
- Standard SQLFluff plugin API: `get_rules` hook (import rules inside the hook), optional `get_configs_info` for parameters.
- Rule classes extend `BaseRule`, named `Rule_<CODE>` (for example `Rule_TP01` reports as `TP01`). The docstring becomes the rule title.
- Additive to the resolved config file. Only with Redgate Bundle SQLFluff.

## 8. Report formats

| Format | Produced | Use |
|---|---|---|
| HTML | Always, at `reportFilename` (default `report.html`) | Human review, pipeline artifact. Code review, drift and changes appear as tabs. Code Review reports show the line that has a violation (Flyway 13.11.0) |
| JSON | Always, same base name as the HTML | Machine parsing. Per violation: `line_no`, `line_pos`, `line_no_end`, `line_pos_end`, `file_pos`, `file_pos_end`, `description`, `code`, `warning`, `engine`, `help`, optional `fixes` (delete/replace/insert) |
| SARIF 2.1.0 | `.sarif` file alongside JSON and HTML (12.2+) | GitHub Code Scanning, Azure DevOps, other SARIF tools |
| Console | Table of engine, rule code, count, severity | Pipeline logs |

- JSON `engine`, `file_pos`, `file_pos_end`, `fixes` added 12.3.0; positions adjust for Windows line endings 12.4.0.
- `-outputType=json` gives machine-readable command output (see CLI reference).
- GitHub Code Scanning: upload the `.sarif` file with GitHub's own SARIF upload action in the workflow after `flyway check -code`. The exact `.sarif` file name follows the report name (unverified; check the pipeline workspace after a first run).

## 9. Flyway Desktop

| Version | Feature |
|---|---|
| 8.5.16 | Code analysis for state-based deployment scripts on Automated deployment page |
| 9.2.0 | Code review display (preview) on Generate migrations and deployment script screens. Uses configured Flyway check engines, SQLFluff by default |
| 9.3.3 | "Apply fix" action for issues with a suggested fix |
| 9.3.4 | Whole-line underline for noqa warnings and regex hits |
| 9.7.0 | **Code Review Policies** tab in Project settings |

Policies tab: rules grouped by category (for example Redgate, Ambiguous, Convention); per rule enable/disable, Error/Warning, parameters, Learn more link; category menu for Enable all, Disable all, Set all to Error/Warning. Saving creates `sqlfluff.cfg` in the project and points `rulesConfig` at it, or rewrites the existing file: unmanaged sections (such as custom plugins) are kept, but rules/warnings lines and parameter sections are regenerated, so manual comments and ordering are lost. SQLFluff only.

Running from Desktop: Migration scripts page > Check > tick `code` > Run check. Also shown on Generate migrations before saving.

## 10. Positioning notes

- Community with SQLFluff is linting. Enterprise adds data-loss and security rules, regex policy rules, custom Python rules, pipeline failure, noqa auditing, SARIF, and Desktop policy editing.
- Map customer standards to rules in discovery: no DELETE/UPDATE without WHERE (RG06/RG09), no DROP TABLE/COLUMN without review (RG01/RG14), PK required (RG15), naming (RG18/19/20/21/23), GRANT and role control (RG07/RG11/RG12).
- Comparison deployment warnings (data loss, rebuilds) are separate from code review; `prepare -abortOnWarningSeverity` fails on those (`PREPARE_ABORT_ON_WARNINGS`).

## Sources
- https://documentation.red-gate.com/fd/reference/commands/check/check-code
- https://documentation.red-gate.com/flyway/flyway-concepts/code-review
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/running-code-review
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/running-code-review/tutorial-run-code-review-on-migrations
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/running-code-review/tutorial-edit-code-review-settings-using-flyway-desktop
- https://documentation.red-gate.com/flyway/reference/code-review-rules
- https://documentation.red-gate.com/fd/reference/code-review-rules/redgate-sqlfluff-rules-library
- https://documentation.red-gate.com/fd/reference/code-review-rules/configuring-sqlfluff-rules
- https://documentation.red-gate.com/fd/reference/code-review-rules/configuring-regex-rules
- https://documentation.red-gate.com/fd/reference/code-review-rules/configuring-custom-sqlfluff-rules
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-code-fail-on-error-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-code-noqa-severity-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-code-profile-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-code-profiles-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-scope-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-check-namespace/flyway-check-sqlfluff-custom-rules-location-setting
- https://documentation.red-gate.com/fd/reference/configuration/flyway-namespace/flyway-report-filename-setting
- https://documentation.red-gate.com/flyway/deploying-database-changes-using-flyway/automating-deployment-using-a-ci-cd-tool/common-state-based-deployment-scripts
- https://documentation.red-gate.com/fd/reference/exit-codes-and-error-codes/prepare-error-codes
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/flyway-desktop-8-release-notes-294781518.html

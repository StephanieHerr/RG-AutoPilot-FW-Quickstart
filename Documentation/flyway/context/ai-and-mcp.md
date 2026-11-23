<!-- last-verified: 2026-10-19 | refreshed-by: weekly refresh routine -->

# Flyway AI features and the Flyway MCP Server

Scope: `flyway mcp` (setup, toolsets, every tool, prerequisites, edition, preview status), Flyway Desktop AI features (script descriptions, summaries, commit messages, explain a change), and documented data handling. All AI capabilities below are **preview**; names and behaviour may change between releases.

## 1. At a glance

| Feature | Where | Edition | Status | Since |
|---|---|---|---|---|
| Flyway MCP Server (`flyway mcp`) | Flyway CLI, called by an AI coding agent | Enterprise | Public preview | Flyway 13.0.0 |
| AI migration script description | Flyway Desktop | Subscription license (see note) | Public preview | Desktop 8.7.2 |
| AI migration script summary ("deployment script descriptions") | Flyway Desktop, Migration scripts page | Subscription license (see note) | Public preview | Desktop 8.7.2 (promoted Jan 2026) |
| AI commit message | Flyway Desktop Git sidebar | Subscription license (see note) | Public preview | Desktop 8.7.2 |
| "Explain this change" in object level history | Flyway Desktop | Object level history was an Enterprise preview feature; GA in Desktop 9.10.7 (release status of "Explain this change" itself not stated) | Preview | Desktop 9.9.1 |

Note on edition: the "AI services in Flyway" doc says AI services are available to anyone with a Flyway subscription license. Redgate's January 2026 product update describes the script descriptions as a Flyway Enterprise feature. Confirm entitlement with Redgate before promising it to a Teams customer.

## 2. Flyway MCP Server

### What it is
- Implements the Model Context Protocol so an AI agent (Claude Code, VS Code GitHub Copilot Chat, GitHub Copilot coding agent, OpenAI Codex, Cursor, others) can call a curated set of Flyway development tools.
- **stdio** server: the AI tool starts `flyway mcp` as a local process. No HTTP endpoint.
- Covers the same development loop as Flyway Desktop: diff development DB vs schema model, update schema model, diff schema model vs migrations, generate migrations, code review, test migrate on shadow, update development DB.
- **Can**: read project config and schema model; diff dev DB, schema model and migrations; update schema model; generate migration scripts; apply changes to the `[flywayDesktop]` development and shadow environments.
- **Cannot**: run arbitrary Flyway verbs; modify `flyway.toml`. These limits apply to the tools only. If `[flywayDesktop]` environments point at non-dev databases, or the agent edits TOML directly, the limits do not protect you.

### Prerequisites
| Requirement | Detail |
|---|---|
| Flyway version | 13.0.0 or later (latest recommended) |
| License | Flyway Enterprise, licensed and authenticated. Check with `flyway version` (shows tier). No org-level opt-in beyond the license |
| Project config | `flyway.toml` must define both environments under `[flywayDesktop]`, and they must exist under `[environments.*]` |
| Workflow | Built for the Desktop dev/shadow workflow. Projects with only hand-written migrations and a single target will fail with `No such environment or missing [flywayDesktop] environments` |

```toml
[flywayDesktop]
developmentEnvironment = "development"
shadowEnvironment = "shadow"
```
For undo scripts alongside versioned ones, the MCP docs also recommend setting `[flyway.generate] types = ["versioned", "undo"]` explicitly.
(Use `developmentEnvironment` / `shadowEnvironment`: Desktop writes these, Redgate sample projects use them and the MCP docs require them. The namespace reference pages still show `development` / `shadow` (out of step; whether Desktop accepts them is unverified). See `common-architectures.md`.)

### Command
```
flyway mcp -mcp.toolsets=all
flyway mcp -mcp.toolsets=develop_migrations -mcp.maxLogs=100
```
| Parameter | Purpose |
|---|---|
| `mcp.toolsets` | Toolsets to enable: `develop_migrations`, `develop_state`, or `all` |
| `mcp.maxLogs` | Max MCP server log files kept on disk |

### Registering with AI tools

Claude Code (`.mcp.json` at repo root, same folder as `.git`):
```json
{
  "mcpServers": {
    "flyway": {
      "type": "stdio",
      "command": "flyway",
      "args": ["mcp", "-mcp.toolsets=develop_migrations", "-mcp.maxLogs=100"]
    }
  }
}
```
Or point at a config elsewhere: `claude --mcp-config flyway-project/.mcp.json`.

VS Code / GitHub Copilot Chat (`.vscode/mcp.json`, key is `servers`):
```json
{
  "servers": {
    "flyway": {
      "command": "flyway",
      "args": ["mcp", "-mcp.toolsets=develop_migrations", "-mcp.maxLogs=100"]
    }
  }
}
```
GitHub Copilot coding agent and OpenAI Codex: use each vendor's MCP config docs; `command` and `args` are identical.

Checking the file into Git:
- Use a bare `flyway` (on PATH), not a machine-specific path like `C:\flyway-x\flyway.cmd`.
- Cloud-hosted agents that honour `.mcp.json` may also start the server. If unwanted, register locally instead of committing.
- One `.mcp.json` at repo root is enough for a multi-project repo. Describe each project in `CLAUDE.md` or `AGENTS.md` so the agent knows which folder to load.
- Desktop may create `flyway.toml` in a subfolder of the folder you chose. The agent needs the exact folder for `load_project`.
- Desktop also creates `flyway.user.toml` (environments, credentials), merged automatically with `flyway.toml`.

### Toolsets
| Toolset | Intent |
|---|---|
| `develop_state` | Schema model and dev DB sync only. Use when you do not want an agent generating migration scripts |
| `develop_migrations` | Everything in develop_state plus migration diff, generation, code review, test migrate, schema model checkpoint |
| `all` | Every toolset (the docs say this is currently identical to `develop_migrations`) |

### Tool reference (12 tools)
| Tool | Toolsets | Purpose | Parameters (required unless marked) | Returns |
|---|---|---|---|---|
| `load_project` | both | Load a project into a new workspace. Required first. Loading another project discards previous artifacts | `projectFolder` (absolute path to folder with flyway.toml) | `workspaceId` |
| `reload_project` | both | Reload after TOML edits, keeping artifacts | `workspaceId` | |
| `create_schema_model_checkpoint` | develop_migrations | Capture schema model checkpoint for a three-sided diff (13.7+; renamed from `create_before_pull_snapshot` in 13.5) | `workspaceId` | `checkpointId` |
| `create_diff_schema_model` | both | Diff development DB against schema model (one stored per workspace) | `workspaceId` | `diffId`, selectable differences |
| `update_schema_model` | both | Apply selected differences to schema model files | `workspaceId`, `diffId`, `changes` (IDs or `*`) | Updated files (relative to schema model folder) |
| `create_diff_migrations` | develop_migrations | Diff schema model against migrations built on the shadow | `workspaceId` | `diffId`, differences not yet in a migration |
| `generate_migrations` | develop_migrations | Generate migration scripts using project naming convention. Undo scripts follow `[flyway.generate] types` (fallback `[flywayDesktop.generate] undoScripts`) unless overridden per call | `workspaceId`, `migrationsDiffId`, `changes`; `description` (optional); `generateUndoScripts` (optional, Flyway 13.10.0: true/false overrides the project setting for this call only) | Folder, generated files, warnings, `undoScriptsGenerated` |
| `review_code` | develop_migrations | Code review one migration script | `workspaceId`, `file` (absolute or project-relative) | Issues, rule definitions, `total_rules_checked` |
| `test_migrate` | develop_migrations | Run pending migrations on shadow; may reprovision if history diverged (13.7+) | `workspaceId`; `rebuild` (optional, forces full reprovision) | `results` per file (`success`/`failed`/`pending`), `error`, `reprovisioned` |
| `create_diff_development` | both | Diff schema model to dev DB (direction to update the DB). With `checkpointId`, three-sided diff tagging `new`, `existing`, `missing`, `conflict` | `workspaceId`; `checkpointId` (optional) | `diffId`, differences, `threeSidedDifferences` |
| `update_development` | both | Apply selected differences to the development DB | `workspaceId`, `diffId`, `changes` | `changesDeployed`, objects updated |
| `get_diff_details` | both | Unified diff text for one changed object from any diff | `workspaceId`, `diffId`, `changeId` | Diff text |

Selection rules: `changes` accepts IDs or a single `*`; cannot mix. Unselected dependencies of selected changes are included automatically.

### Typical agent sequence (from Redgate's worked example)
Request: "Generate migration scripts for the views I've updated in my development database."
1. `load_project` -> `workspaceId`
2. `create_diff_schema_model` -> `update_schema_model` with `*`
3. `create_diff_migrations`
4. `generate_migrations` with an inferred description, e.g. `V1.2__update_customer_summary_view.sql`
5. `review_code` on the new file (recommended), then optionally `test_migrate`

Smoke test prompts: "Load the Flyway project in this folder" (expect a workspace ID), "Diff my development database against the schema model", "Apply those schema model changes".

### File system footprint
| Purpose | Windows | Linux |
|---|---|---|
| Session workspace artifacts (diffs) | `%tmp%` | `/tmp` (or `$TMPDIR` / `java.io.tmpdir`) |
| Licensing and feature usage | `%appdata%\Redgate` | `~/.config/Redgate` |
| Server logs (`mcp.maxLogs`) | `%localappdata%\Red Gate\Logs\Flyway` | `~/.local/share/Red Gate/Logs/Flyway` |

### Security guidance (Redgate best practices)
- Enable the narrowest toolset (`develop_state` if no migration generation wanted).
- Only use with trusted projects and databases; anything the server can reach is within the agent's reach.
- Secure development and shadow environments, not just production.
- No plaintext credentials. Use resolvers (environment variables, secrets managers, Local Secret). Desktop's connection dialog can write plaintext credentials into TOML.
- Describe the workflow in `CLAUDE.md` / a skill ("capture into schema model before generating migrations", "ask before applying") rather than scripting tool order.
- Review with `get_diff_details` and read generated scripts before applying.
- Pin toolset config and read release notes before upgrading.

### MCP troubleshooting
| Symptom | Fix |
|---|---|
| `flyway` not recognised | Add Flyway to PATH or use the full path in `command` |
| Agent does not detect server | File must be exactly `.mcp.json` (leading dot, no hidden `.txt`), in the folder the tool launched from, and restart the tool |
| Nothing happens | Session must `load_project` first; ask explicitly and expect a workspace ID |
| Cannot find flyway.toml | Project folder differs from install folder; check where Desktop created it |
| Missing `[flywayDesktop]` environments | Add development and shadow environments |

Release history: 13.0.0 introduced; 13.2.0 no error when a `.conf` project exists outside project root; 13.5.0 rename to `create_schema_model_checkpoint`; 13.7.0 `test_migrate` and three-sided diff; 13.10.0 `generate_migrations` `generateUndoScripts` parameter.

Marketing vs docs: Redgate's launch blog mentions agents "checking migration status". No such tool exists in the tool reference; do not demo it.

## 3. Flyway Desktop AI services

| Feature | Behaviour |
|---|---|
| Generate migration script description | Suggests a filename description from script contents and project naming conventions, instead of defaulting to the user name. Editable. Not offered for baseline scripts (Desktop 9.0.1). At most 50 characters from Desktop 9.10.2, so file names avoid Windows "path too long" errors |
| Summarize migration script | Short summary of intent shown under the script on the Migration scripts page. Automatic when enabled. Baseline scripts excluded |
| Generate commit message | Select scripts in Git sidebar, press the AI button |
| Explain this change | In object level history, explains what a commit did to the selected object (Desktop 9.9.1) |

Enabling:
1. Allow `api.prod.prompt.redgate-platform.com` on 443.
2. Have a Redgate organization (domain not on the Redgate AI blocklist); users are members via SSO or Portal invite.
3. Desktop 8.7.2 or later, online license (offline permits do not work).
4. Org admin enables AI in Portal settings (https://portal.red-gate.com/settings). This is a Redgate-wide setting also covering Redgate Assistant, SQL Prompt and Monitor.
5. Users can switch AI off locally in Desktop Settings. Some users may also need to enable it in Desktop Preview features.

Troubleshooting: sign out and in; check firewall; check org setting and membership; version. No response for extremely large, empty or unintelligible scripts or diffs. Rate limited: wait five minutes.

## 4. Data handling (as documented)

Desktop AI services:
- May send migration script contents and commit diffs to Redgate's private AI service.
- Not used for training, not retained, not shared; processed transiently and not accessible after the response.
- Redgate states it cannot access information sent to the private AI service. Usage statistics may be collected.
- Models (listed on the doc page): Claude 3.7 Sonnet, Claude 4 Sonnet, Claude 4.5 Haiku, Cohere Embed multilingual v3, Amazon Nova Lite v1, hosted on Redgate's Amazon Bedrock in Frankfurt, London, Ireland and Paris.

MCP Server:
- No Redgate-hosted AI in the loop. The customer's chosen AI tool and its model provider receive whatever the agent reads (project files, schema, diffs, query results). Data handling is governed by that AI vendor, not Redgate.
- Licensing and feature usage data written locally as above.

Flyway Insights (formerly Pipelines) is a separate opt-in service; see `deployment-and-drift.md`.

## Sources
- https://documentation.red-gate.com/fd/reference/usage/flyway-mcp-server
- https://documentation.red-gate.com/fd/reference/usage/flyway-mcp-server/tool-reference
- https://documentation.red-gate.com/fd/reference/usage/flyway-mcp-server/register-with-your-ai-tools
- https://documentation.red-gate.com/fd/worked-example-362611560.html
- https://documentation.red-gate.com/fd/reference/commands/mcp
- https://documentation.red-gate.com/flyway/learn-more-about-flyway/troubleshooting
- https://documentation.red-gate.com/flyway/reference/configuration/flyway-desktop-namespace
- https://documentation.red-gate.com/fd/ai-services-in-flyway-317496573.html
- https://documentation.red-gate.com/flyway/flyway-blog/redgate-flyway-product-updates-january-2026
- https://voiceofthedba.com/2026/01/09/flyway-tips-ai-deployment-script-descriptions/
- https://www.red-gate.com/blog/introducing-the-flyway-mcp-server-governed-database-change-now-available-to-your-ai-coding-assistant/
- https://www.red-gate.com/blog/redgate-flyways-product-updates-september-2026/
- https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html
- https://documentation.red-gate.com/fd/flyway-desktop-8-release-notes-294781518.html

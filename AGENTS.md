# Flyway sandbox: instructions for AI assistants

This repo is a ready-made **Flyway Enterprise sandbox project** for SQL Server, Oracle, PostgreSQL and MySQL. Someone who may never have used Flyway opens it in their AI tool and says "start". You guide them to a working Flyway project on structure-only copies of their own database, starting from a dataless backup (Backup as Baseline on SQL Server, a Data Pump dump on Oracle, a schema-only dump plus a baseline script Flyway writes on PostgreSQL and MySQL). Then they try the everyday workflows themselves: deploy, check, drift and undo. It is a sandbox, not a production setup.

## What to do

- **"start", "set up", "get started", "next", "where am I":** read `.claude/skills/flyway-setup/SKILL.md` and follow it. It works in any AI tool. If yours has no skills feature, treat the file as your instructions. Someone who already has a Flyway Enterprise project can go straight to setting up a pipeline for it.
- **An error, "problem", "stuck", or a step that failed twice:** read `.claude/skills/flyway-troubleshoot/SKILL.md` and follow it, then return to the setup.
- **Progress and decisions** live in `Documentation/project-profile.md`. Read it first; update it at the end of each phase.
- **Reference, only when you need detail:** `Documentation/FlywayAIDump/` (SQL Server library; start at file 00's routing table) and https://documentation.red-gate.com.

Already here: `flyway.toml` (settings), `Scripts/` (create-databases SQL, CLI installer), code-review rules (`Rules/`, `sqlfluff.cfg`), a filter (`Filter.scpf`) and optional pipelines (`pipelines/`, one folder per CI/CD tool). Empty on purpose: `schema-model/`, `migrations/` and the environments in `flyway.toml`.

## Rules that always apply

1. **Sandbox only.** Use a server the user can create and drop databases on (their own machine or a dev/test server). The sandbox databases are new, hold structure only (no data) and are used for nothing else. If real production, real customer data or a real deployment comes up, stop kindly. `Prod` here is a pretend production.
2. **Plain, warm and short.** Assume no Flyway or pipeline knowledge. Ask one question per message, with numbered answers and the default marked. End every message with exactly what to reply. Don't use step numbers, and explain any jargon in one line. Answer in the user's language; keep commands, keys, file names and error text in English.
3. **Say before you do.** Before any command or file change, say in one plain sentence what it does and why. Don't write to the repo, run `git init` or commit until the user has answered the question the change depends on, then tell them what changed. Do tool calls first and put your message last.
4. **Who runs what.**
   - You run the Flyway CLI against `development` and `shadow` only: `--version`, `info`, `diff`, `model` and `generate`. If your tool has the Flyway MCP server (`.mcp.json`, preview), you may use it for the same work.
   - The user runs anything that changes Test or Prod (`baseline`, `migrate`, `undo`), in a terminal in this folder or in Flyway Desktop. Never run those yourself, even if asked: say you're blocked from changing their deployment targets, and guide them through it instead. Never run `clean` or `repair`.
   - You never run SQL against their databases. Give them the script and explain it; they run it in SSMS, Azure Data Studio or sqlcmd (SQL Server), SQL Developer (Oracle), psql or pgAdmin (PostgreSQL), or mysql or MySQL Workbench (MySQL).
   - Pipelines: you write and tailor the pipeline files, and commit once they agree. They install CI/CD tools, register runners or agents, enter secrets and run `git push`.
   - If you can't run commands at all, give the user each command and ask them to paste the output.
   - On Windows use PowerShell, and quote any Flyway argument containing a dot. Stay inside this folder, or the folder of an existing Flyway project the user names. Don't search the machine for files; ask. The one exception is the setup skill's lookup of Flyway Desktop in the installed-programs list.
5. **No secrets.** Never ask for, show or store passwords, tokens or permits. URLs in `flyway.toml` carry no credentials (Windows sign-in: `integratedSecurity=true`). SQL logins go into Flyway Desktop, which saves them in the git-ignored `flyway.user.toml`. Pipelines use secrets. If someone pastes a secret, tell them to rotate it and don't repeat it.
6. **Flyway writes the migrations.** Never hand-write or edit a migration; generate it from the schema model. Never change a migration that has been applied.
7. **Never invent** a command, flag, TOML key or URL. If the library and docs.red-gate.com don't cover it, say so. Label preview features as preview.
8. **Easiest route first, smallest scope.** One database and one schema, with Dev, Test and Prod. Don't add schemas, databases, a QA stage or ticketing until the first end-to-end run works. Don't call the sandbox finished before the wrap-up.

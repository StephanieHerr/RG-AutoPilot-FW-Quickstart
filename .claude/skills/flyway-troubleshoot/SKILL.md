---
name: flyway-troubleshoot
description: Diagnose a Flyway problem in this sandbox and, if it can't be fixed quickly, write a redacted support report for the user's Redgate SE or Support. Use when something fails, errors, hangs or looks wrong, when a setup step has failed twice, or when the user says "problem", "it broke", "error", "stuck", "not working" or "write this up for my SE".
---

# Flyway troubleshooting

Find the cause and get the user unstuck, or hand them a short, safe-to-share report. All rules in `AGENTS.md` apply.
- Diagnose read-only. Never run `migrate`, `undo`, `baseline`, `clean` or `repair`, and never suggest `clean` as a fix. If `repair` might be needed, explain what it changes and let the user decide.
- Never run SQL against their databases. Give them a script, and ask for the result (error text, never data).
- Use `flyway info` on `development` or `shadow` to test a connection, not `flyway testConnection`.
- Calm and clear: one question per message, and say what you're checking and why.
- **Two tries, then hand over.** If a fix hasn't worked after two attempts, stop guessing and write the report.

## Method

1. **Collect five facts.** Take what you can from the conversation and read-only checks, and ask only for what's missing:
   - the exact error text
   - the command, or Desktop page and button
   - where it ran (this machine, Desktop, or a pipeline)
   - `flyway --version` from that place (Community means a licensing problem, whatever the error says)
   - whether it worked anywhere else
2. **Simplest cause first:**
   - wrong folder
   - old Flyway, or not signed in
   - an unquoted dotted argument in PowerShell
   - a database or file name that's slightly off: sample names carry a year, such as `AdventureWorks2022`
   - a login that can't create or restore databases
   - a backup path the SQL Server can't read: `backupFilePath` and `@SourceBackupFile` are paths on the server, not on the user's PC, and the SQL Server service account must be able to read them
   - a login that can't restore databases (Flyway restores the baseline into shadow, Check and Build)
3. **Route by symptom.** Open the file; don't answer from memory.

   | Symptom | Look in |
   |---|---|
   | `migrate`, `validate`, checksum, failed or ignored migration, baseline mismatch, drift | Library file 22 |
   | Install, sign-in, licence, Git, Desktop, proxy, SQL Server connection, runner | Library file 23 (ignore its `testConnection` line) |
   | Backup as Baseline, baseline script, restore | Library file 07; `Scripts/CreateSandboxDatabases.sql` |
   | `flyway.toml`, environments, filters, shadow | Library file 10 |
   | `flyway --version` complains about a setting in `flyway.toml` | Flyway is too old: update it, don't edit the file |
   | Pipeline failure | `pipelines/README.md` and the tool's `README.md`; library files 11, 12 and 13 |
   | Oracle or Data Pump | `.claude/skills/flyway-setup/oracle.md` and the Redgate pages it links |
   | PostgreSQL or MySQL, `pg_dump`, `psql`, `mysqldump`, `mysql` | `.claude/skills/flyway-setup/postgresql-mysql.md` (its failure list) and the Redgate pages it links |
   | Unwanted `GRANT`/`DENY` in a diff or migration, or "changes" where only a made-up constraint or index name differs (`DF__…__1A2B3C4D`, `PK__…__F2AF558A…`) | Library file 10, comparison options: `ignorePermissions` and `ignoreSystemNamedConstraintAndIndexNames` (SQL Server). Ask before changing `flyway.toml`, then run the comparison again |
   | Desktop offers to "baseline and continue" on Test or Prod | Library file 08, section 18. Don't accept it: they're already baselined |
   | Flyway MCP server not responding | Library file 20, section 7 (the CLI works without it) |
   | Flyway MCP server registered but a tool errors, or you need its logs | Library file 23, section 12 (logs in `%localappdata%\Red Gate\Logs\Flyway`) |
4. **Fix.** Give the fix in a sentence. If they need to run something, give it to them and ask them to say when it's done.
5. **Verify** with the same check. Never say it's fixed just because a command ran.
6. **Go back:** "Shall we pick up where we left off?"

## Support report

Write it as a copyable block. Strip passwords, tokens, server, database and schema names (`<server>`, `<dev-db>`) and any data. Tell them you did, and ask them to look it over before sending it.

```
Flyway support report
Trying to: <one sentence>
What happened: <one or two sentences>
Command / Desktop action: <...>
Error (redacted): <...>
flyway --version: <...>
Database and kind: <SQL Server local / Azure SQL MI / Azure SQL DB / Oracle, version>
Where it ran: <this machine / Desktop / pipeline>
Worked elsewhere?: <...>
Already tried: <...>
Last 20 lines of output, -X if possible (redacted): <...>
```

If they want it saved, write it to `support-report.md` (git-ignored). Send it to their Redgate SE or to https://productsupport.red-gate.com/. Offer to carry on with any step that doesn't depend on the problem.

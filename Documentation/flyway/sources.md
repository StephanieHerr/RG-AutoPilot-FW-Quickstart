# Flyway sources

Where the refresh routine starts. Each context file also ends with a `## Sources` list of the exact pages it was built from.

## Release notes (check every run)

- Engine: https://documentation.red-gate.com/flyway/release-notes-and-older-versions/release-notes-for-flyway-engine
- Desktop 9: https://documentation.red-gate.com/fd/flyway-desktop-9-release-notes-329778435.html (if a Desktop 10 page appears, add it)

## High-change pages (check every run)

- Supported databases: https://documentation.red-gate.com/fd/supported-databases-and-versions-143754067.html
- Commands index (edition labels): https://documentation.red-gate.com/fd/reference/commands
- Feature summary (edition gating): https://documentation.red-gate.com/fd/feature-summary-165740620.html
- MCP tool reference: https://documentation.red-gate.com/fd/reference/usage/flyway-mcp-server/tool-reference
- Roadmap: https://www.red-gate.com/products/flyway/roadmap/
- Exit and error codes: https://documentation.red-gate.com/flyway/reference/exit-codes-and-error-codes

## Not refreshed

- `common-architectures.md` pipelines and `pizza-schema-sqlserver-2022.sql` are Laura's designs. The routine only checks that commands and parameters they use still exist.

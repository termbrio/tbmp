<p align="center">
  <img src="assets/brand/termbrio-mark.svg" alt="Termbrio" width="96" />
</p>

<h1 align="center">Termbrio Plugin Marketplace</h1>

Public Codex and Claude Code marketplace source for Termbrio CLI guidance,
TeamRelay messaging, activity hooks, and team orchestration skills.

## Repository Layout

The repository is intentionally small and provider-neutral:

```text
.agents/plugins/marketplace.json       Codex marketplace catalog
.claude-plugin/marketplace.json        Claude Code marketplace catalog
plugins/termbrio-team/
  plugin.json                          shared/Codex package manifest
  .codex-plugin/plugin.json            Codex package manifest
  .claude-plugin/plugin.json           Claude package manifest
  .mcp.json                            TermbrioTeam HTTP MCP registration
  hooks/hooks.json                     shared lifecycle hooks
  skills/                              CLI, TeamRelay, and orchestration skills
scripts/                               validation and release support
docs/                                  contracts and migration records
assets/brand/                          documentation artwork
```

Hooks, skills, and MCP configuration have one shared source under
`plugins/termbrio-team/`; the provider catalogs and manifests only expose that
payload to their respective runtimes. See [AGENTS.md](AGENTS.md) for placement
and ownership rules.

## Plugin

The shared `termbrio-team` plugin connects to the installed Server endpoint:

```text
http://127.0.0.1:56789/mcp
```

It does not ship a separate MCP runtime.

## Install

No GitHub login is required to install from this public marketplace.

```powershell
codex plugin marketplace add termbrio/tbmp --ref main
codex plugin add termbrio-team@tbmp
```

```powershell
claude plugin marketplace add https://github.com/termbrio/tbmp.git#main --scope user
claude plugin install termbrio-team@tbmp --scope user
```

The public Termbrio bootstrap scripts remain the recommended installation
surface. This repository owns marketplace/plugin source, not product packages.

## Versioning

Plugin versions are independent from Termbrio product releases. Each plugin
release records its minimum compatible product version and updates the public
release catalog through automation.

## Migration

TBMP is a clean-history extraction of the Termbrio marketplace payload from the
former EKMP repository. It does not contain unrelated plugins, applications, or
historical build artifacts, and the retired marketplace identity is not a
runtime fallback. The exact inclusion and exclusion boundary is recorded in
[docs/ekmp-to-tbmp-migration.md](docs/ekmp-to-tbmp-migration.md).

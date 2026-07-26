<p align="center">
  <img src="assets/brand/termbrio-mark.svg" alt="Termbrio" width="96" />
</p>

<h1 align="center">Termbrio Plugin Marketplace</h1>

Private Codex and Claude Code marketplace source for Termbrio CLI guidance,
TeamRelay messaging, activity hooks, and team orchestration skills.

## Plugin

The shared `termbrio-team` plugin connects to the installed Server endpoint:

```text
http://127.0.0.1:56789/mcp
```

It does not ship a separate MCP runtime.

## Install

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

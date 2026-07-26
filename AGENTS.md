# Repository Guidelines

## Scope

This repository owns the Termbrio Codex and Claude Code marketplace catalogs,
the `termbrio-team` plugin, its hooks, and its skills.

- `.agents/plugins/marketplace.json` is the Codex marketplace catalog.
- `.claude-plugin/marketplace.json` is the Claude Code marketplace catalog.
- `plugins/termbrio-team/` is the shared plugin source.
- `scripts/` contains focused migration/audit helpers and their tests.

Termbrio Server hosts the plugin's HTTP MCP endpoint. Do not add a standalone
MCP binary or duplicate Server runtime to this repository.

## Versions

Plugin versions advance independently of the Termbrio product. Generic and
Codex manifests use the Codex package version; the Claude manifest may use its
own compatible version. Every release must state the minimum compatible
Termbrio product version.

## Validation

```powershell
pwsh -File scripts/validate-termbrio-marketplace.ps1
```

Keep `*.sh` files UTF-8 and LF-only.

## Skills and Hooks

Skill instructions are product contracts. Review them against the current CLI,
MCP tools, hook environment, and identity behavior before publishing.

Hooks must remain bounded and must not fail the provider when Termbrio is
unavailable. Protected TeamRelay calls use the current stateless identity
contract.

## Git and Publishing

`dev` is the integration branch and `main` is the release branch. Use short
imperative commits. Release tags use the `vX.Y.Z` plugin version in this source
repo; public distribution may use the `plugins-vX.Y.Z` namespace in
`termbrio/releases`.

Never commit credentials, marketplace tokens, GitHub App private keys, local
plugin caches, or release binaries.

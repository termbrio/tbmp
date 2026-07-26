# Repository Guidelines

## Scope

This public repository owns the Termbrio Codex and Claude Code marketplace
catalogs, the `termbrio-team` plugin, its hooks, and its skills.

Termbrio Server hosts the plugin's HTTP MCP endpoint. Do not add a standalone
MCP binary or duplicate Server runtime to this repository.

Product binaries, installers, desktop/mobile applications, release artifacts,
and website pages belong to their respective `termbrio/tb`,
`termbrio/releases`, and `termbrio/website` repositories.

## Repository Layout

```text
tbmp/
|-- .agents/plugins/marketplace.json
|-- .claude-plugin/marketplace.json
|-- .github/workflows/
|-- assets/brand/
|-- docs/
|-- plugins/
|   `-- termbrio-team/
|       |-- plugin.json
|       |-- .codex-plugin/plugin.json
|       |-- .claude-plugin/plugin.json
|       |-- .mcp.json
|       |-- hooks/hooks.json
|       `-- skills/
|           |-- termbrio-cli/
|           |-- termbrio-team-agent/
|           `-- termbrio-team-orchestrator/
`-- scripts/
```

Ownership rules:

- `.agents/plugins/marketplace.json` is the Codex marketplace catalog.
- `.claude-plugin/marketplace.json` is the Claude Code marketplace catalog.
- `plugins/termbrio-team/` is the single shared plugin payload. Do not create
  provider-specific copies of shared hooks, skills, or MCP configuration.
- Provider manifests may describe provider-specific packaging, but their
  repository identity and plugin name must remain aligned.
- `scripts/` contains repository validation and release-support tooling.
- `docs/` contains shared marketplace contracts, migration records, and
  publishing notes.
- `assets/brand/` contains repository documentation assets; runtime UI assets
  remain in the product repository.

When adding another plugin, give it a separate directory under `plugins/` and
add one explicit entry to each marketplace catalog that supports it. Do not
place unrelated EK utilities, Bridge plugins, VsMcp plugins, or generated
artifacts in this repository.

## Versions

Plugin versions advance independently of the Termbrio product. Generic and
Codex manifests use the Codex package version; the Claude manifest may use its
own compatible version. Every release must state the minimum compatible
Termbrio product version.

## Validation

```powershell
pwsh -File scripts/validate-termbrio-marketplace.ps1
```

Run validation after changing a catalog, manifest, hook, skill, or repository
identity. A marketplace release is not ready while the validator reports a
retired marketplace name, old repository URL, version mismatch, or missing
shared payload.

Keep `*.sh` files UTF-8 and LF-only.

## Skills and Hooks

Skill instructions are product contracts. Review them against the current CLI,
MCP tools, hook environment, and identity behavior before publishing.

Hooks must remain bounded and must not fail the provider when Termbrio is
unavailable. Protected TeamRelay calls use the current stateless identity
contract.

## Git and Publishing

The clean-history import from the former EKMP repository is recorded in
`docs/ekmp-to-tbmp-migration.md`. Preserve that file as provenance; do not
reintroduce the old repository as a runtime fallback.

`dev` is the integration branch and `main` is the release branch. Use short
imperative commits. Release tags use `vX.Y.Z` in this source repository and
must point to a commit already integrated into `main`. A tag creates a
metadata-only GitHub Release here and projects its versions and source link
through `termbrio/releases`; plugin contents continue to be installed directly
from this public marketplace repository.

Marketplace installation is anonymous because this repository is public.
GitHub credentials are required only for contributor and publishing actions.

Never commit credentials, marketplace tokens, GitHub App private keys, local
plugin caches, or release binaries.

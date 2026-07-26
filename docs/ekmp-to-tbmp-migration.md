# EKMP to TBMP Migration

Status: completed source extraction; downstream product/release cutover in
progress.

## Purpose

`termbrio/tbmp` is the public dedicated source repository for Termbrio
coding-assistant marketplace plugins. It starts with a clean Git history while
preserving the reviewed Termbrio plugin payload from the former EKMP
repository.

This is a repository ownership change, not a compatibility layer. New
installation, update, validation, and release tooling must use the `tbmp`
marketplace identity and `termbrio/tbmp` repository.

## Provenance

- Source repository: `0x656d7265/ekmp`
- Source revision: `6520fa97e312b266413589d554dc184ce14f0016`
- Source release: Termbrio plugin `0.4.2`
- Clean-history import commit: `c10cbab`
- Destination repository: `termbrio/tbmp`

The shared hook and skill payload was copied from that source revision.
Repository identity, marketplace catalogs, validation, documentation, and
branding were adapted for TBMP.

## Included

- Codex marketplace catalog:
  `.agents/plugins/marketplace.json`
- Claude Code marketplace catalog:
  `.claude-plugin/marketplace.json`
- Generic, Codex, and Claude manifests for `termbrio-team`
- Stateless TermbrioTeam HTTP MCP registration
- Shared Codex/Claude lifecycle hooks
- `termbrio-cli`, `termbrio-team-agent`, and
  `termbrio-team-orchestrator` skills and their referenced guidance
- Focused marketplace validation
- Repository documentation and brand mark

## Excluded

The following former EKMP content is deliberately outside TBMP ownership:

- Bridge Team plugin
- VsMcp plugin
- marketplace applications
- unrelated EK tools and repository automation
- generated packages, caches, and release artifacts
- retired TermBridge migration helpers

Product code and product installers remain in `termbrio/tb`. Public binaries
and manifests belong in `termbrio/releases`. Landing and installation pages
belong in `termbrio/website`.

## Identity Mapping

| Former value | Current value |
| --- | --- |
| marketplace `ekmp` | marketplace `tbmp` |
| repository `0x656d7265/ekmp` | repository `termbrio/tbmp` |
| plugin id `termbrio-team@ekmp` | plugin id `termbrio-team@tbmp` |

The former values are provenance only. Active scripts and user guidance must
not use them as defaults or fallbacks.

## Version Contract

The imported versions were preserved:

- generic/Codex: `0.4.2+codex.20260725`
- Claude Code: `0.4.2`
- minimum compatible Termbrio product: `0.5.2`

Plugin versions advance independently from the Termbrio product version.
Generic and Codex manifests currently match exactly; the Claude version
currently matches the Codex semantic-version base.

## Validation

Run:

```powershell
pwsh -File scripts/validate-termbrio-marketplace.ps1
```

The validator checks catalog identity, repository identity, version agreement,
the shared HTTP MCP registration, required hooks and skills, and absence of
retired marketplace identities.

Before the first published TBMP release, also verify the downstream
`termbrio/tb` installer and release scripts use TBMP defaults and record the
TBMP source revision in generated release evidence.

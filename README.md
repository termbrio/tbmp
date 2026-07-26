<p align="center">
  <img src="assets/brand/termbrio-mark.svg" alt="Termbrio" width="96" />
</p>

<h1 align="center">Termbrio Plugin Marketplace</h1>

<p align="center">
  Codex and Claude Code integration for the Termbrio terminal runtime.
</p>

TBMP is the public marketplace repository for the `termbrio-team` plugin. The
plugin gives coding assistants an accurate operating model for Termbrio,
connects their lifecycle events to the installed Server, and lets team members
exchange durable messages without shipping another background service.

TBMP is not Termbrio itself. An installed and reachable Termbrio Server and the
`tb` CLI are required. Product releases are published separately through
[`termbrio/releases`](https://github.com/termbrio/releases).

## Why the plugin exists

A generic terminal assistant can run commands, but it does not automatically
know:

- which terminal session, workspace, peer, or team member a name refers to;
- whether it should create, resume, attach, or restart a managed conversation;
- how Termbrio distinguishes terminal activity from assistant activity;
- how to authenticate one stateless TeamRelay call without borrowing another
  member's identity;
- when a durable message has been accepted but its terminal notification is
  still deferred;
- which team lifecycle actions are definition edits, hidden initialization,
  visible layout operations, or destructive cleanup.

The plugin captures those contracts as versioned skills, hooks, manifests, and
MCP configuration. This allows Codex and Claude Code to use the installed
product instead of guessing from old syntax or inspecting private runtime data.

## What is included

| Surface | Purpose |
| --- | --- |
| `termbrio-cli` skill | Operate sessions, workspaces, Servers, pairing, shares, launches, installers, and plugins through current `tb` help and JSON contracts |
| `termbrio-team-agent` skill | Register one member identity and use TeamRelay inboxes, threads, replies, delivery state, and bounded screen reads through MCP |
| `termbrio-team-orchestrator` skill | Define, validate, initialize, recover, start, hide, stop, and hand off Server-owned coding-agent teams |
| Provider hooks | Report session, prompt, question, permission, completion, failure, and shutdown events without failing the provider when Termbrio is unavailable |
| MCP registration | Connect both providers to the stateless `TermbrioTeam` HTTP endpoint hosted by Termbrio Server |
| Marketplace catalogs | Expose one shared plugin payload to Codex and Claude Code without provider-specific copies |

The orchestration skill is intentionally explicit: ordinary team membership
does not grant permission to redesign or restart a team. Member messaging and
team lifecycle management remain separate workflows.

## Architecture

```text
Codex / Claude Code
  |-- skills ----------> installed tb CLI ----------> Termbrio.Server
  |-- lifecycle hooks ------------------------------> activity intake
  `-- TermbrioTeam MCP -> http://127.0.0.1:56789/mcp
                                                   `-> TeamRelay
```

The MCP endpoint is part of `Termbrio.Server`. TBMP contains no MCP executable,
stdio bridge, daemon, database, or duplicate Server runtime. Protected MCP
calls are stateless and carry the current member identity on every request.

## Product dependency

Install or update Termbrio before installing the plugin:

```powershell
tb --version --json
tb server status
```

The current plugin requires Termbrio 0.5.2 or newer for schema-v4 conversation
actions, managed provider resume, stable conversation identity, notification
templates, exact-message reply acknowledgement, and bounded team screen reads.
Plugin and product versions advance independently; each plugin release records
its minimum compatible product version.

If the Server is unavailable, the CLI and TeamRelay operations report that
condition normally. Hook transport remains bounded and must not block or fail a
Codex or Claude Code turn.

## Install

The marketplace is public. Installation does not require GitHub authentication.

### Codex

```powershell
codex plugin marketplace add termbrio/tbmp --ref main
codex plugin add termbrio-team@tbmp
```

Update later:

```powershell
codex plugin marketplace upgrade tbmp
codex plugin add termbrio-team@tbmp
```

### Claude Code

```powershell
claude plugin marketplace add https://github.com/termbrio/tbmp.git#main --scope user
claude plugin install termbrio-team@tbmp --scope user
```

Update later:

```powershell
claude plugin marketplace update tbmp
claude plugin update termbrio-team@tbmp --scope user
```

Restart Claude Code or run `/reload-plugins` after installation or update.
Termbrio's public bootstrap scripts provide the same setup for Windows, Linux,
and macOS.

## Repository layout

```text
.agents/plugins/marketplace.json       Codex marketplace catalog
.claude-plugin/marketplace.json        Claude Code marketplace catalog
plugins/termbrio-team/
  plugin.json                          shared manifest
  .codex-plugin/plugin.json            Codex manifest
  .claude-plugin/plugin.json           Claude Code manifest
  .mcp.json                            Server-hosted MCP registration
  hooks/hooks.json                     shared lifecycle hooks
  skills/
    termbrio-cli/
    termbrio-team-agent/
    termbrio-team-orchestrator/
scripts/                               validation and release contracts
docs/                                  migration and publishing records
assets/brand/                          repository artwork
```

Hooks, skills, and MCP configuration have one shared source under
`plugins/termbrio-team/`. Provider catalogs only expose that payload to their
respective runtimes. See [AGENTS.md](AGENTS.md) for ownership rules.

## Validate

```powershell
pwsh -File scripts/validate-termbrio-marketplace.ps1
pwsh -File scripts/plugin-release-contract-tests.ps1
```

Validation checks marketplace identity, provider manifests, shared versions,
the MCP endpoint, required hooks and skills, hard-cutover rules, and the
tag-to-catalog release contract.

## Version and release flow

The source tag is `vX.Y.Z` and must point to a commit already integrated into
`main`. Tagging performs four actions:

1. validate the marketplace and shared plugin payload;
2. require `X.Y.Z` to match the Claude version and the base Codex version;
3. create an assets-free GitHub Release record in this repository;
4. dispatch the source revision, versions, tag, and release URL through
   `termbrio/releases` to the website.

No plugin archive is built. Codex and Claude Code continue to install the
marketplace contents directly from this repository.

## Migration provenance

TBMP is a clean-history extraction of the Termbrio marketplace payload from the
former EKMP repository. It contains no unrelated plugins, applications, or
historical build artifacts, and the retired marketplace identity is not a
runtime fallback. The inclusion and exclusion boundary is recorded in
[the migration note](docs/ekmp-to-tbmp-migration.md).

# Termbrio Team Plugin

This plugin adds three deliberately separate agent behaviors through the
following skills:

- `termbrio-cli`: general Termbrio operation and troubleshooting through the
  installed `tb` CLI;
- `termbrio-team-agent`: member-scoped TeamRelay messaging through the
  Server-hosted MCP endpoint;
- `termbrio-team-orchestrator`: explicitly assigned team-definition and
  lifecycle work through the installed `tb` CLI.

The plugin uses the stateless Streamable HTTP endpoint hosted by the installed `Termbrio.Server`:

~~~text
http://127.0.0.1:56789/mcp
~~~

There is no standalone MCP runtime, download cache, or stdio process.

The MCP surface is reserved for member-scoped TeamRelay messaging. Team definition and lifecycle management use the installed CLI over the Server's REST contracts; no second management secret or second MCP connection is introduced.

Plugin version 0.4.3 requires Termbrio 0.5.2 or newer for schema-v4 conversation actions, scoped bootstrap, visible-before-ready `tb team start`, lazy managed `tb session resume`, stable provider conversation identity, the current hook contract, exact-message reply acknowledgement, notification templates, and bounded team screen reads. Update the product before relying on those workflows after a plugin-only upgrade.

TeamRelay notifications remain reference-only by default; an operator may explicitly opt a global or team template into fixed-frame untrusted `{body}` presentation. Protected MCP tools also expose sender-authorized delivery status, ordered thread reads, exact-message reply acknowledgement, and policy-controlled on-demand `team_read_screen`. A committed MessageId means durable inbox acceptance, while `message_status` reports the separate terminal-notification state. Screen reads are same-host, bounded, untrusted, non-redacting observations and are never a readiness or monitoring loop.

## Codex Install

The marketplace repository is public, so GitHub authentication is not required.
Add the marketplace and plugin:

```powershell
codex plugin marketplace add termbrio/tbmp --ref main
codex plugin add termbrio-team@tbmp
```

For updates:

```powershell
codex plugin marketplace upgrade tbmp
codex plugin add termbrio-team@tbmp
```

## Claude Code Install

Claude Code uses the same skill and HTTP MCP configuration through the Claude marketplace catalog in this repository. GitHub authentication is not required for this public marketplace. For first-time setup:

```powershell
claude plugin marketplace add https://github.com/termbrio/tbmp.git#main --scope user
claude plugin install termbrio-team@tbmp --scope user
```

For updates:

```powershell
claude plugin marketplace update tbmp
claude plugin update termbrio-team@tbmp --scope user
```

Restart Claude Code or run `/reload-plugins` after installation or update.

## macOS and Linux

Install the Codex or Claude Code plugin with the matching POSIX shell bootstrap:

```sh
curl -fsSL https://termbrio.dev/apps/tb/install-plugin.sh | sh
curl -fsSL https://termbrio.dev/apps/tb/install-claude-plugin.sh | sh
```

Update later with:

```sh
curl -fsSL https://termbrio.dev/apps/tb/update-plugin.sh | sh
curl -fsSL https://termbrio.dev/apps/tb/update-claude-plugin.sh | sh
```

These commands manage only the plugin. A reachable `Termbrio.Server` is still required for the HTTP MCP endpoint.

## Activity Hooks

Codex and Claude lifecycle hooks report provider-neutral member activity through the shared synchronous `hooks/hooks.json` manifest. The bounded two-second commands cover session start/end, prompt submission, permission/input requests, actionable notifications, and completion. Question-tool hooks match Codex `request_user_input` and Claude `AskUserQuestion` instead of launching a process for every tool call. A single cross-provider manifest avoids duplicate Codex registration and unsupported asynchronous-hook warnings. Hook transport failure never fails the provider. Termbrio retains bounded provider metadata and summaries rather than raw hook stdin.

Every managed runtime receives `TB_SESSION_ID`, `TB_SESSION_REF`, `TB_WORKSPACE`, `TB_SERVER_URL`, `TB_RUNTIME_GENERATION`, `TB_HOOK_TOKEN`, and `TB_BOARD_URL`. An actual team-member runtime additionally receives `AGENT_TEAM`, `AGENT_NAME`, `AGENT_PIN`, and `AGENT_IDENTITY`, plus provider/member metadata when configured. `TB_HOOK_TOKEN` is a narrow write-only activity credential bound to that exact session and runtime generation; it is separate from TeamRelay messaging identity. Hooks read `TB_SERVER_URL`; the retired `TB_AGENT_URL` name has no fallback. Sessions without managed hook identity are ignored safely.

Use `tb team status TEAM --json` for the latest member state and `tb hook events --team TEAM --json` for the ordered observer stream. Treat hook state as provider evidence with an expiry, not as proof that the terminal process is alive.

Install or update Termbrio before installing this plugin so `tb` is available on `PATH`.

## Identity

Termbrio team-member sessions expose `AGENT_IDENTITY` in `agentName@team:pin` form. The six-hex `AGENT_PIN` is a local accidental-use guard derived from canonical `team/agentName`; pairing and the Server bearer remain remote authority. The shared MCP endpoint is stateless, so every protected tool call receives the known value as `agentIdentity`. An agent reads it from its own process environment once on first need and reuses it, rather than shell-reading before every call. Do not print it in user-facing output.

Registration uses the known identity or reads `AGENT_IDENTITY` once, adds optional metadata from the current terminal environment, and calls `register_agent` once. It does not inspect databases, team plans, config files, source code, or construct JSON.

Member identity values remain scoped to protected TeamRelay calls. Team Orchestrator operations use `tb team` commands and never place `AGENT_IDENTITY` or `AGENT_PIN` on the command line.

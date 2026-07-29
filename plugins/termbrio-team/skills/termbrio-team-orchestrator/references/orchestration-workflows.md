# Team Orchestration Workflows

Use only the installed `tb` CLI for team definition and lifecycle management. TermbrioTeam MCP is reserved for member-scoped TeamRelay messaging; do not search its catalog for orchestration tools or ask the model to read member credentials for management.

## First Team

Prefer this path when the user describes several members and wants a team definition without an immediate start:

~~~text
tb --version --json
tb team layouts --json
tb team template codex --json
# Author one schema-v4 FILE from the template and the user's supplied members.
tb team validate FILE --resolve --json
tb team import FILE --json
tb team show TEAM --json
~~~

Before validation, require each member to make these choices explicit in the file:

- one session binding: `session.id`, `session.ref`, or create/reuse-capable `session.name`;
- one provider and `assistant.action`;
- `conversation` for `resume`;
- `create-once` for a new persistent conversation unless the user asked for ephemeral `create-always`;
- a real working directory;
- `permissions.mode: default` unless the user requested another profile;
- only layout coordinates advertised by `tb team layouts --json`.

If the team already exists, fetch its revision first and use `--replace --revision REVISION` only after intentionally reconciling the stored and file definitions. A successful import completes a definition-only request. Do not run `init` or `start` unless the user separately requested lifecycle mutation.

## Atomic Definition

~~~text
tb team layouts --json
tb team create optimate --json
# Set REVISION from the create response, then replace it after every successful edit.
tb team edit optimate set workspace --name optimate --cwd /work/optimate --revision REVISION --json
tb team edit optimate set layout --strategy auto --surfaces 2 --revision REVISION --json
tb team edit optimate add agent CODER --role coder --display-name "Coder" --revision REVISION --json
tb team edit optimate set agent CODER session --name CODER --cwd /work/optimate --revision REVISION --json
tb team edit optimate set agent CODER assistant --provider codex --action create-once --model MODEL --conversation CODER --revision REVISION --json
tb team edit optimate set agent CODER bootstrap --version 1 --scope once --wait-for input-ready --revision REVISION --json
tb team edit optimate set agent CODER bootstrap --submit "Inspect the repository and wait." --revision REVISION --json
tb team edit optimate set agent CODER layout --surface main --area left --revision REVISION --json
tb team show optimate --json
tb team preflight optimate --json
~~~

Use the installed help for exact flags. Select an explicit renderer, surface, display, or area only when `team layouts --json` advertises the matching capability. After the first write, retain the returned revision and pass it through `--revision` on every later edit; on conflict, fetch `team show --json`, merge intentionally, and retry with the fresh revision.

## File Definition

~~~text
tb team template codex --json
tb team export optimate --output optimate.team.yaml --json
# Edit the portable file.
tb team validate optimate.team.yaml --resolve --json
# Replace REVISION with the integer returned by team show/export.
tb team import optimate.team.yaml --replace --revision REVISION --json
tb team show optimate --json
~~~

Export/import files never contain credentials and never start a session.

## Legacy File Migration

Read the current schema version from `tb team schema --json`, then perform a pure file conversion before import:

~~~text
tb team migrate legacy.team.yaml --to-version 4 --output migrated.team.yaml --resolve-sessions --json
tb team validate migrated.team.yaml --resolve --json
~~~

Migration never imports, initializes, or starts the team. Review every warning, especially unresolved or ambiguous session references, before importing the output. Never reuse the input path as the output path.

## Conversation Actions and Bootstrap Scope

Use one explicit assistant action:

~~~yaml
# Existing conversation; fail without creating a fallback.
assistant:
  provider: codex
  action: resume
  conversation: CODER

# New persistent conversation; later starts resume it.
assistant:
  provider: codex
  action: create-once
  conversation: CODER

# Fresh reviewer conversation after every stop/start.
assistant:
  provider: codex
  action: create-always
  conversation: REVIEWER
bootstrap:
  version: 1
  scope: per-conversation
  steps:
    - submit: "Read AGENTS.md and review the current changes."
~~~

`create-once` provisioning is recorded after provider initialization and before bootstrap. If bootstrap later fails, retry the existing conversation; never change the action to force another create. Use `scope: once` for member-lifetime setup and `per-start` only for an intentionally repeated prompt in the same resumed conversation.

## Hidden Initialization

Foreground:

~~~text
tb team init optimate --wait --json
tb team status optimate --json
~~~

If the result is `attention-required`, show the sanitized question and advertised choices to the user, then relay exactly one explicit answer:

~~~text
tb team init-respond optimate OPERATION_ID --choice CHOICE --wait --json
~~~

Detached:

~~~text
tb team init optimate --json
tb team init-status optimate OPERATION_ID --json
tb team init-cancel optimate OPERATION_ID --json
~~~

Do not loop on `init-status`. Prefer `--wait` when the orchestrator must block, otherwise retain the id and resume on an external event or user request.

## Provider Permission Profiles

Keep `default` for ordinary orchestration so the provider's interactive configuration remains authoritative. Pin a portable conservative profile only when requested:

~~~yaml
assistant:
  provider: codex
  permissions:
    mode: prompt
~~~

The supported typed profiles are `prompt`, `edit-accepting`, `read-only`, and `full-access`. Semantic preflight reports the normalized mode and every injected provider argument. Claude `read-only` maps to its restrictive planning mode.

Use `full-access` only when the user explicitly requests bypass for named members and the runtime has an appropriate external sandbox:

~~~yaml
# Codex: externally sandboxed unrestricted member
assistant:
  provider: codex
  permissions:
    mode: full-access

# Claude: externally sandboxed unrestricted member
assistant:
  provider: claude
  permissions:
    mode: full-access
~~~

Never add either flag merely because the user asked to initialize, start, automate, or run a team unattended. Scope the choice to the named member(s), state that provider safeguards are bypassed, and retain the default `attention-required` flow for every other member.

For a small revision to a stored definition, use the typed atomic edit only after that explicit opt-in. Replace `REVISION` with the current revision:

~~~text
tb team edit optimate set agent CODER assistant --permission-mode full-access --revision REVISION --json
tb team preflight optimate --json
~~~

Before initialization, require one of these session intents per member:

~~~yaml
# Reuse exact existing session
session:
  id: 019f0000-0000-7000-8000-000000000000

# Resolve an existing canonical reference; missing is an error
session:
  ref: workspace/session@pair

# Explicitly permit create-or-reuse by name
session:
  name: session
~~~

## Visibility

~~~text
tb team start optimate --json
tb team hide optimate --json
tb team stop optimate --json
~~~

`start` is also the immediate-visibility lifecycle entry point. It materializes correctly configured member sessions, renders the server's neutral layout on the current CLI platform, and returns the queued background initialization operation for unfinished provider/bootstrap readiness. Use explicit `init --wait` only when hidden prewarm is intended. `hide` affects local views only. `stop` stops server sessions while preserving the definition and resume metadata.

## Input and Messaging

~~~text
tb team submit optimate CODER "Run the focused tests." --json
tb team dispatch optimate --from ORCHESTRATOR --to CODER --body "Review the failing test." --json
~~~

Use `submit` for trusted terminal/provider input. Use `dispatch` for untrusted TeamRelay messages. Never place a member identity value on either command line.

Use `team status` and hook events for readiness. The TeamRelay `team_read_screen` operation is an explicit, bounded, same-host observation tool for the member-messaging role; it is not a lifecycle probe and must not be polled by an orchestrator.

## Recovery

- Revision conflict: fetch `team show` again, merge intentionally, and retry with the fresh revision.
- One managed member: prefer its canonical session reference and run `tb session resume CANONICAL_REF --no-attach --no-replay`. Use `id:<guid>[@pair]` only when discovery confirms that it resolves to this named session; a bare GUID remains a lexical name. A live and ready member is kept without readiness work. A live but not-ready member is kept without relaunch and queues readiness work. A stopped or missing named member is materialized/restored from the team definition and queues provider create/resume readiness. Do not substitute an id-only session or a hand-built `codex resume` / `claude --resume` command.
- Failed operation: inspect `team status` and the operation error, then use `--retry-failed`.
- Failed operation cleanup: preview with `tb team init-cleanup TEAM OPERATION_ID --json`; after reviewing candidates, apply with `tb team init-cleanup TEAM OPERATION_ID --apply --json`. The server removes only resources owned by that operation and preserves reused sessions.
- Ambiguous bootstrap input: inspect terminal state; use `--reinitialize-bootstrap` only with explicit replay intent.
- Server restart: query the same operation id; queued/running jobs are recovered by the server.
- Visible layout lost: run `team start` again; do not restart a live SessionId solely to rebuild a view.
- When `team start` returns an initialization operation because readiness work remains, retain its id for later status or attention handling; do not wait before presenting the opened layout. The operation is null when every member is already ready.
- Slow visible layout: retry with `tb team start TEAM --timing --json` and report the resolved renderer plus server, renderer, and total timings.

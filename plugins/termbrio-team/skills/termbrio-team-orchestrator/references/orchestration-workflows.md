# Team Orchestration Workflows

Use the installed `tb` CLI for Team definition and lifecycle management. Use
TermbrioTeam MCP only for member-scoped TeamRelay messaging.

## Discover the canonical contract

~~~text
tb --version --json
tb team --help
tb team schema --json
tb team layouts --json
~~~

Require Termbrio 0.5.9 or newer and root `version: 6`. The root integer is
only the file-schema contract. There is one Team domain and one `tb team` /
`/teams` API; do not seek a versioned endpoint, store, service, or DTO.

The schema is authoritative for files. If `team template` or human help emits
fields rejected by `team schema`, report the installed product mismatch and
author from the schema instead. Do not run migration commands, convert an old
root version, or preserve an unsupported Team shape.

## Author a Team file

Prefer one reviewed file for several related changes:

~~~yaml
version: 6
team: optimate
defaultView: day-shift

workspaces:
  optimate:
    cwd: E:\GitHub\btyon\optimate
    environment: {}
  optimate@ek-pc:
    peer: ek-pc
    cwd: E:\GitHub\btyon\optimate
    environment: {}

agents:
  - name: LEAD
    workspace: optimate
    role: Local owner
    session:
      name: LEAD
      startup: []
    assistant:
      provider: codex
      action: resume
      conversation: LEAD
      arguments: []
      permissions:
        mode: default

  - name: WORKER
    workspace: optimate@ek-pc
    role: Owner-controlled worker hosted by EK-PC
    runtime:
      server: ek-pc
      lifecycleAuthority: team-owner
    session:
      name: WORKER
      startup: []
    assistant:
      provider: codex
      action: create-once
      conversation: OPTIMATE_WORKER
      arguments: []
      permissions:
        mode: default
    bootstrap:
      version: 1
      scope: per-conversation
      steps:
        - waitFor: input-ready
        - submit: Read the team instructions and report ready.

linkedAgents:
  - id: reviewer
    agent: quality/REVIEWER@ek-pc

views:
  - name: day-shift
    layouts:
      - id: coordination
        pattern: main-right-stack
        launcher: windows-terminal
        surface: 1
        display: 1
        panels:
          - target: member:LEAD
            slot: main
          - target: member:WORKER
            slot: right-top
          - target: link:reviewer
            slot: right-bottom
~~~

Preserve these boundaries:

- `agents` are owned lifecycle members. A remote owned member uses the remote
  workspace path, `runtime.server: PAIR`, and
  `runtime.lifecycleAuthority: team-owner`.
- `linkedAgents` are persistent canonical references to externally owned
  members. A link has no local workspace, session, assistant, or lifecycle.
- `views` select presentation only. A panel target is `member:NAME` or
  `link:ID`; a layout never creates membership or limits Team size.
- `pattern` and `slot` use the enums returned by `team schema`. `launcher` uses
  an available renderer returned by `team layouts`.
- Pair aliases and remote-machine paths are authoring values. TeamId, MemberId,
  OwnerServerId, credentials, endpoints, and grant IDs remain Server-owned and
  never enter the portable file.

Validate and import without starting anything:

~~~text
tb team validate optimate.team.yaml --json
tb team import optimate.team.yaml --json
tb team show optimate --json
tb team view list optimate --json
tb team start optimate --view day-shift --dry-run --json
~~~

For replacement, fetch the current revision and use both `--replace` and
`--revision REVISION`. Reconcile a `409` intentionally; never overwrite a
newer Team definition blindly.

## Edit a stored Team

Use `tb team edit TEAM ... --revision REVISION --json` for one small change.
Use export/edit/validate/import when changing workspaces, several members,
links, or views together:

~~~text
tb team export optimate --output optimate.team.yaml --json
# Edit the portable file.
tb team validate optimate.team.yaml --json
tb team import optimate.team.yaml --replace --revision REVISION --json
tb team show optimate --json
tb team start optimate --view day-shift --dry-run --json
~~~

`create`, `edit`, `import`, and Server Web builder save are definition-only.
They never initialize a provider or open a terminal view.

## Pair and place a remote owned member

Discover and verify the existing authority before changing it:

~~~text
tb pair list
tb pair show ek-pc
tb pair test ek-pc
tb federation status --json
~~~

Pairing is directional. A sender needs an outbound peer; the receiving Server
needs the corresponding trusted-client authority. Treat aliases, ServerIds,
trusted-client grant IDs, federation grant IDs, and capabilities as distinct.

Do not create or broaden grants merely because a Team file names a remote
workspace. A reviewed full-access pair may already supply the development
authority. If installed status reports that a scoped relay/runtime grant is
required, obtain explicit user authority, use the exact trusted-client grant
and stable Server-owned TeamId/MemberId returned by the Server, then verify the
fresh federation status. Never guess IDs or add them to YAML.

The Runtime Server brokers process creation. The Owner Server retains Team
lifecycle, provider readiness, TeamRelay policy, and the direct SessionHost
control/attach relationship. An offline Runtime Server remains an unreachable
per-member outcome; never create a local fallback member.

## Link an external member

Add a canonical `linkedAgents` entry only when the user wants that external
member to be part of this Team's discoverable collaboration/view contract:

~~~yaml
linkedAgents:
  - id: external-reviewer
    agent: other-team/REVIEWER@ek-pc
~~~

Use `link:external-reviewer` in a view. The linking Team may resolve and attach
that exact member only through current owner-authorized evidence. It never
starts, resumes, initializes, or stops the external member.

A direct TeamRelay recipient such as `other-team/REVIEWER@ek-pc` is merely a
routed address; sending to it does not create a persistent link. `*` targets
the sender's primary Team set and never recursively expands linked teams.

## Choose conversation provisioning

~~~yaml
# Existing provider conversation; missing is an error.
assistant:
  provider: codex
  action: resume
  conversation: LEAD

# Create once, persist the provider conversation ID, then resume it.
assistant:
  provider: codex
  action: create-once
  conversation: WORKER

# Create a fresh provider conversation after every stopped-to-running start.
assistant:
  provider: codex
  action: create-always
  conversation: REVIEWER
~~~

`create-once` resumes only when the Server has a real provider conversation
ID. A logical member/conversation name is not a provider resume locator. Use
`tb team reset-assistant TEAM --member MEMBER --json` only with explicit
recreate intent and only while the member terminal is stopped.

Bootstrap scope is independent: use `once` for member-lifetime setup,
`per-conversation` for each newly created provider conversation, and
`per-start` only for deliberately repeated work.

## Start, show, hide, and stop

Run a zero-side-effect file validation and inspect the stored definition
before lifecycle mutation. Then choose one visible-start mode:

~~~text
# A sole view is implicit; otherwise defaultView is used.
tb team start optimate --json

# Select one named view explicitly.
tb team start optimate --view day-shift --json

# Start owned lifecycle without a local presentation view.
tb team start optimate --no-view --json
~~~

Start reconciles every owned member independently, then compiles the selected
view from stable Team/member/link identity. One offline or failed member must
not block healthy members or valid panels. A panel may appear before it has a
current attachable SessionId and wait for the ordinary attach route; the panel
must not create a second lifecycle operation.

Repeated start is idempotent: reuse existing launcher instances, fill missing
panels, and retry failed members without duplicating the entire view.

~~~text
tb team show optimate --view day-shift --json
tb team hide optimate --view day-shift --json
tb team stop optimate --json
~~~

`show --view` materializes an existing-session view. `hide` closes matching
local views and leaves sessions alive. `stop` closes every local view owned by
the canonical Team and independently requests stop for owned members only. An
unreachable remote member becomes pending; it must not turn the whole command
into HTTP 500 or protect healthy local views from closure.

## Hidden initialization and recovery

Use hidden prewarm only when requested:

~~~text
tb team init optimate --wait --json
tb team status optimate --json
~~~

If initialization returns `attention-required`, present the sanitized choices
and submit exactly the user's decision:

~~~text
tb team init-respond optimate OPERATION_ID --choice CHOICE --wait --json
~~~

For one managed member, resolve its canonical session reference and prefer:

~~~text
tb session resume CANONICAL_REF --no-attach --no-replay
~~~

A live member is kept; a stopped or missing named member is restored from the
canonical Team definition. Never reconstruct provider commands from provider
files or terminal text.

Use `--retry-failed` for failed initialization members. Preview cleanup before
`--apply`; reused sessions never belong to an older failed operation. Treat an
ambiguous submit as potentially delivered and do not replay non-idempotent
input without explicit approval.

## Messaging boundary

Use `tb team submit` for trusted terminal/provider input. Use `tb team
dispatch` or the member MCP skill for untrusted TeamRelay messages. Omit the
delivery policy for ordinary `submit-when-human-idle`; request
`interrupt-and-submit` only after explicit user approval. Never emulate a
semantic policy with raw Enter, Tab, or Escape input.

## Completion checklist

- exact Team name, revision, selected/default view, and visible-start command;
- each owned member's local/paired runtime selector and lifecycle outcome;
- each linked canonical address and current capability/reachability state;
- operation id and per-member readiness/attention state when applicable;
- no identity PIN, bearer token, invitation, secret environment value, or
  prompt body in the handoff.

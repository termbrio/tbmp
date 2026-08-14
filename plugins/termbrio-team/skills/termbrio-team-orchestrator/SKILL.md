---
name: termbrio-team-orchestrator
description: Build, edit, validate, place, initialize, recover, start, hide, stop, and hand off server-owned Termbrio AI-agent teams through tb CLI and the team schema, including teams whose definitions, member runtimes, and TeamRelay routes span paired Servers. Use only when the user explicitly asks to define, manage, launch, place, federate, or orchestrate a team, or assigns the Team Orchestrator role. Do not use merely because the current process is a team member or for ordinary TeamRelay inbox/messaging; use termbrio-team-agent for member messaging.
---

# Termbrio Team Orchestrator

Manage canonical team definitions and lifecycle through non-interactive `tb` CLI commands backed by Termbrio.Server. Keep this role separate from TeamRelay member messaging, which remains MCP-based.

## Establish the Contract

1. Run `tb --version --json`, then `tb team --help` and `tb team schema --json`. Require Termbrio 0.5.9 or newer for the sole schema-6 Team definition, named views, persistent linked agents, owner-controlled remote placement, one-hop linked visibility, and lifecycle/view separation. Reject every root Team version other than `6`; do not migrate or author compatibility files.
2. Run `tb team layouts --json` before choosing a launcher. Read the schema's pattern and slot enums for authoring; renderer discovery reports launcher availability, not the Team layout catalog.
3. Use `--json` for automation-facing discovery, mutation, and status operations. Read the stable envelope code and process exit code; do not parse human tables or prose errors.
4. Treat the server-provided schema as the canonical file contract. A template or help surface that emits fields rejected by that schema is a product mismatch: report it and stop instead of copying stale fields.

Never inspect Termbrio databases or source code to reconstruct a team or identity. Never request, read, print, or copy a member's `AGENT_IDENTITY` or `AGENT_PIN` for management.

## Use the First-Team Fast Path

- If the user already supplied member names, working directories, conversation intent, and layout placement, preserve those decisions. Do not rediscover them from databases, source code, provider history, or unrelated team files.
- For a multi-member team, prefer one portable schema-6 file over a long sequence of atomic edits. Author only `version`, `team`, optional `defaultView`, `workspaces`, `agents`, `linkedAgents`, and `views` as advertised by `tb team schema --json`, then run `tb team validate FILE --json`. Import does not start anything; after import use `tb team start TEAM --view VIEW --dry-run --json` for a revision-bound resolved plan.
- Map an explicitly existing conversation to `resume` and an explicitly new persistent member to `create-once`. Ask only when that material intent is genuinely unknown; do not silently turn a missing resume target into a new conversation.
- Import the validated definition and verify it with `tb team show TEAM --json`. If the user asked only to define, update, or import the team, stop there. Never infer permission to run `init` or `start`.
- Ask for user input only for a decision that changes the result materially, such as resume versus create, destructive replacement after a revision conflict, or hidden initialization versus visible start.

Read the First Team section in [references/orchestration-workflows.md](references/orchestration-workflows.md) for the compact file workflow and completion checklist.

## Choose an Editing Workflow

- Use atomic `tb team edit TEAM ...` commands for a small change, or export/edit/validate/import for several related fields.
- Treat `create`, `edit`, `import`, and editor save as definition-only operations. They never initialize or start sessions.
- Do not use or recreate `team apply`.
- Do not invoke or emulate Team-file migration. Older root versions are unsupported input; create a reviewed schema-6 file and import it explicitly.

Read [references/orchestration-workflows.md](references/orchestration-workflows.md) for concrete CLI sequences and recovery choices.

## Place Members Across Servers

- Keep one canonical team definition on its Owner Server. A member may run locally or on a paired Runtime Server; do not copy the canonical definition into an independent second team merely to place one runtime remotely.
- Treat the paired Runtime Server as the physical terminal and SessionHost host only. The Owner Server remains the lifecycle, readiness, TeamRelay, and delivery-policy authority for an owner-controlled placed member.
- Begin with `tb pair list`, `tb pair show PAIR`, `tb pair test PAIR`, and `tb federation status --json` on participating Servers. Pair aliases are authoring selectors; ServerIds, trusted-client grants, and tokens remain Server-owned authority and never enter Team YAML.
- Define remote paths once under `workspaces`: set `peer: PAIR` and use the path as seen on that remote machine. On the owned member set `workspace: WORKSPACE_KEY`, `runtime.server: PAIR`, and `runtime.lifecycleAuthority: team-owner`. The current schema supports no other lifecycle authority.
- Treat `linkedAgents` as persistent canonical Team references. Each entry has a local `id` and an exact external `agent: team/member@pair`; it may be placed in views as `link:ID` but never receives create, initialize, resume, stop, workspace, or assistant policy from the linking Team.
- A direct `[team/]member@pair` message remains routed addressing and does not by itself create a link. Do not confuse that fact with an explicitly authored `linkedAgents` entry.
- Use the authority already established by the reviewed pairing. Create or widen federation grants only when installed status/help explicitly requires it and the user authorized that mutation; never duplicate a working full-access development pair or guess a GrantId.
- Preserve Team/member/owner/runtime UUIDs returned by Server responses when diagnosing or granting authority, but do not add them to schema-6 authoring files.
- After mutation, verify `tb team show TEAM --json`, `tb team status TEAM --json`, and `tb federation status --json` on the relevant Servers. Check placement reachability/claim state and `tb federation outbox list --json`; a committed local message does not prove remote acceptance.

Read the Remote Placement and Relay Federation section in [references/orchestration-workflows.md](references/orchestration-workflows.md) before performing a multi-Server mutation.

## Choose Conversation Provisioning

- Use `assistant.action: resume` for a named existing conversation. Require `conversation`; a missing provider conversation must fail without creating or renaming a fallback.
- Use `create-once` for a new persistent member. The first successful provider initialization creates and renames the conversation; the Server records that provisioning before bootstrap, and later starts resume it.
- Use `create-always` only when the user explicitly wants a fresh conversation after every stop/start, such as an ephemeral reviewer.
- Emit only `assistant.action: resume`, `create-once`, or `create-always`; never emit obsolete lifecycle spellings.
- Preflight must report the expected operational assistant action (`create` or `resume`) before initialization.

## Run the Lifecycle

1. Run zero-side-effect file validation with `tb team validate FILE --json`. After import, run `tb team start TEAM [--view VIEW] --dry-run --json` for semantic resolution against the stored revision. Require every member to use exactly one binding: `session.id` or `session.ref` must resolve an existing session, while `session.name` explicitly permits create/reuse. Never place a UUID in `session.ref`.
2. Save/import it with revision protection.
3. For a stored definition, run `tb team preflight TEAM --json` immediately before initialization and review workspace/session/assistant/bootstrap/layout actions.
4. Choose the lifecycle entry point from the user's visibility intent:
   - For hidden prewarm, run `tb team init TEAM --wait --json`. If detaching, retain the returned operation id.
   - For immediate visibility, run `tb team start TEAM [--view VIEW] --json` on the layout client. A sole view is implicit; several views require `defaultView` or `--view`; `--no-view` is explicit headless lifecycle. Start reconciles every owned member independently, then materializes the selected view without letting one offline member block healthy members or panels.
   - If initialization returns `attention-required`, present the sanitized prompt and advertised choices to the user. Relay only their explicit choice with `tb team init-respond`; never guess, reuse, or broaden an approval.
5. Inspect `tb team status TEAM --json` and the initialization result. For placed members, also inspect placement reachability, claim revision/runtime instance, and the Runtime Server's federation state. Do not infer readiness from quiet terminal output.
6. Use `hide` to close matching local views while leaving sessions alive. Use `stop` to close every local view owned by the canonical Team and independently request stop for every owned member; linked members are never lifecycle targets and an unreachable placed member is a per-member pending outcome, not a global failure.

Do not busy-poll. Use lifecycle wait mode when foreground blocking is intended, or check initialization status after a user prompt or external event. Use the CLI cancellation operation only for explicit cancellation.

## Bootstrap and Recovery

- Bootstrap steps are versioned. Increase the version when changing already-applied steps.
- Choose bootstrap scope independently: `once` for member-lifetime setup, `per-conversation` for one run in every newly created conversation, or `per-start` only when the same conversation must receive the steps after every requested initialization.
- Pair `create-always` with `per-conversation` when each fresh conversation needs the initial task. Do not leave an ephemeral reviewer with one-time bootstrap unless that asymmetry is intentional.
- Prefer `wait-for input-ready` between task inputs where readiness matters. Provider create/rename is managed before bootstrap.
- Use `--retry-failed` to retry recorded failures without replaying successful steps.
- Treat an `ambiguous` submit/command as potentially delivered. Inspect the terminal before using `--reinitialize-bootstrap`, because reset may replay non-idempotent input.
- Preview failed-operation cleanup with `tb team init-cleanup TEAM OPERATION_ID --json`; apply only the reviewed operation-owned cleanup with `--apply --json`. Never add `--force` without explicit destructive intent.
- To restore one managed member outside full-team initialization, resolve its `canonicalRef` and run `tb session resume CANONICAL_REF --no-attach --no-replay`. A live ready member is kept and needs no readiness work. A live but not-ready member is kept without relaunch and queues readiness work. A stopped or not-yet-materialized named member is prepared from its team definition and queues create/resume readiness in the background.
- Never reconstruct a Codex or Claude conversation command from provider files. If the server reports a stale, changed, or ambiguous binding, run the advertised member-scoped `tb team init TEAM --member MEMBER --wait` recovery instead.
- A successful explicit Team stop abandons an incomplete `create-once` attempt that has no real provider conversation identity, so the next start creates again. Do not reset the database or recreate the assistant solely for that stopped attempt. If `create-submitted` remains after a successful stop on the current product, preserve the terminal for inspection and report the exact member status as a product defect.
- Keep initial task submission as terminal input. TeamRelay dispatch is a separate communication operation.
- For `tb team dispatch`, omit `--delivery` unless the orchestration task explicitly requires different timing; omission uses `submit-when-human-idle`. Use only installed semantic policies and never translate them into provider keys. Request `interrupt-and-submit` only after explicit user approval. Codex supports all four policies; Claude supports safe submit, active-turn submit, and Tab-backed after-turn queue. Inspect visible fallback and audit fields instead of assuming the requested policy executed.
- Use `[team/]member@pair` only when the message must be routed through a named outbound peer. A remote address selects transport; it does not transfer team ownership or create a member definition.
- Treat `*` as the caller's primary Team member set. It does not expand into linked teams; name an authorized linked recipient explicitly with its canonical address.
- Use team status and provider-hook evidence for lifecycle/readiness. Never substitute `team_read_screen` for readiness checks or poll teammate screens; explicit on-demand screen inspection belongs to the TeamRelay member skill.

## Provider Permissions

- Keep `assistant.permissions.mode: default` unless the user asks to pin a member's autonomy independently of provider configuration.
- Use `prompt`, `edit-accepting`, or `read-only` for portable conservative profiles. Codex maps them to explicit sandbox/approval pairs; Claude maps them to `manual`, `acceptEdits`, and `plan`.
- Use `full-access` only for an explicit user request and an appropriately isolated runtime. It maps to Codex `--dangerously-bypass-approvals-and-sandbox` or Claude `--dangerously-skip-permissions`. The legacy `unrestricted` spelling is input compatibility only; emit `full-access` in new definitions.
- Inspect semantic preflight before saving or initializing: require the normalized mode and exact provider arguments to match intent. The command provider supports only `default`; put its explicit policy in the command definition.
- Never infer full access from requests to initialize, start, automate, or run unattended. Keep raw `assistant.arguments` for provider options outside the typed policy.

## Hand Off

Return the team name, saved revision, selected/default view, each owned member's local or paired runtime selector and lifecycle outcome, each linked canonical address and capability state, initialization operation id/state, per-member reachability/readiness, and the exact visible-start command. Include Server-owned UUIDs only when returned and operationally relevant. Do not include prompt bodies, member identity values, access tokens, or secret environment values.

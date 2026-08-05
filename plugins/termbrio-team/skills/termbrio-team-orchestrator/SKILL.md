---
name: termbrio-team-orchestrator
description: Build, edit, validate, place, initialize, recover, start, hide, stop, and hand off server-owned Termbrio AI-agent teams through tb CLI and the team schema, including teams whose definitions, member runtimes, and TeamRelay routes span paired Servers. Use only when the user explicitly asks to define, manage, launch, place, federate, or orchestrate a team, or assigns the Team Orchestrator role. Do not use merely because the current process is a team member or for ordinary TeamRelay inbox/messaging; use termbrio-team-agent for member messaging.
---

# Termbrio Team Orchestrator

Manage canonical team definitions and lifecycle through non-interactive `tb` CLI commands backed by Termbrio.Server. Keep this role separate from TeamRelay member messaging, which remains MCP-based.

## Establish the Contract

1. Run `tb --version --json`, then `tb team --help`. Require Termbrio 0.5.6 or newer for schema-v4 conversation actions, scoped bootstrap, visible-before-ready start, managed provider-resume, and stable conversation-ID workflow. Require Termbrio 0.5.8 or newer for schema-v5 TeamId/MemberId/OwnerServerId, remote runtime placement, federated TeamRelay routing, and the `tb federation` operator surface. Treat installed-help and capability discovery as a separate guard; the stable `name=tb` field does not relax the version floor. Inspect the installed `schema`, `describe`, and `template` commands before authoring unfamiliar fields.
2. Run `tb team layouts --json` before choosing an explicit layout strategy; use only capability fields reported by the current platform.
3. Use `--json` for automation-facing discovery, mutation, and status operations. Read the stable envelope code and process exit code; do not parse human tables or prose errors.
4. Treat installed CLI help and server-provided schema output as the current contract.

Never inspect Termbrio databases or source code to reconstruct a team or identity. Never request, read, print, or copy a member's `AGENT_IDENTITY` or `AGENT_PIN` for management.

## Use the First-Team Fast Path

- If the user already supplied member names, working directories, conversation intent, and layout placement, preserve those decisions. Do not rediscover them from databases, source code, provider history, or unrelated team files.
- For a multi-member team, prefer one portable current-schema file over a long sequence of atomic edits. Start from `tb team template PROVIDER --json`, preserve or obtain schema-v5 stable identities from the Server, fill every blank `assistant.action`, then run `tb team validate FILE --resolve --json`.
- Map an explicitly existing conversation to `resume` and an explicitly new persistent member to `create-once`. Ask only when that material intent is genuinely unknown; do not silently turn a missing resume target into a new conversation.
- Import the validated definition and verify it with `tb team show TEAM --json`. If the user asked only to define, update, or import the team, stop there. Never infer permission to run `init` or `start`.
- Ask for user input only for a decision that changes the result materially, such as resume versus create, destructive replacement after a revision conflict, or hidden initialization versus visible start.

Read the First Team section in [references/orchestration-workflows.md](references/orchestration-workflows.md) for the compact file workflow and completion checklist.

## Choose an Editing Workflow

- Use atomic `tb team edit TEAM ...` commands for a small change, or export/edit/validate/import for several related fields.
- Treat `create`, `edit`, `import`, and editor save as definition-only operations. They never initialize or start sessions.
- Do not use or recreate `team apply`.

Read [references/orchestration-workflows.md](references/orchestration-workflows.md) for concrete CLI sequences and recovery choices.

## Place Members Across Servers

- Keep one canonical team definition on its Owner Server. A member may run locally or on a paired Runtime Server; do not copy the canonical definition into an independent second team merely to place one runtime remotely.
- Begin with `tb federation status --json` on every participating Server. Record each stable ServerId, outbound peer alias, inbound trusted-client PairingGrantId, peer capabilities, and current grants. Never infer these identities from host names or aliases.
- Require `relay-federation` for remote TeamRelay transport and `team-member-runtime` for delegated member lifecycle. Pairing is directional: every sending Server needs an outbound peer route, and every receiving/runtime Server needs the matching trusted-client grant plus a scoped federation grant.
- Configure a relay grant on the receiving Server for each allowed source-team to target-team path. Address a remote recipient as `[team/]member@pair`; treat this as routing syntax, not a durable linked-member record.
- Configure a runtime grant on the Runtime Server. Scope it to the Owner Server's stable TeamId, the placed stable MemberId, and only the required `ensure`, `initialize`, `status`, and `stop` operations.
- Set the canonical member's `runtime.serverId` to the Runtime Server's stable UUID. Set `runtime.lifecycleAuthority` to `team-owner` only when the Owner Server must run remote init/start/status/stop. Use `runtime-owner` when lifecycle control must remain at the Runtime Server, and do not claim owner-side lifecycle commands will control that member.
- Preserve TeamId, MemberId, OwnerServerId, and runtime ServerId across edits and import/export. Names remain human-facing addresses; stable UUIDs define ownership, placement, grants, and claims.
- After mutation, verify `tb team show TEAM --json`, `tb team status TEAM --json`, and `tb federation status --json` on the relevant Servers. Check placement reachability/claim state and `tb federation outbox list --json`; a committed local message does not prove remote acceptance.

Read the Remote Placement and Relay Federation section in [references/orchestration-workflows.md](references/orchestration-workflows.md) before performing a multi-Server mutation.

## Choose Conversation Provisioning

- Use `assistant.action: resume` for a named existing conversation. Require `conversation`; a missing provider conversation must fail without creating or renaming a fallback.
- Use `create-once` for a new persistent member. The first successful provider initialization creates and renames the conversation; the Server records that provisioning before bootstrap, and later starts resume it.
- Use `create-always` only when the user explicitly wants a fresh conversation after every stop/start, such as an ephemeral reviewer.
- Never emit legacy `assistant.lifecycle` in a new definition. Older `auto` and `create` values migrate to `create-once`; `resume-only` migrates to `resume`.
- Preflight must report the expected operational assistant action (`create` or `resume`) before initialization.

## Run the Lifecycle

1. Run zero-side-effect semantic preflight with `tb team validate FILE --resolve --json`. Require every member to use exactly one binding: `session.id` or `session.ref` must resolve an existing session, while `session.name` explicitly permits create/reuse. Never place a UUID in `session.ref`. For a remote member, also require stable owner/team/member/runtime identities and a compatible lifecycle authority.
2. Save/import it with revision protection.
3. For a stored definition, run `tb team preflight TEAM --json` immediately before initialization and review workspace/session/assistant/bootstrap/layout actions.
4. Choose the lifecycle entry point from the user's visibility intent:
   - For hidden prewarm, run `tb team init TEAM --wait --json`. If detaching, retain the returned operation id.
   - For immediate visibility, run `tb team start TEAM --json` on the layout client. Start materializes member sessions, opens views, and, when readiness work remains, returns the queued background initialization operation without waiting for readiness.
   - If initialization returns `attention-required`, present the sanitized prompt and advertised choices to the user. Relay only their explicit choice with `tb team init-respond`; never guess, reuse, or broaden an approval.
5. Inspect `tb team status TEAM --json` and the initialization result. For placed members, also inspect placement reachability, claim revision/runtime instance, and the Runtime Server's federation state. Do not infer readiness from quiet terminal output.
6. Use `hide` to close local views while leaving sessions alive; use `stop` to stop server sessions.

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
- Keep initial task submission as terminal input. TeamRelay dispatch is a separate communication operation.
- For `tb team dispatch`, omit `--delivery` unless the orchestration task explicitly requires different timing. Use only the installed semantic policies; never translate them into provider keys. `interrupt-and-submit` requires explicit urgent user intent and may be denied by the receiving Server. Treat Codex and Claude capability as recipient-specific: do not assume Claude supports Codex's Tab queue behavior without advertised, tested capability.
- Use `[team/]member@pair` only when the message must be routed through a named outbound peer. A remote address selects transport; it does not transfer team ownership or create a member definition.
- Use team status and provider-hook evidence for lifecycle/readiness. Never substitute `team_read_screen` for readiness checks or poll teammate screens; explicit on-demand screen inspection belongs to the TeamRelay member skill.

## Provider Permissions

- Keep `assistant.permissions.mode: default` unless the user asks to pin a member's autonomy independently of provider configuration.
- Use `prompt`, `edit-accepting`, or `read-only` for portable conservative profiles. Codex maps them to explicit sandbox/approval pairs; Claude maps them to `manual`, `acceptEdits`, and `plan`.
- Use `full-access` only for an explicit user request and an appropriately isolated runtime. It maps to Codex `--dangerously-bypass-approvals-and-sandbox` or Claude `--dangerously-skip-permissions`. The legacy `unrestricted` spelling is input compatibility only; emit `full-access` in new definitions.
- Inspect semantic preflight before saving or initializing: require the normalized mode and exact provider arguments to match intent. The command provider supports only `default`; put its explicit policy in the command definition.
- Never infer full access from requests to initialize, start, automate, or run unattended. Keep raw `assistant.arguments` for provider options outside the typed policy.

## Hand Off

Return the team name, saved revision, Owner ServerId, each placed member's Runtime ServerId and lifecycle authority, initialization operation id/state, per-member reachability/readiness, and the exact visible-start command. Do not include prompt bodies, member identity values, access tokens, or secret environment values.

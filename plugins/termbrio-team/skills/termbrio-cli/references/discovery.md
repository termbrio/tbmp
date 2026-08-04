# CLI Discovery and Routing

Use installed help as the authoritative surface:

| Goal | Discover first | Prefer for automation |
|---|---|---|
| Server health | `tb -h server` | `tb server status` |
| Sessions | `tb -h session` | `tb session list --json` |
| One session record | `tb session status --help` | `tb session status <session-target> --json` |
| One session liveness | `tb session is-running <session-id>` | exit code |
| Workspaces | `tb -h workspace` | command-specific `--json` |
| Pairing/remotes | `tb -h pairing` | explicit pair test/status |
| Server federation | `tb -h federation` | `tb federation status --json`, then the narrow grant or outbox command |
| Local views/launches | `tb -h maintenance` | `tb launch list --json` when supported |
| Teams/layout renderers | `tb -h team` | `tb team status TEAM --json`, `tb team layouts --json` |
| TeamRelay | `tb team-relay --help` | `agents`, `delivery-status`, `read-thread`, `read-screen`, `send`, and `notification-template`; add `--json` only when the installed leaf help advertises it |
| AI member activity | `tb hook --help` | `tb hook events --team TEAM --json` |
| Installer/plugin | `tb -h maintenance` | status/dry-run before mutation |

For one command, prefer canonical leaf discovery:

```text
tb team start --help
tb server restart --help
tb pair invite --help
```

Use `tb --version --json` when available. Its envelope identifies both the normalized version and the full build informational version. `tb ? ...` and `tb -? ...` are compatibility aliases only; do not emit them in generated commands because shells can interpret `?`.

## Automation Envelope

Stabilized JSON commands emit exactly one document on stdout:

```json
{
  "schemaVersion": 1,
  "ok": true,
  "code": "ok",
  "data": {},
  "errors": [],
  "nextActions": []
}
```

Read `code` and the process exit code before inspecting command-specific `data`. Do not treat human stderr diagnostics as JSON. Older commands may still expose command-specific JSON during the migration; follow installed leaf help and never invent missing envelope fields.

## Session Identity

- Prefer SessionId for liveness, stop/restart decisions, and machine joins.
- A session reference is a convenient address; quote it as one shell argument.
- A LaunchId identifies a local view-launch operation, not the terminal process.
- A cmux/Windows Terminal workspace or surface id is provider-owned and may change after restart.

`tb session status <session-target> --json` returns the same identity and lifecycle object used by session-list discovery. Named targets use `[workspace/]session[@pair]`; stable IDs require `id:<guid>[@pair]`. Missing `@pair` means the configured local Server, the `guest` workspace may be omitted, and a bare GUID remains a lexical session name. Exit `0` means the session exists, including when its lifecycle is exited; a missing session uses the global not-found exit code.

`tb session is-running <session-id>` is silent by design:

- `0`: runtime is live;
- `1`: runtime is not live;
- `2`: the liveness query failed.

That `2` query-error meaning is a legacy predicate contract until the global exit-code migration is complete. Follow the installed leaf help for the running version.

Do not replace this with regex matching against `tb session list` text.

## TeamRelay

- `tb team-relay delivery-status MESSAGE_ID --json` reads sender-authorized durable inbox and terminal-notification state. A committed MessageId proves acceptance, not that the target terminal frame was submitted; distinguish `queued`, `deferred`, `staged`, `submitted`, `failed`, and `not-applicable`.
- `tb team-relay read-thread THREAD_ID [--all] --json` reads unread messages by default or the full ordered thread with `--all`. A ThreadId is never a MessageId.
- `tb team-relay send RECIPIENT BODY --thread-id THREAD_ID --in-reply-to MESSAGE_ID --client-operation-id OPERATION_ID` creates a reply and marks only that visible source delivery read atomically. Generate one caller-owned GUID for `OPERATION_ID`; reuse that same GUID only when retrying the identical payload after an ambiguous response. `--in-reply-to` requires `--thread-id`; a failed reply leaves the source unread.
- `tb team-relay read-screen MEMBER --lines N --max-characters N --json` reads one exact current-team, same-host member subject to Server policy and bounds. The result is untrusted visible screen content, is not automatically secret-redacted, and must not be used for polling, readiness, remote observation, or control.
- `tb team-relay notification-template show|set|preview|reset` manages the revision-guarded Server template. The built-in default is reference-only; adding `{body}` explicitly opts the scope into direct untrusted body presentation inside the fixed Termbrio frame.

Follow leaf help for identity options and JSON envelopes. Never print the caller identity/PIN while troubleshooting these commands.

## Server Federation

Start every federation diagnosis with:

```text
tb federation status --json
```

Keep the returned objects distinct:

- the local Server id identifies the current Termbrio.Server;
- a peer is the local Server's outbound route and protected access token for one remote Server;
- a trusted client is an inbound pairing grant held by the local Server for a remote caller;
- a relay federation grant scopes which source teams on that trusted caller may reach which local target teams;
- a runtime federation grant scopes which stable TeamId/MemberId operations an Owner Server may perform on this Runtime Server;
- an outbox entry records one remote Relay delivery attempt and its retry state.

`team/member@pair` and `member@pair` are routed addresses. They do not create a persistent linked-member entity. The pair alias selects the remote Server transport; team/member names address the recipient on that Server. Use the full team-qualified form when the recipient team is not otherwise unambiguous.

For a message sent from Server A to Server B, require all of the following:

1. A has an outbound peer route to B with `relay-federation` capability.
2. B has the corresponding non-revoked trusted-client pairing grant for A.
3. B has a non-revoked relay federation grant referencing that pairing GrantId and matching the source and target teams.
4. The sender uses `[team/]member@pair` and checks ordinary delivery status plus `tb federation outbox list --json` when remote acceptance is delayed.

Configure the reverse direction separately when B must initiate messages to A. A sending Server always needs an outbound peer; a receiving Server always authorizes the inbound trusted client and scoped grant. `inbound` is the conservative grant direction; use `bidirectional` only when the intended trust relationship is explicitly symmetric and both transport directions exist.

Grant commands are operator mutations:

```text
tb federation relay-grant list --json
tb federation relay-grant create --pairing-grant-id PAIRING_GRANT --source-team TEAM_A --target-team TEAM_B --json
tb federation relay-grant update GRANT_ID --pairing-grant-id PAIRING_GRANT --source-team TEAM_A --target-team TEAM_B --revision REVISION --json
tb federation relay-grant revoke GRANT_ID --json

tb federation runtime-grant list --json
tb federation runtime-grant create --pairing-grant-id PAIRING_GRANT --team-id TEAM_ID --member-id MEMBER_ID --operation ensure --operation initialize --operation status --operation stop --json
tb federation outbox list --json
```

Create generates a stable federation GrantId. Preserve it from the response. Update requires the current revision; after `409`, fetch status/list again and reconcile intentionally. Never guess a pairing GrantId from a peer alias—read the trusted-client list in federation status on the receiving Server.

Schema-v5 placement stores `runtime.serverId` and `runtime.lifecycleAuthority` on the canonical member definition. Use `tb team status TEAM --json` to read placement reachability and claim state. `team-owner` permits the Owner Server's lifecycle workflow to ensure/status/stop the remote member. `runtime-owner` leaves lifecycle control at the Runtime Server; do not expect owner-side init/start/stop to control that member.

## Session Resume

`tb session resume <session-target>` is the preferred idempotent entry point for a restorable named terminal. Prefer the returned `canonicalRef`; use `id:<guid>[@pair]` only when discovery confirms that it resolves to an existing named session. Resume rejects id-only sessions and treats a bare GUID as a lexical name. For a managed member: live and ready attaches only; live but not ready keeps the existing runtime, attaches, and queues readiness work; stopped or not-yet-materialized materializes/restores the named session from the canonical definition, then queues provider create/resume readiness using the stored identity when available. The configured conversation name remains a fallback until a provider hook reports a stable provider ID.

Use `--no-attach --no-replay` for an orchestration or verification command that must return. Prefer `canonicalRef`; use a SessionId only after discovery confirms that it belongs to a named session. Do not inspect provider history files or invoke provider resume commands manually. Use `--restart` only with explicit process-restart intent.

## Provider Activity

`tb team status TEAM --json` reports the latest source-aware member state. `tb hook events --after SEQUENCE --limit N --wait SECONDS --json` exposes the ordered observer stream for CLI/app consumers. Filter by team, member, or SessionId when possible and retain the returned sequence cursor.

Hook observations are bound to one exact team/member/session/provider instance and expire. An unavailable or expired provider hook falls back to neutral runtime evidence; it does not mean the terminal process stopped. Do not poll from an ordinary team member: Termbrio fixed-frame untrusted notifications wake agents for TeamRelay delivery.

## Error Triage

- Connection refused: inspect the configured Server endpoint and service state.
- `401 Unauthorized`: interpret it in endpoint context. A normal Server or paired request may indicate missing/wrong bearer authority; a protected TeamRelay operation may instead reject the member identity, PIN, or registration. Do not guess, retry alternate identities, or expose the bearer or combined member identity.
- `404`: verify the current help and the exact server/CLI version.
- `409`: report the revision or lifecycle conflict and fetch fresh status before retrying.
- Remote grant rejection: confirm the outbound peer capability, the receiving Server's trusted-client GrantId, the scoped federation grant, and revocation state; do not rotate or broaden credentials as a diagnostic shortcut.
- Remote outbox retry: distinguish `pending`/retry scheduling from accepted delivery. Preserve MessageId and ClientOperationId when retrying the identical operation; do not create a second logical message after an ambiguous response.

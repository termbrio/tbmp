# AGY plugin projection

Status: development integration; live Team-member acceptance is still pending.

The AGY package is generated from `plugins/termbrio-team`. Shared skills remain
in that one source directory. AGY's manifest, `serverUrl` MCP field, and hook
event layout are packaging translations; Team identity, lifecycle, and Relay
policy remain owned by Termbrio Server.

Build into a new directory outside the shared plugin source:

```powershell
./scripts/build-agy-plugin.ps1 -OutputDirectory E:/scratch/termbrio-team-agy
./scripts/test-agy-plugin.ps1 -OutputParent E:/scratch
agy plugin validate E:/scratch/termbrio-team-agy
```

The scripts support Windows PowerShell 5.1. They do not install, overwrite an
existing output directory, or publish. Generated files are not a second tracked
plugin payload. The package name remains `termbrio-team`.

The generated hooks require a matching development `tbhookemit` build with AGY
support on PATH. Released binaries that only recognize Codex/Claude are not
sufficient. Termbrio 0.5.10 and TBMP 0.4.7 are the minimum versions assigned for this
integration. After the matching preview product is installed, a local package can be
installed explicitly with `agy plugin install <output-directory>`.

The MCP endpoint comes from the shared `.mcp.json`; currently it is the local
Termbrio endpoint. Non-default endpoints and remote-owner credential injection
still need integration acceptance. No credentials are written into this package.

AGY 1.2.7 accepted the generated manifest, three skills, one MCP server, and one
hook group with `agy plugin validate`. Separate TB-session startup reached the
interactive prompt. Neither observation proves TeamRelay registration/message
delivery or managed create-once/resume; those remain live acceptance gates.

The projection follows Google's [plugin format](https://antigravity.google/docs/plugins/),
[MCP configuration](https://antigravity.google/docs/mcp/), and
[hook contract](https://antigravity.google/docs/hooks/). AGY's `PostInvocation`
is not turn completion; the product adapter interprets `Stop` and `fullyIdle`
separately. The hooks report activity and do not output permission decisions.

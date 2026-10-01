#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputParent,
    [string]$RepositoryRoot
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$source = Join-Path $repository 'plugins/termbrio-team'
$stage = Join-Path ([IO.Path]::GetFullPath($OutputParent)) ('agy-plugin-test-' + [Guid]::NewGuid().ToString('N'))
& (Join-Path $PSScriptRoot 'build-agy-plugin.ps1') -RepositoryRoot $repository -OutputDirectory $stage
$manifest = Get-Content -LiteralPath (Join-Path $stage 'plugin.json') -Raw | ConvertFrom-Json
$mcp = Get-Content -LiteralPath (Join-Path $stage 'mcp_config.json') -Raw | ConvertFrom-Json
$hooks = Get-Content -LiteralPath (Join-Path $stage 'hooks.json') -Raw | ConvertFrom-Json
if ($manifest.name -ne 'termbrio-team' -or $mcp.mcpServers.TermbrioTeam.serverUrl -ne 'http://127.0.0.1:56789/mcp') {
    throw 'Shared plugin identity or MCP endpoint was changed.'
}
$activity = $hooks.'termbrio-activity'
if (@($activity.PSObject.Properties).Count -ne 5) { throw 'Expected exactly five AGY hook events.' }
foreach ($event in @('PreInvocation', 'PostInvocation', 'PreToolUse', 'PostToolUse', 'Stop')) {
    $handlers = @($activity.$event)
    if ($event -in @('PreToolUse', 'PostToolUse')) {
        if ($handlers[0].matcher -ne '*') { throw 'Expected all-tool activity matcher.' }
        $handlers = @($handlers[0].hooks)
    }
    if ($handlers.Count -ne 1 -or $handlers[0].command -ne "tbhookemit agy $event" -or $handlers[0].timeout -ne 2) {
        throw "Incorrect AGY hook projection: $event"
    }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $source 'skills') -File -Recurse) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\', '/')
    $copied = Join-Path $stage $relative
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $copied).Hash) {
        throw "Shared skill changed during projection: $relative"
    }
}
$rejected = $false
try { & (Join-Path $PSScriptRoot 'build-agy-plugin.ps1') -RepositoryRoot $repository -OutputDirectory $stage }
catch { $rejected = $true }
if (-not $rejected) { throw 'The builder overwrote an existing output directory.' }
$rejected = $false
try { & (Join-Path $PSScriptRoot 'build-agy-plugin.ps1') -RepositoryRoot $repository -OutputDirectory (Join-Path $source 'must-not-create') }
catch { $rejected = $true }
if (-not $rejected) { throw 'The builder accepted output inside the shared source.' }
Write-Output 'AGY plugin projection tests passed.'

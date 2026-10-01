#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$sourceRoot = Join-Path (Resolve-Path -LiteralPath $RepositoryRoot).Path 'plugins/termbrio-team'
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if ($outputRoot.Equals($sourceRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputRoot.StartsWith($sourceRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Output directory must be outside the shared plugin source.'
}
if (Test-Path -LiteralPath $outputRoot) {
    throw "Output directory must not already exist: $outputRoot"
}

# AGY is a projection of the shared payload, not another source of skills or MCP settings.
$manifest = Get-Content -LiteralPath (Join-Path $sourceRoot 'plugin.json') -Raw | ConvertFrom-Json
$mcp = Get-Content -LiteralPath (Join-Path $sourceRoot '.mcp.json') -Raw | ConvertFrom-Json
$sharedHooks = Get-Content -LiteralPath (Join-Path $sourceRoot 'hooks/hooks.json') -Raw | ConvertFrom-Json
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-PluginJson([string]$Name, $Value) {
    $json = ($Value | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $outputRoot $Name), $json, $utf8)
}

$mcpServers = [ordered]@{}
foreach ($entry in $mcp.mcpServers.PSObject.Properties) {
    if ($entry.Value.type -ne 'http' -or [string]::IsNullOrWhiteSpace($entry.Value.url)) {
        throw "AGY projection expects an HTTP MCP server: $($entry.Name)"
    }
    $mcpServers[$entry.Name] = [ordered]@{ serverUrl = $entry.Value.url }
}

$events = [ordered]@{}
foreach ($eventName in @('PreInvocation', 'PostInvocation', 'PreToolUse', 'PostToolUse', 'Stop')) {
    $handler = [ordered]@{ type = 'command'; command = "tbhookemit agy $eventName"; timeout = 2 }
    if ($eventName -in @('PreToolUse', 'PostToolUse', 'Stop') -and
        $null -eq $sharedHooks.hooks.PSObject.Properties[$eventName]) {
        throw "Shared activity hook is missing: $eventName"
    }
    if ($eventName -in @('PreToolUse', 'PostToolUse')) {
        $events[$eventName] = @([ordered]@{ matcher = '*'; hooks = @($handler) })
    }
    else {
        $events[$eventName] = @($handler)
    }
}

New-Item -ItemType Directory -Path $outputRoot | Out-Null
Write-PluginJson 'plugin.json' ([ordered]@{
    '$schema' = 'https://antigravity.google/schemas/v1/plugin.json'
    name = $manifest.name
    description = $manifest.description
})
Write-PluginJson 'mcp_config.json' ([ordered]@{ mcpServers = $mcpServers })
Write-PluginJson 'hooks.json' ([ordered]@{ 'termbrio-activity' = $events })
Copy-Item -LiteralPath (Join-Path $sourceRoot 'skills') -Destination (Join-Path $outputRoot 'skills') -Recurse
Write-Output "Built AGY plugin projection: $outputRoot"
Write-Output 'Requires a Termbrio/tbhookemit build with AGY provider support. This command does not install or publish it.'

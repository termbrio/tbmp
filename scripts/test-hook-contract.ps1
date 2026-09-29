#Requires -Version 5.1
[CmdletBinding()]
param([string]$RepositoryRoot)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$fixtureParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$fixture = [IO.Path]::GetFullPath((Join-Path $fixtureParent ('tbmp-hook-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $fixture.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped temporary directory.' }
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    foreach ($relative in @('.agents', '.claude-plugin', 'plugins')) {
        Copy-Item -LiteralPath (Join-Path $repository $relative) -Destination (Join-Path $fixture $relative) -Recurse
    }
    $hookFile = Join-Path $fixture 'plugins/termbrio-team/hooks/hooks.json'
    $hooks = Get-Content -LiteralPath $hookFile -Raw | ConvertFrom-Json
    if ($null -eq $hooks.hooks.PSObject.Properties['StopFailure']) { throw 'Baseline StopFailure registration is missing.' }
    $hooks.hooks.PSObject.Properties.Remove('StopFailure')
    $hooks | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $hookFile -Encoding UTF8
    $rejected = $false
    try {
        & (Join-Path $repository 'scripts/validate-termbrio-marketplace.ps1') -RepositoryRoot $fixture
    }
    catch {
        if ($_.Exception.Message -ne 'Required Termbrio activity hook is missing: StopFailure') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Marketplace validation accepted a missing StopFailure hook.' }
    Write-Output 'Hook registration regression passed: missing StopFailure is rejected.'
}
finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    if (-not $resolvedFixture.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path.' }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}

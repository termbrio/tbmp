#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$codexManifestPath = Join-Path $repositoryRoot `
    'plugins\termbrio-team\.codex-plugin\plugin.json'
$claudeManifestPath = Join-Path $repositoryRoot `
    'plugins\termbrio-team\.claude-plugin\plugin.json'
$codexManifest = Get-Content -LiteralPath $codexManifestPath -Raw |
    ConvertFrom-Json
$claudeManifest = Get-Content -LiteralPath $claudeManifestPath -Raw |
    ConvertFrom-Json
$releaseVersion = [string]$claudeManifest.version
$codexBaseVersion = ([string]$codexManifest.version) -replace '\+.*$', ''

if ($codexBaseVersion -ne $releaseVersion) {
    throw 'The test fixture manifests do not share one release version.'
}

$sourceRevision = git -C $repositoryRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $sourceRevision -notmatch '^[0-9a-f]{40}$') {
    throw 'Could not resolve the marketplace source revision.'
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'termbrio-plugin-release-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)

try {
    $eventPath = Join-Path $testRoot 'plugins.json'
    $releaseUrl =
        "https://github.com/termbrio/tbmp/releases/tag/v$releaseVersion"
    & (Join-Path $PSScriptRoot 'export-plugin-release-event.ps1') `
        -CodexManifestPath $codexManifestPath `
        -ClaudeManifestPath $claudeManifestPath `
        -ReleaseVersion $releaseVersion `
        -ReleaseTag "v$releaseVersion" `
        -ReleaseUrl $releaseUrl `
        -SourceRevision $sourceRevision `
        -OutputPath $eventPath `
        -Channel stable `
        -CreatedAt '2026-07-27T00:00:00Z'

    $event = Get-Content -LiteralPath $eventPath -Raw | ConvertFrom-Json
    if ($event.eventKind -ne 'plugins' -or
        $event.source.repository -ne 'termbrio/tbmp' -or
        $event.source.tag -ne "v$releaseVersion" -or
        $event.releaseUrl -ne $releaseUrl -or
        $event.plugins.releaseVersion -ne $releaseVersion -or
        $event.plugins.codexVersion -ne [string]$codexManifest.version -or
        $event.plugins.claudeVersion -ne $releaseVersion) {
        throw 'The exported plugin release event does not match the contract.'
    }

    $versionParts = $releaseVersion.Split('-')[0].Split('.')
    $mismatchedVersion = '{0}.{1}.{2}' -f @(
        $versionParts[0],
        $versionParts[1],
        ([int]$versionParts[2] + 1))
    $mismatchRejected = $false
    try {
        & (Join-Path $PSScriptRoot 'export-plugin-release-event.ps1') `
            -CodexManifestPath $codexManifestPath `
            -ClaudeManifestPath $claudeManifestPath `
            -ReleaseVersion $mismatchedVersion `
            -SourceRevision $sourceRevision `
            -OutputPath (Join-Path $testRoot 'invalid.json')
    }
    catch {
        $mismatchRejected = $true
    }

    if (-not $mismatchRejected) {
        throw 'A release version that differs from the manifests was accepted.'
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'Plugin release contract tests passed.'

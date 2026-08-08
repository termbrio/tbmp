#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helpersPath = Join-Path $PSScriptRoot 'plugin-release-workflow-helpers.ps1'
$testRoot = Join-Path `
    ([IO.Path]::GetTempPath()) `
    "termbrio-plugin-workflow-$([Guid]::NewGuid().ToString('N'))"
$revision = '0123456789abcdef0123456789abcdef01234567'

. $helpersPath

function Assert-Throws {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        & $Action
    }
    catch {
        return
    }

    throw $Message
}

try {
    [void](New-Item -ItemType Directory -Force -Path $testRoot)
    if ((Get-TermbrioSourceTagDisposition `
            -ExpectedRevision $revision `
            -ExistingRevision '') -ne 'create') {
        throw 'Absent plugin source tag did not select create.'
    }
    if ((Get-TermbrioSourceTagDisposition `
            -ExpectedRevision $revision `
            -ExistingRevision $revision) -ne 'verify') {
        throw 'Matching plugin source tag did not select verify.'
    }
    Assert-Throws {
        Get-TermbrioSourceTagDisposition `
            -ExpectedRevision $revision `
            -ExistingRevision ('f' * 40)
    } -Message 'Conflicting plugin source tag unexpectedly passed reconciliation.'

    $entryPath = Join-Path $testRoot '1.2.3.json'
    $entry = [ordered]@{
        schemaVersion = 1
        component = 'plugins'
        version = '1.2.3'
        channel = 'stable'
        status = 'ready'
        summary = 'Ships a predictable plugin release.'
        changes = @(
            [ordered]@{
                type = 'fixed'
                area = 'release'
                text = 'Made plugin release reruns deterministic.'
                providers = @('codex')
            }
        )
    }
    [IO.File]::WriteAllText(
        $entryPath,
        (($entry | ConvertTo-Json -Depth 8) + [Environment]::NewLine),
        [Text.UTF8Encoding]::new($false))
    $firstNotes = New-TermbrioPluginReleaseNotes `
        -ChangelogEntryPath $entryPath `
        -SourceRevision $revision
    $secondNotes = New-TermbrioPluginReleaseNotes `
        -ChangelogEntryPath $entryPath `
        -SourceRevision $revision
    if ($firstNotes -cne $secondNotes -or
        -not $firstNotes.Contains('[codex]') -or
        -not $firstNotes.Contains('Changelog SHA256:')) {
        throw 'Plugin release notes were not deterministic or provider-aware.'
    }

    Write-Host 'Plugin release workflow tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

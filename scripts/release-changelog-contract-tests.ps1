#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$helpersPath = Join-Path $PSScriptRoot 'release-changelog-helpers.ps1'
$selectorPath = Join-Path $PSScriptRoot 'get-ready-plugin-release.ps1'
$testRoot = Join-Path `
    ([IO.Path]::GetTempPath()) `
    "termbrio-plugin-changelog-$([Guid]::NewGuid().ToString('N'))"

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

function Write-Entry {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Entry
    )

    [IO.File]::WriteAllText(
        $Path,
        (($Entry | ConvertTo-Json -Depth 12) + [Environment]::NewLine),
        [Text.UTF8Encoding]::new($false))
}

function New-Entry {
    param(
        [string]$Version = '1.2.3',
        [string]$Status = 'ready'
    )

    $entry = [ordered]@{
        schemaVersion = 1
        component = 'plugins'
        version = $Version
        channel = 'preview'
        status = $Status
        summary = if ($Status -eq 'ready') { 'A tested plugin release.' } else { $null }
        changes = @()
    }
    if ($Status -eq 'ready') {
        $entry.changes = @(
            [ordered]@{
                type = 'changed'
                area = 'team-relay'
                text = 'Aligned agent delivery behavior.'
                providers = @('codex', 'claude')
            }
        )
    }

    return $entry
}

try {
    [void](New-Item -ItemType Directory -Force -Path $testRoot)
    $entryPath = Join-Path $testRoot '1.2.3.json'
    Write-Entry -Path $entryPath -Entry (New-Entry -Status 'draft')

    $draft = Read-TermbrioChangelogEntry `
        -Path $entryPath `
        -ExpectedComponent 'plugins'
    if ([string]$draft.Entry.status -ne 'draft' -or
        [string]$draft.Digest -notmatch '^[0-9a-f]{64}$') {
        throw 'Draft validation or digest generation failed.'
    }

    $selection = & $selectorPath -ChangelogRoot $testRoot |
        ConvertFrom-Json
    if ([bool]$selection.found) {
        throw 'Draft-only plugin changelog unexpectedly selected a release.'
    }

    Write-Entry -Path $entryPath -Entry (New-Entry)
    $selection = & $selectorPath -ChangelogRoot $testRoot |
        ConvertFrom-Json
    if (-not [bool]$selection.found -or
        [string]$selection.version -ne '1.2.3' -or
        [string]$selection.entryDigest -notmatch '^[0-9a-f]{64}$') {
        throw 'Ready plugin changelog was not selected deterministically.'
    }

    $invalidProviders = New-Entry
    $invalidProviders.changes[0].providers = @('codex', 'codex')
    Write-Entry -Path $entryPath -Entry $invalidProviders
    Assert-Throws {
        Read-TermbrioChangelogEntry `
            -Path $entryPath `
            -ExpectedComponent 'plugins'
    } -Message 'Duplicate plugin providers unexpectedly passed validation.'

    Write-Entry -Path $entryPath -Entry (New-Entry)
    Write-Entry `
        -Path (Join-Path $testRoot '2.0.0.json') `
        -Entry (New-Entry -Version '2.0.0')
    Assert-Throws {
        Get-TermbrioReadyChangelogEntry `
            -ChangelogRoot $testRoot `
            -ExpectedComponent 'plugins'
    } -Message 'Multiple ready plugin entries unexpectedly passed selection.'

    Write-Host 'Plugin changelog contract tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

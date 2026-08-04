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

function Invoke-TestGit {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = @(& git -C $RepositoryRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }

    return $output
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
    [void](Invoke-TestGit -RepositoryRoot $testRoot -Arguments @('init', '-q'))
    [void](Invoke-TestGit -RepositoryRoot $testRoot -Arguments @('config', 'user.name', 'Termbrio Tests'))
    [void](Invoke-TestGit -RepositoryRoot $testRoot -Arguments @('config', 'user.email', 'tests@termbrio.local'))
    $entryPath = Join-Path $testRoot '1.2.3.json'
    Write-Entry -Path $entryPath -Entry (New-Entry -Status 'draft')

    $draft = Read-TermbrioChangelogEntry `
        -Path $entryPath `
        -ExpectedComponent 'plugins'
    if ([string]$draft.Entry.status -ne 'draft' -or
        [string]$draft.Digest -notmatch '^[0-9a-f]{64}$') {
        throw 'Draft validation or digest generation failed.'
    }

    $selection = & $selectorPath `
        -ChangelogRoot $testRoot `
        -RepositoryRoot $testRoot |
        ConvertFrom-Json
    if ([bool]$selection.found) {
        throw 'Draft-only plugin changelog unexpectedly selected a release.'
    }

    Write-Entry -Path $entryPath -Entry (New-Entry)
    $selection = & $selectorPath `
        -ChangelogRoot $testRoot `
        -RepositoryRoot $testRoot |
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

    $stringSchemaVersion = New-Entry
    $stringSchemaVersion.schemaVersion = '1'
    Write-Entry -Path $entryPath -Entry $stringSchemaVersion
    Assert-Throws {
        Read-TermbrioChangelogEntry `
            -Path $entryPath `
            -ExpectedComponent 'plugins'
    } -Message 'String schemaVersion unexpectedly passed plugin validation.'

    $booleanSchemaVersion = New-Entry
    $booleanSchemaVersion.schemaVersion = $true
    Write-Entry -Path $entryPath -Entry $booleanSchemaVersion
    Assert-Throws {
        Read-TermbrioChangelogEntry `
            -Path $entryPath `
            -ExpectedComponent 'plugins'
    } -Message 'Boolean schemaVersion unexpectedly passed plugin validation.'

    $numericChangeText = New-Entry
    $numericChangeText.changes[0].text = 42
    Write-Entry -Path $entryPath -Entry $numericChangeText
    Assert-Throws {
        Read-TermbrioChangelogEntry `
            -Path $entryPath `
            -ExpectedComponent 'plugins'
    } -Message 'Numeric plugin changelog text unexpectedly passed validation.'

    Write-Entry -Path $entryPath -Entry (New-Entry)
    Write-Entry `
        -Path (Join-Path $testRoot '2.0.0.json') `
        -Entry (New-Entry -Version '2.0.0')
    Assert-Throws {
        Get-TermbrioReadyChangelogEntry `
            -ChangelogRoot $testRoot `
            -ExpectedComponent 'plugins'
    } -Message 'Multiple ready plugin entries unexpectedly passed selection.'

    $selectionRepository = Join-Path $testRoot 'selection-repository'
    $selectionChangelogRoot = Join-Path $selectionRepository 'changelog'
    [void](New-Item -ItemType Directory -Force -Path $selectionChangelogRoot)
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('init', '-q'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('config', 'user.name', 'Termbrio Tests'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('config', 'user.email', 'tests@termbrio.local'))

    $historicalPath = Join-Path $selectionChangelogRoot '1.0.0.json'
    Write-Entry -Path $historicalPath -Entry (New-Entry -Version '1.0.0')
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('add', '--', 'changelog/1.0.0.json'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('commit', '-q', '-m', 'Add historical release'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('tag', 'v1.0.0'))

    $nextPath = Join-Path $selectionChangelogRoot '2.0.0.json'
    Write-Entry -Path $nextPath -Entry (New-Entry -Version '2.0.0')
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('add', '--', 'changelog/2.0.0.json'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('commit', '-q', '-m', 'Add next release'))
    $nextSelection = Get-TermbrioReadyChangelogEntry `
        -ChangelogRoot $selectionChangelogRoot `
        -ExpectedComponent 'plugins' `
        -RepositoryRoot $selectionRepository `
        -IntegratedRevision 'HEAD'
    if ([string]$nextSelection.Entry.version -ne '2.0.0') {
        throw 'Historical published ready entry blocked the next plugin release.'
    }

    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('tag', 'v2.0.0'))
    $currentTagRetrySelection = Get-TermbrioReadyChangelogEntry `
        -ChangelogRoot $selectionChangelogRoot `
        -ExpectedComponent 'plugins' `
        -RepositoryRoot $selectionRepository `
        -IntegratedRevision 'HEAD'
    if ([string]$currentTagRetrySelection.Entry.version -ne '2.0.0') {
        throw 'Exact current plugin tag did not remain eligible for a targeted rerun.'
    }
    [IO.File]::WriteAllText(
        (Join-Path $selectionRepository 'after-release.txt'),
        'later integrated change',
        [Text.UTF8Encoding]::new($false))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('add', '--', 'after-release.txt'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('commit', '-q', '-m', 'Advance after release'))
    $publishedOnlySelection = Get-TermbrioReadyChangelogEntry `
        -ChangelogRoot $selectionChangelogRoot `
        -ExpectedComponent 'plugins' `
        -RepositoryRoot $selectionRepository `
        -IntegratedRevision 'HEAD'
    if ($null -ne $publishedOnlySelection) {
        throw 'Historical-only plugin changelog selected a new release.'
    }

    Write-Entry `
        -Path (Join-Path $selectionChangelogRoot '3.0.0.json') `
        -Entry (New-Entry -Version '3.0.0')
    Write-Entry `
        -Path (Join-Path $selectionChangelogRoot '4.0.0.json') `
        -Entry (New-Entry -Version '4.0.0')
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('add', '--', 'changelog/3.0.0.json', 'changelog/4.0.0.json'))
    [void](Invoke-TestGit -RepositoryRoot $selectionRepository -Arguments @('commit', '-q', '-m', 'Add ambiguous releases'))
    Assert-Throws {
        Get-TermbrioReadyChangelogEntry `
            -ChangelogRoot $selectionChangelogRoot `
            -ExpectedComponent 'plugins' `
            -RepositoryRoot $selectionRepository `
            -IntegratedRevision 'HEAD'
    } -Message 'Two unpublished ready plugin entries unexpectedly passed selection.'

    $changedRepository = Join-Path $testRoot 'changed-repository'
    $changedChangelogRoot = Join-Path $changedRepository 'changelog'
    [void](New-Item -ItemType Directory -Force -Path $changedChangelogRoot)
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('init', '-q'))
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('config', 'user.name', 'Termbrio Tests'))
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('config', 'user.email', 'tests@termbrio.local'))
    $changedPath = Join-Path $changedChangelogRoot '5.0.0.json'
    Write-Entry -Path $changedPath -Entry (New-Entry -Version '5.0.0')
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('add', '--', 'changelog/5.0.0.json'))
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('commit', '-q', '-m', 'Add tagged release'))
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('tag', 'v5.0.0'))
    $changedEntry = New-Entry -Version '5.0.0'
    $changedEntry.changes[0].text = 'Changed after publication.'
    Write-Entry -Path $changedPath -Entry $changedEntry
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('add', '--', 'changelog/5.0.0.json'))
    [void](Invoke-TestGit -RepositoryRoot $changedRepository -Arguments @('commit', '-q', '-m', 'Change tagged release'))
    Assert-Throws {
        Get-TermbrioReadyChangelogEntry `
            -ChangelogRoot $changedChangelogRoot `
            -ExpectedComponent 'plugins' `
            -RepositoryRoot $changedRepository `
            -IntegratedRevision 'HEAD'
    } -Message 'Changed blob under an existing plugin tag unexpectedly passed selection.'

    Write-Host 'Plugin changelog contract tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

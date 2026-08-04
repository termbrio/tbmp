#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ChangelogRoot,

    [string]$OutputPath,

    [string]$RepositoryRoot,

    [string]$IntegratedRevision = 'HEAD'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'release-changelog-helpers.ps1')

if ([string]::IsNullOrWhiteSpace($ChangelogRoot)) {
    $ChangelogRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'changelog'
}
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$selected = Get-TermbrioReadyChangelogEntry `
    -ChangelogRoot $ChangelogRoot `
    -ExpectedComponent 'plugins' `
    -RepositoryRoot $RepositoryRoot `
    -IntegratedRevision $IntegratedRevision

$result = if ($null -eq $selected) {
    [ordered]@{
        schemaVersion = 1
        found = $false
    }
}
else {
    [ordered]@{
        schemaVersion = 1
        found = $true
        path = [IO.Path]::GetFullPath([string]$selected.Path)
        entryDigest = [string]$selected.Digest
        version = [string]$selected.Entry.version
        channel = [string]$selected.Entry.channel
        summary = [string]$selected.Entry.summary
        changes = @($selected.Entry.changes)
    }
}

$json = $result | ConvertTo-Json -Depth 12
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [void](New-Item -ItemType Directory -Force -Path $parent)
    }
    [IO.File]::WriteAllText(
        $OutputPath,
        $json.TrimEnd() + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false))
}

$json

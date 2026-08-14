#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workflowPath = Join-Path $repoRoot '.github\workflows\release-projection.yml'
$workflow = Get-Content -LiteralPath $workflowPath -Raw
$validationWorkflowPath = Join-Path $repoRoot '.github\workflows\validate.yml'
$validationWorkflow = Get-Content -LiteralPath $validationWorkflowPath -Raw

function Assert-Contains {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $workflow.Contains($Pattern)) {
        throw $Message
    }
}

Assert-Contains `
    -Pattern 'workflow_run:' `
    -Message 'Plugin release is not gated by completed validation.'
Assert-Contains `
    -Pattern "github.event.workflow_run.conclusion == 'success'" `
    -Message 'Plugin release does not require successful validation.'
Assert-Contains `
    -Pattern 'SOURCE_REVISION: ${{ github.event.workflow_run.head_sha }}' `
    -Message 'Plugin release is not bound to the successful main revision.'
Assert-Contains `
    -Pattern 'ref: ${{ env.SOURCE_REVISION }}' `
    -Message 'Plugin checkout does not use the successful main revision.'
Assert-Contains `
    -Pattern './tbmp/scripts/get-ready-plugin-release.ps1' `
    -Message 'Plugin release does not select the validated ready entry.'
Assert-Contains `
    -Pattern 'reason=already-published' `
    -Message 'Published plugin entries do not produce an explicit no-op.'
Assert-Contains `
    -Pattern 'git -C ./tbmp hash-object $relativeEntryPath' `
    -Message 'Plugin no-op is not bound to identical changelog bytes.'
Assert-Contains `
    -Pattern '--changelog-output ./out/projected/catalog/changelog.json' `
    -Message 'Plugin preflight does not project the changelog ledger.'
Assert-Contains `
    -Pattern 'retention-days: 14' `
    -Message 'Plugin pre-publication evidence retention is too short.'

if (-not $validationWorkflow.Contains('fetch-depth: 0')) {
    throw 'Marketplace validation must fetch tags for historical ready-entry selection.'
}

$tagIndex = $workflow.IndexOf('- name: Create or verify plugin source tag')
$releaseIndex = $workflow.IndexOf('- name: Publish or verify plugin release record')
$dispatchIndex = $workflow.IndexOf('- name: Dispatch published plugin event')
if ($tagIndex -lt 0 -or
    $releaseIndex -le $tagIndex -or
    $dispatchIndex -le $releaseIndex) {
    throw 'Plugin release order must be source tag, release record, then dispatch.'
}

foreach ($forbidden in @(
    'gh run watch',
    'Start-Sleep',
    'while ($true)',
    'workflow_dispatch:',
    'push:'
)) {
    if ($workflow.Contains($forbidden)) {
        throw "Plugin release contains forbidden trigger or babysitting behavior: $forbidden"
    }
}

Write-Host 'Plugin release workflow policy tests passed.'

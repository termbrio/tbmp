#Requires -Version 5.1

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'release-changelog-helpers.ps1')

function Get-TermbrioSourceTagDisposition {
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedRevision,

        [AllowEmptyString()]
        [string]$ExistingRevision
    )

    if ($ExpectedRevision -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'Expected source-tag revision must be a full Git commit.'
    }
    if ([string]::IsNullOrWhiteSpace($ExistingRevision)) {
        return 'create'
    }
    if ($ExistingRevision -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'Existing source-tag revision must be a full Git commit.'
    }
    if ($ExistingRevision -ne $ExpectedRevision) {
        throw "Source tag resolves to '$ExistingRevision', expected '$ExpectedRevision'."
    }

    return 'verify'
}

function New-TermbrioPluginReleaseNotes {
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogEntryPath,

        [Parameter(Mandatory)]
        [string]$SourceRevision
    )

    if ($SourceRevision -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'Release notes source revision must be a full Git commit.'
    }

    $validated = Read-TermbrioChangelogEntry `
        -Path $ChangelogEntryPath `
        -ExpectedComponent 'plugins'
    $entry = $validated.Entry
    if ([string]$entry.status -ne 'ready') {
        throw 'Release notes require a ready plugin changelog entry.'
    }

    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add([string]$entry.summary)
    $lines.Add('')
    $lines.Add('## Changes')
    $lines.Add('')
    foreach ($change in @($entry.changes)) {
        $type = ([string]$change.type).Substring(0, 1).ToUpperInvariant() +
            ([string]$change.type).Substring(1)
        $providers = if ($null -ne $change.PSObject.Properties['providers']) {
            " [$(@($change.providers) -join ', ')]"
        }
        else {
            ''
        }
        $lines.Add("- $type ($([string]$change.area))$providers`: $([string]$change.text)")
    }
    $lines.Add('')
    $lines.Add('## Provenance')
    $lines.Add('')
    $lines.Add("- Plugin source: termbrio/tbmp@$($SourceRevision.ToLowerInvariant())")
    $lines.Add("- Source tag: v$([string]$entry.version)")
    $lines.Add("- Channel: $([string]$entry.channel)")
    $lines.Add("- Changelog SHA256: $([string]$validated.Digest)")

    return ($lines -join "`n") + "`n"
}

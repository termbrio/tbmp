#Requires -Version 5.1

Set-StrictMode -Version Latest

$script:TermbrioChangelogVersionPattern =
    '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)' +
    '(?:-[0-9A-Za-z.-]+)?$'
$script:TermbrioChangelogComponents = @('product', 'plugins')
$script:TermbrioChangelogChannels = @('pilot', 'preview', 'stable')
$script:TermbrioChangelogStatuses = @('draft', 'ready')
$script:TermbrioChangelogChangeTypes = @(
    'added',
    'changed',
    'fixed',
    'deprecated',
    'removed',
    'security'
)
$script:TermbrioChangelogProviders = @('codex', 'claude')

function Assert-TermbrioChangelogProperties {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string[]]$Allowed,

        [Parameter(Mandatory)]
        [string[]]$Required,

        [Parameter(Mandatory)]
        [string]$Context
    )

    $propertyNames = @($Value.PSObject.Properties.Name)
    foreach ($requiredName in $Required) {
        if ($propertyNames -notcontains $requiredName) {
            throw "$Context is missing required property '$requiredName'."
        }
    }

    $unknownNames = @($propertyNames | Where-Object { $Allowed -notcontains $_ })
    if ($unknownNames.Count -gt 0) {
        throw "$Context contains unsupported properties: $($unknownNames -join ', ')."
    }
}

function Assert-TermbrioChangelogPlainText {
    param(
        [AllowNull()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Context,

        [switch]$AllowNull
    )

    if ($null -eq $Value) {
        if ($AllowNull.IsPresent) {
            return
        }

        throw "$Context must be non-empty plain text."
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Context must be non-empty plain text."
    }

    if ($Value -match '[\r\n<>]') {
        throw "$Context must be single-line plain text without HTML delimiters."
    }
}

function Read-TermbrioChangelogEntry {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('product', 'plugins')]
        [string]$ExpectedComponent
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $item = Get-Item -LiteralPath $resolvedPath
    if ($item.Extension -ne '.json') {
        throw "Changelog entry must be a JSON file: $resolvedPath"
    }

    $raw = Get-Content -LiteralPath $resolvedPath -Raw
    try {
        $entry = $raw | ConvertFrom-Json
    }
    catch {
        throw "Changelog entry is not valid JSON: $resolvedPath"
    }

    Assert-TermbrioChangelogProperties `
        -Value $entry `
        -Allowed @(
            'schemaVersion',
            'component',
            'version',
            'channel',
            'status',
            'summary',
            'changes'
        ) `
        -Required @(
            'schemaVersion',
            'component',
            'version',
            'channel',
            'status',
            'summary',
            'changes'
        ) `
        -Context "Changelog entry '$resolvedPath'"

    if ([int]$entry.schemaVersion -ne 1) {
        throw "Changelog entry schemaVersion must be 1: $resolvedPath"
    }

    $component = [string]$entry.component
    if ($script:TermbrioChangelogComponents -notcontains $component) {
        throw "Changelog entry component is unsupported: $component"
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedComponent) -and
        $component -ne $ExpectedComponent) {
        throw "Changelog entry component must be '$ExpectedComponent': $resolvedPath"
    }

    $version = [string]$entry.version
    if ($version -notmatch $script:TermbrioChangelogVersionPattern) {
        throw "Changelog entry version is not supported: $version"
    }
    if ($item.BaseName -ne $version) {
        throw "Changelog filename '$($item.Name)' does not match version '$version'."
    }

    $channel = [string]$entry.channel
    if ($script:TermbrioChangelogChannels -notcontains $channel) {
        throw "Changelog entry channel is unsupported: $channel"
    }

    $status = [string]$entry.status
    if ($script:TermbrioChangelogStatuses -notcontains $status) {
        throw "Changelog entry status is unsupported: $status"
    }

    $summary = $entry.summary
    if ($null -ne $summary -and $summary -isnot [string]) {
        throw "Changelog entry summary must be plain text or null: $resolvedPath"
    }
    if ($status -eq 'ready') {
        Assert-TermbrioChangelogPlainText `
            -Value ([string]$summary) `
            -Context 'Changelog entry summary'
    }
    elseif ($null -ne $summary) {
        Assert-TermbrioChangelogPlainText `
            -Value ([string]$summary) `
            -Context 'Changelog entry summary'
    }

    if ($null -eq $entry.changes -or $entry.changes -isnot [Array]) {
        throw "Changelog entry changes must be an array: $resolvedPath"
    }
    $changes = @($entry.changes)
    if ($status -eq 'ready' -and $changes.Count -eq 0) {
        throw "Ready changelog entry must contain at least one change: $resolvedPath"
    }

    foreach ($change in $changes) {
        Assert-TermbrioChangelogProperties `
            -Value $change `
            -Allowed @('type', 'area', 'text', 'providers') `
            -Required @('type', 'area', 'text') `
            -Context "Changelog change in '$resolvedPath'"

        $changeType = [string]$change.type
        if ($script:TermbrioChangelogChangeTypes -notcontains $changeType) {
            throw "Changelog change type is unsupported: $changeType"
        }

        $area = [string]$change.area
        if ($area -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
            throw "Changelog change area is invalid: $area"
        }

        Assert-TermbrioChangelogPlainText `
            -Value ([string]$change.text) `
            -Context 'Changelog change text'

        $providersProperty = $change.PSObject.Properties['providers']
        if ($null -eq $providersProperty) {
            continue
        }
        if ($component -ne 'plugins') {
            throw 'Changelog change providers are supported only for plugins.'
        }
        if ($null -eq $change.providers -or
            $change.providers -isnot [Array] -or
            @($change.providers).Count -eq 0) {
            throw 'Plugin changelog change providers must be a non-empty array.'
        }

        $providers = @($change.providers | ForEach-Object { [string]$_ })
        if (@($providers | Select-Object -Unique).Count -ne $providers.Count) {
            throw 'Plugin changelog change providers must be unique.'
        }
        foreach ($provider in $providers) {
            if ($script:TermbrioChangelogProviders -notcontains $provider) {
                throw "Changelog provider is unsupported: $provider"
            }
        }
    }

    return [pscustomobject]@{
        Path = $resolvedPath
        Digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath).
            Hash.ToLowerInvariant()
        Entry = $entry
    }
}

function Get-TermbrioReadyChangelogEntry {
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogRoot,

        [ValidateSet('product', 'plugins')]
        [string]$ExpectedComponent
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $ChangelogRoot).Path
    $validatedEntries = @(
        Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.json' |
            Where-Object { $_.Name -ne 'schema.json' } |
            Sort-Object Name |
            ForEach-Object {
                Read-TermbrioChangelogEntry `
                    -Path $_.FullName `
                    -ExpectedComponent $ExpectedComponent
            }
    )
    $readyEntries = @(
        $validatedEntries |
            Where-Object { [string]$_.Entry.status -eq 'ready' }
    )
    if ($readyEntries.Count -gt 1) {
        $versions = @($readyEntries | ForEach-Object { [string]$_.Entry.version })
        throw "Expected at most one ready $ExpectedComponent changelog entry; found: $($versions -join ', ')."
    }
    if ($readyEntries.Count -eq 0) {
        return $null
    }

    return $readyEntries[0]
}

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

function Test-TermbrioChangelogInteger {
    param(
        [AllowNull()]
        $Value
    )

    return $Value -is [sbyte] -or
        $Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
}

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

    if (-not (Test-TermbrioChangelogInteger -Value $entry.schemaVersion) -or
        [int64]$entry.schemaVersion -ne 1) {
        throw "Changelog entry schemaVersion must be 1: $resolvedPath"
    }

    if ($entry.component -isnot [string]) {
        throw "Changelog entry component must be a string: $resolvedPath"
    }
    $component = $entry.component
    if ($script:TermbrioChangelogComponents -notcontains $component) {
        throw "Changelog entry component is unsupported: $component"
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedComponent) -and
        $component -ne $ExpectedComponent) {
        throw "Changelog entry component must be '$ExpectedComponent': $resolvedPath"
    }

    if ($entry.version -isnot [string]) {
        throw "Changelog entry version must be a string: $resolvedPath"
    }
    $version = $entry.version
    if ($version -notmatch $script:TermbrioChangelogVersionPattern) {
        throw "Changelog entry version is not supported: $version"
    }
    if ($item.BaseName -ne $version) {
        throw "Changelog filename '$($item.Name)' does not match version '$version'."
    }

    if ($entry.channel -isnot [string]) {
        throw "Changelog entry channel must be a string: $resolvedPath"
    }
    $channel = $entry.channel
    if ($script:TermbrioChangelogChannels -notcontains $channel) {
        throw "Changelog entry channel is unsupported: $channel"
    }

    if ($entry.status -isnot [string]) {
        throw "Changelog entry status must be a string: $resolvedPath"
    }
    $status = $entry.status
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

        if ($change.type -isnot [string]) {
            throw "Changelog change type must be a string: $resolvedPath"
        }
        $changeType = $change.type
        if ($script:TermbrioChangelogChangeTypes -notcontains $changeType) {
            throw "Changelog change type is unsupported: $changeType"
        }

        if ($change.area -isnot [string]) {
            throw "Changelog change area must be a string: $resolvedPath"
        }
        $area = $change.area
        if ($area -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
            throw "Changelog change area is invalid: $area"
        }

        if ($change.text -isnot [string]) {
            throw "Changelog change text must be a string: $resolvedPath"
        }
        Assert-TermbrioChangelogPlainText `
            -Value $change.text `
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

        $providers = @($change.providers)
        if (@($providers | Where-Object { $_ -isnot [string] }).Count -gt 0) {
            throw 'Plugin changelog change providers must contain only strings.'
        }
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

function Test-TermbrioHistoricalPublishedReadyChangelogEntry {
    param(
        [Parameter(Mandatory)]
        $ValidatedEntry,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$IntegratedRevision
    )

    $resolvedRepository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    $workTreeResult = @(
        & git -C $resolvedRepository rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or
        ([string]($workTreeResult -join '')).Trim() -ne 'true') {
        throw "Repository root is not a Git worktree: $resolvedRepository"
    }
    $separatorCharacters = [char[]]@(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar)
    $repositoryPrefix =
        $resolvedRepository.TrimEnd($separatorCharacters) +
        [IO.Path]::DirectorySeparatorChar
    $entryPath = [IO.Path]::GetFullPath([string]$ValidatedEntry.Path)
    if (-not $entryPath.StartsWith(
            $repositoryPrefix,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Changelog entry is outside repository root: $entryPath"
    }

    $relativeEntryPath = $entryPath.
        Substring($repositoryPrefix.Length).
        Replace([IO.Path]::DirectorySeparatorChar, '/')
    $version = [string]$ValidatedEntry.Entry.version
    $sourceTag = "v$version"
    & git -C $resolvedRepository show-ref `
        --verify `
        --quiet `
        "refs/tags/$sourceTag"
    $tagReferenceExitCode = $LASTEXITCODE
    if ($tagReferenceExitCode -eq 1) {
        $global:LASTEXITCODE = 0
        return $false
    }
    if ($tagReferenceExitCode -ne 0) {
        throw "Unable to inspect source tag $sourceTag."
    }

    $tagRevisionOutput = @(
        & git -C $resolvedRepository rev-list -n 1 $sourceTag 2>$null)
    $tagExitCode = $LASTEXITCODE
    if ($tagExitCode -ne 0) {
        throw "Existing source tag $sourceTag did not resolve to a commit."
    }

    $tagRevision = ([string]($tagRevisionOutput -join '')).Trim()
    if ($tagRevision -notmatch '^[0-9a-fA-F]{40}$') {
        throw "Existing source tag $sourceTag did not resolve to a commit."
    }

    $integratedRevisionOutput = @(
        & git -C $resolvedRepository rev-parse `
            "$IntegratedRevision^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Integrated revision did not resolve to a commit: $IntegratedRevision"
    }
    $integratedRevisionHash =
        ([string]($integratedRevisionOutput -join '')).Trim()

    & git -C $resolvedRepository merge-base --is-ancestor `
        $tagRevision `
        $integratedRevisionHash
    if ($LASTEXITCODE -ne 0) {
        throw "Existing source tag $sourceTag is not integrated into $IntegratedRevision."
    }

    $taggedBlobOutput = @(
        & git -C $resolvedRepository rev-parse `
            "$sourceTag`:$relativeEntryPath" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Existing source tag $sourceTag does not contain $relativeEntryPath."
    }
    $taggedBlob = ([string]($taggedBlobOutput -join '')).Trim()

    $currentBlobOutput = @(
        & git -C $resolvedRepository hash-object -- $relativeEntryPath)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to hash current changelog entry $relativeEntryPath."
    }
    $currentBlob = ([string]($currentBlobOutput -join '')).Trim()
    if ($taggedBlob -ne $currentBlob) {
        throw "Ready changelog entry $relativeEntryPath changed after $sourceTag was created."
    }

    return $tagRevision -ne $integratedRevisionHash
}

function Get-TermbrioReadyChangelogEntry {
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogRoot,

        [ValidateSet('product', 'plugins')]
        [string]$ExpectedComponent,

        [string]$RepositoryRoot,

        [string]$IntegratedRevision = 'HEAD'
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
    $unpublishedEntries = @(
        if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
            $readyEntries
        }
        else {
            $readyEntries | Where-Object {
                -not (Test-TermbrioHistoricalPublishedReadyChangelogEntry `
                    -ValidatedEntry $_ `
                    -RepositoryRoot $RepositoryRoot `
                    -IntegratedRevision $IntegratedRevision)
            }
        }
    )
    if ($unpublishedEntries.Count -gt 1) {
        $versions = @(
            $unpublishedEntries |
                ForEach-Object { [string]$_.Entry.version })
        throw "Expected at most one unpublished ready $ExpectedComponent changelog entry; found: $($versions -join ', ')."
    }
    if ($unpublishedEntries.Count -eq 0) {
        return $null
    }

    return $unpublishedEntries[0]
}

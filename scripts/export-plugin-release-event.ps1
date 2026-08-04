#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CodexManifestPath,

    [Parameter(Mandatory)]
    [string]$ClaudeManifestPath,

    [Parameter(Mandatory)]
    [string]$SourceRevision,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [string]$ChangelogEntryPath,

    [ValidateSet('pilot', 'preview', 'stable')]
    [string]$Channel = 'pilot',

    [Parameter(Mandatory)]
    [string]$ReleaseVersion,

    [string]$ReleaseTag,

    [string]$ReleaseUrl,

    [string]$CreatedAt = [DateTimeOffset]::UtcNow.ToString('o')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'release-changelog-helpers.ps1')

if ($SourceRevision -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'SourceRevision must be a full Git commit revision.'
}

$codexManifest = Get-Content -LiteralPath $CodexManifestPath -Raw |
    ConvertFrom-Json
$claudeManifest = Get-Content -LiteralPath $ClaudeManifestPath -Raw |
    ConvertFrom-Json
$codexVersion = [string]$codexManifest.version
$claudeVersion = [string]$claudeManifest.version

$versionPattern =
    '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)' +
    '(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'
foreach ($version in @($codexVersion, $claudeVersion)) {
    if ($version -notmatch $versionPattern) {
        throw "Plugin manifest contains an invalid semantic version: $version"
    }
}

if ($ReleaseVersion -notmatch $versionPattern -or
    $ReleaseVersion.Contains('+')) {
    throw 'ReleaseVersion must be a semantic version without build metadata.'
}

$codexBaseVersion = $codexVersion -replace '\+.*$', ''
if ($codexBaseVersion -ne $ReleaseVersion -or
    $claudeVersion -ne $ReleaseVersion) {
    throw (
        "ReleaseVersion '$ReleaseVersion' must match the Codex base version " +
        "'$codexBaseVersion' and Claude version '$claudeVersion'.")
}

$changelog = Read-TermbrioChangelogEntry `
    -Path $ChangelogEntryPath `
    -ExpectedComponent 'plugins'
if ([string]$changelog.Entry.version -ne $ReleaseVersion) {
    throw 'Changelog entry version does not match ReleaseVersion.'
}
if ([string]$changelog.Entry.channel -ne $Channel) {
    throw 'Changelog entry channel does not match Channel.'
}
if ([string]$changelog.Entry.status -ne 'ready') {
    throw 'Plugin release event requires a ready changelog entry.'
}

$expectedTag = "v$ReleaseVersion"
if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
    $ReleaseTag = $expectedTag
}
elseif ($ReleaseTag -ne $expectedTag) {
    throw "ReleaseTag must be $expectedTag."
}

$parsedTimestamp = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse(
        $CreatedAt,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsedTimestamp)) {
    throw "CreatedAt is not a round-trip timestamp: $CreatedAt"
}

$normalizedTimestamp = $parsedTimestamp.ToUniversalTime().ToString(
    "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'",
    [Globalization.CultureInfo]::InvariantCulture)

$normalizedReleaseUrl = $null
if (-not [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
    $uri = $null
    if (-not [Uri]::TryCreate(
            $ReleaseUrl,
            [UriKind]::Absolute,
            [ref]$uri) -or
        $uri.Scheme -ne 'https' -or
        $uri.Host -ne 'github.com') {
        throw 'ReleaseUrl must be an HTTPS github.com URL.'
    }

    $normalizedReleaseUrl = $uri.AbsoluteUri
    $expectedReleaseUrl =
        "https://github.com/termbrio/tbmp/releases/tag/$expectedTag"
    if ($normalizedReleaseUrl.TrimEnd('/') -ne $expectedReleaseUrl) {
        throw "ReleaseUrl must be $expectedReleaseUrl."
    }
}

$event = [ordered]@{
    schemaVersion = 1
    eventKind = 'plugins'
    channel = $Channel
    createdAt = $normalizedTimestamp
    source = [ordered]@{
        repository = 'termbrio/tbmp'
        revision = $SourceRevision.ToLowerInvariant()
        tag = $ReleaseTag
        entryDigest = [string]$changelog.Digest
    }
    releaseUrl = $normalizedReleaseUrl
    changelog = $changelog.Entry
    plugins = [ordered]@{
        releaseVersion = $ReleaseVersion
        codexVersion = $codexVersion
        claudeVersion = $claudeVersion
    }
}

$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    [void](New-Item -ItemType Directory -Force -Path $parent)
}

$json = $event | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText(
    $OutputPath,
    $json.TrimEnd() + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))

Write-Host "Wrote plugin release event to '$OutputPath'."

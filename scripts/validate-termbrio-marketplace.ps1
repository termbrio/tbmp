[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path

function Read-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $path = Join-Path $resolvedRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required marketplace file is missing: $RelativePath"
    }

    try {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in '$RelativePath': $($_.Exception.Message)"
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory)]
        $Expected,

        [Parameter(Mandatory)]
        $Actual,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', found '$Actual'."
    }
}

$manifest = Read-JsonFile -RelativePath 'plugins/termbrio-team/plugin.json'
$codexManifest =
    Read-JsonFile -RelativePath 'plugins/termbrio-team/.codex-plugin/plugin.json'
$claudeManifest =
    Read-JsonFile -RelativePath 'plugins/termbrio-team/.claude-plugin/plugin.json'
$mcp = Read-JsonFile -RelativePath 'plugins/termbrio-team/.mcp.json'
$hooks = Read-JsonFile -RelativePath 'plugins/termbrio-team/hooks/hooks.json'
$codexMarketplace = Read-JsonFile -RelativePath '.agents/plugins/marketplace.json'
$claudeMarketplace = Read-JsonFile -RelativePath '.claude-plugin/marketplace.json'

Assert-Equal -Expected 'tbmp' -Actual $codexMarketplace.name `
    -Message 'Unexpected Codex marketplace name.'
Assert-Equal -Expected 'tbmp' -Actual $claudeMarketplace.name `
    -Message 'Unexpected Claude marketplace name.'

foreach ($pluginManifest in @($manifest, $codexManifest, $claudeManifest)) {
    Assert-Equal -Expected 'termbrio-team' -Actual $pluginManifest.name `
        -Message 'Unexpected plugin name.'
    Assert-Equal -Expected 'https://github.com/termbrio/tbmp' `
        -Actual $pluginManifest.repository `
        -Message 'Unexpected plugin repository.'
}

Assert-Equal -Expected $manifest.version -Actual $codexManifest.version `
    -Message 'Generic and Codex plugin versions differ.'

$codexBaseVersion = $codexManifest.version -replace '\+.*$', ''
Assert-Equal -Expected $codexBaseVersion -Actual $claudeManifest.version `
    -Message 'Claude version does not match the Codex base version.'

$codexEntry = @(
    $codexMarketplace.plugins |
        Where-Object { $_.name -eq 'termbrio-team' }
)
$claudeEntry = @(
    $claudeMarketplace.plugins |
        Where-Object { $_.name -eq 'termbrio-team' }
)

if ($codexEntry.Count -ne 1 -or
    $codexEntry[0].source.path -ne './plugins/termbrio-team') {
    throw 'Codex marketplace must contain one local Termbrio plugin entry.'
}

if ($claudeEntry.Count -ne 1 -or
    $claudeEntry[0].source -ne './plugins/termbrio-team') {
    throw 'Claude marketplace must contain one local Termbrio plugin entry.'
}

if ($null -eq $mcp.mcpServers.TermbrioTeam) {
    throw 'TermbrioTeam MCP registration is missing.'
}

Assert-Equal -Expected 'http' -Actual $mcp.mcpServers.TermbrioTeam.type `
    -Message 'TermbrioTeam MCP transport must be HTTP.'
Assert-Equal -Expected 'http://127.0.0.1:56789/mcp' `
    -Actual $mcp.mcpServers.TermbrioTeam.url `
    -Message 'Unexpected TermbrioTeam MCP endpoint.'

if ($null -eq $hooks.hooks.SessionStart -or
    $null -eq $hooks.hooks.UserPromptSubmit) {
    throw 'Required Termbrio activity hooks are missing.'
}

$requiredSkills = @(
    'plugins/termbrio-team/skills/termbrio-cli/SKILL.md',
    'plugins/termbrio-team/skills/termbrio-team-agent/SKILL.md',
    'plugins/termbrio-team/skills/termbrio-team-orchestrator/SKILL.md'
)

foreach ($relativePath in $requiredSkills) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot $relativePath))) {
        throw "Required skill is missing: $relativePath"
    }
}

$forbiddenTerms = @(
    ('term' + 'bridge'),
    ('@' + 'ekmp'),
    ('0x656d' + '7265/ekmp')
)

$repositoryFiles = @(
    git -C $resolvedRoot ls-files --cached --others --exclude-standard
)
if ($LASTEXITCODE -ne 0) {
    throw 'Could not enumerate marketplace files.'
}

foreach ($relativePath in $repositoryFiles) {
    $fullPath = Join-Path $resolvedRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $content = [IO.File]::ReadAllText($fullPath)
    foreach ($forbiddenTerm in $forbiddenTerms) {
        if ($relativePath.IndexOf(
                $forbiddenTerm,
                [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $content.IndexOf(
                $forbiddenTerm,
                [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Retired marketplace identity remains in '$relativePath'."
        }
    }
}

Write-Host 'Termbrio marketplace validation passed.'

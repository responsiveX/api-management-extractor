#Requires -Version 7

<#
.SYNOPSIS
    Publishes one version of the ApiManagementExtractor dotnet tool package from this folder to
    the Azure Artifacts feed.

.DESCRIPTION
    Pushes ApiManagementExtractor.<Version>.nupkg from the folder of this script to the
    'dotnet-tool-feed' source with 'dotnet nuget push'. The source comes from the nuget.config in
    the same folder; the script passes that file with --configfile, so it works from any current
    directory.

    The script never builds or changes a package file. It only pushes.

    Before the push, the script searches the feed with 'dotnet package search'. When the version
    is already on the feed, or the search fails, the script throws and pushes nothing, so a
    pipeline step fails when no publish occurs. Azure Artifacts never lets you replace a version.

    A person runs it by hand, or a pipeline step runs it, after 'dotnet pack' writes a new package
    to this folder. The caller
    needs Contributor (or Feed Publisher) rights on the feed, and the Azure Artifacts Credential
    Provider must be installed (https://github.com/microsoft/artifacts-credprovider). Pass
    -Interactive on the first run, so the credential provider can sign you in.

.PARAMETER Version
    The package version to publish, for example 1.5.0 or 1.6.0-beta.1.

.PARAMETER Source
    The name of the package source in nuget.config to push to. Defaults to dotnet-tool-feed.

.PARAMETER Interactive
    Lets the credential provider stop and ask you to sign in.

.EXAMPLE
    ./Publish-ExtractorTool.ps1 -Version 1.5.0

    Publishes version 1.5.0.

.EXAMPLE
    ./Publish-ExtractorTool.ps1 -Version 1.5.1 -Interactive

    Publishes version 1.5.1, and lets the credential provider ask you to sign in.

.EXAMPLE
    ./Publish-ExtractorTool.ps1 -Version 1.5.1 -WhatIf

    Checks the feed and shows the package that would be pushed, without pushing it.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # A string, not [version]: NuGet versions can have a prerelease label (1.6.0-beta.1).
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$')]
    [string] $Version,

    [ValidateNotNullOrEmpty()]
    [string] $Source = 'dotnet-tool-feed',

    [switch] $Interactive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageId = 'ApiManagementExtractor'

# Azure Artifacts ignores the API key, but 'dotnet nuget push' needs one to send the package.
$apiKey = 'AzureArtifacts'

# The problem messages in the JSON output of 'dotnet package search', from the top level and
# from each source.
function Get-SearchProblem {
    param([object] $Result)

    foreach ($node in @($Result) + @($Result.searchResult)) {
        if ($node.PSObject.Properties['problems']) {
            foreach ($problem in $node.problems) {
                if ($problem.PSObject.Properties['text']) { $problem.text } else { "$problem" }
            }
        }
    }
}

# The versions of the package that the source has.
function Get-PublishedVersion {
    param([string] $PackageId, [string] $Source, [string] $ConfigPath, [switch] $Interactive)

    $arguments = @(
        'package', 'search', $PackageId,
        '--exact-match',
        '--prerelease',
        '--source', $Source,
        '--configfile', $ConfigPath,
        '--format', 'json'
    )
    if ($Interactive) {
        $arguments += '--interactive'
    }

    Write-Verbose "dotnet $($arguments -join ' ')"
    $json = dotnet @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Searching '$Source' for '$PackageId' failed. Run again with -Interactive to sign in."
    }

    $result = ($json -join [Environment]::NewLine) | ConvertFrom-Json
    $problems = @(Get-SearchProblem -Result $result)
    if ($problems.Count -gt 0) {
        $hint = 'Run again with -Interactive to sign in, and check that you can read the feed.'
        throw "Searching '$Source' for '$PackageId' failed: $($problems -join ' ') $hint"
    }

    $versions = foreach ($sourceResult in $result.searchResult) {
        if ($sourceResult.PSObject.Properties['packages']) {
            foreach ($package in $sourceResult.packages) {
                if ($package.id -eq $PackageId) { $package.version }
            }
        }
    }

    return @($versions)
}

$configPath = Join-Path $PSScriptRoot 'nuget.config'
$packagePath = Join-Path $PSScriptRoot "$packageId.$Version.nupkg"

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Could not find '$configPath'. It defines the '$Source' package source."
}

if (-not (Test-Path -LiteralPath $packagePath)) {
    $available = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "$packageId.*.nupkg" |
        Select-Object -ExpandProperty Name
    $hint = "Run 'dotnet pack' for version $Version first."
    throw "Could not find '$packagePath'. $hint Packages in this folder: $($available -join ', ')"
}

$publishedVersions = Get-PublishedVersion -PackageId $packageId -Source $Source -ConfigPath $configPath -Interactive:$Interactive

# NuGet versions are case-insensitive (1.6.0-Beta equals 1.6.0-beta); -contains ignores case.
if ($publishedVersions -contains $Version) {
    $hint = "Change <Version> in ApiManagementExtractor.csproj, run 'dotnet pack', and publish the new version."
    throw "'$packageId' version $Version is already on '$Source'; nothing was published. $hint"
}

Write-Host "'$packageId' version $Version is not on '$Source' yet."

$arguments = @(
    'nuget', 'push', $packagePath,
    '--source', $Source,
    '--api-key', $apiKey,
    '--configfile', $configPath
)

if ($Interactive) {
    $arguments += '--interactive'
}

Write-Verbose "dotnet $($arguments -join ' ')"

if ($PSCmdlet.ShouldProcess($Source, "Push '$packageId' version $Version")) {
    dotnet @arguments
    if ($LASTEXITCODE -ne 0) {
        $hint = 'If the error is 401 or 403, run again with -Interactive, and check that you can publish to the feed.'
        throw "Pushing '$packageId' version $Version to '$Source' failed. $hint"
    }

    Write-Host "Pushed '$packageId' version $Version to '$Source'."
}

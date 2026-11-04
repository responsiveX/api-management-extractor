#Requires -Version 7

<#
.SYNOPSIS
    Checks PowerShell scripts and modules against the powershell-standards skill: parse errors,
    PSScriptAnalyzer findings and comment-based help.

.DESCRIPTION
    For each .ps1 and .psm1 file in -Path (a folder is searched recursively):

    - Parses the file and reports each parse error.
    - Runs PSScriptAnalyzer with -SettingsPath, when the module is installed. When it is not
      installed, the script says so and does not install it.
    - For a .ps1 file, checks that Get-Help finds the help block, that it has a .SYNOPSIS, and
      that each parameter has a .PARAMETER entry.

    Changes nothing. Throws at the end when a file has a parse error, an analyzer finding or a
    help problem, so a pipeline step fails.

.PARAMETER Path
    The files or folders to check. Test files (*.Tests.ps1) are skipped.

.PARAMETER SettingsPath
    The PSScriptAnalyzer settings file. Defaults to the settings file next to this script. Pass
    the repository's settings file when it has one.

.EXAMPLE
    ./Test-PowerShellScript.ps1 -Path ./deploy/scripts/Deploy-Identities.ps1

.EXAMPLE
    ./Test-PowerShellScript.ps1 -Path ./deploy/scripts -SettingsPath ./PSScriptAnalyzerSettings.psd1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]] $Path,

    [string] $SettingsPath = (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$files = @(
    foreach ($item in $Path) {
        Get-ChildItem -Path $item -Include '*.ps1', '*.psm1' -Recurse -File |
            Where-Object Name -NotLike '*.Tests.ps1'
    }
)

if ($files.Count -eq 0) {
    throw "No .ps1 or .psm1 files in '$($Path -join "', '")'."
}

$analyzerAvailable = $null -ne (Get-Module -ListAvailable -Name PSScriptAnalyzer)
if (-not $analyzerAvailable) {
    Write-Warning 'PSScriptAnalyzer is not installed, so the analyzer did not run. Install it with: Install-PSResource PSScriptAnalyzer -Scope CurrentUser'
}

$problems = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $null, [ref] $parseErrors)
    foreach ($parseError in $parseErrors) {
        $problems.Add("$($file.FullName):$($parseError.Extent.StartLineNumber) parse error: $($parseError.Message)")
    }

    if ($analyzerAvailable -and $parseErrors.Count -eq 0) {
        # PSScriptAnalyzer runs its rules in parallel, and two rules that resolve command
        # parameters at the same time can fail with a NullReferenceException. The failure comes
        # and goes, so try again before reporting it.
        $findings = $null
        $analyzerError = $null
        for ($attempt = 1; $attempt -le 3 -and $null -eq $findings; $attempt++) {
            try {
                $findings = @(Invoke-ScriptAnalyzer -Path $file.FullName -Settings $SettingsPath)
            }
            catch {
                $analyzerError = $_.Exception.Message
            }
        }

        if ($null -eq $findings) {
            $problems.Add("$($file.FullName): PSScriptAnalyzer failed on this file 3 times: $analyzerError")
        }
        else {
            foreach ($finding in $findings) {
                $problems.Add("$($file.FullName):$($finding.Line) $($finding.RuleName): $($finding.Message)")
            }
        }
    }

    if ($file.Extension -eq '.ps1' -and $parseErrors.Count -eq 0) {
        # GetHelpContent finds the help block the same way Get-Help does.
        $help = $ast.GetHelpContent()
        if ($null -eq $help) {
            $problems.Add("$($file.FullName): Get-Help finds no help block. Put the help first, or after #Requires and a blank line.")
        }
        else {
            if ([string]::IsNullOrWhiteSpace($help.Synopsis)) {
                $problems.Add("$($file.FullName): the help has no .SYNOPSIS.")
            }

            $parameterNames = @()
            if ($null -ne $ast.ParamBlock) {
                $parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
            }

            foreach ($parameterName in $parameterNames) {
                if (-not $help.Parameters.ContainsKey($parameterName.ToUpperInvariant())) {
                    $problems.Add("$($file.FullName): the help has no .PARAMETER $parameterName.")
                }
            }
        }
    }
}

foreach ($problem in $problems) {
    Write-Host $problem
}

if ($problems.Count -gt 0) {
    throw "$($problems.Count) problems in $($files.Count) files."
}

Write-Host "Checked $($files.Count) files; no problems."

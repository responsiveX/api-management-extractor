#Requires -Version 7

<#
.SYNOPSIS
    Creates the example file when it is missing. <One or two sentences: what the script does,
    starting with a verb such as "Creates", "Gets" or "Publishes".>

.DESCRIPTION
    <What the script changes, and what it never changes.>

    Idempotent: an existing file is never changed, so a second run changes nothing.

    <Who runs it and when, and the rights the caller needs.>

.PARAMETER Name
    The name of the file to create.

.PARAMETER Path
    The folder for the file. Defaults to the folder of this script.

.EXAMPLE
    ./New-Example.ps1 -Name example.txt

.EXAMPLE
    ./New-Example.ps1 -Name example.txt -WhatIf
    Shows what would change without changing it.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [string] $Path = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module imports, then script-level constants, then functions, then the main body. Replace the
# body below; it shows the pattern: find what exists, then change only what is missing, inside
# ShouldProcess, and print one line for each thing.

$itemPath = Join-Path $Path $Name

if (Test-Path -LiteralPath $itemPath) {
    Write-Host "'$itemPath' exists; left unchanged."
}
elseif ($PSCmdlet.ShouldProcess($itemPath, 'Create')) {
    $null = New-Item -ItemType File -Path $itemPath
    Write-Host "Created '$itemPath'."
}

# Shared modules, pipeline input and Pester tests

Part of the powershell-standards skill. Read it when you write or change a shared module, a
function that returns objects, or Pester tests.

## Shared modules

When a second script needs a function, move it to a shared module (`common/<Product>.psm1`, or
the module the repository already has). In the module:

- the module starts with a comment that says what it holds, then `Set-StrictMode -Version Latest`
- each function name has the product or repository name as a noun prefix
  (`Invoke-<Product>Request`), so it does not collide with other modules
- each function has a `.SYNOPSIS` help block inside it, `[CmdletBinding()]` and a full
  `param()` block
- each public function is in the `Export-ModuleMember -Function` list at the end of the module
- each public function has Pester tests (see [Pester tests](#pester-tests))

Import the module with a path relative to the script:

```powershell
Import-Module (Join-Path $PSScriptRoot 'common' '<Product>.psm1') -Force
```

When a module is shared beyond one repository (published to a feed, or copied into other
repositories), give it a manifest: `New-ModuleManifest` makes a `<Product>.psd1` next to the
`.psm1`. List the public functions in `FunctionsToExport` (never `'*'`), and set
`ModuleVersion`, `PowerShellVersion = '7.0'` and `Description`. A module used only inside one
repository can stay a `.psm1` with `Export-ModuleMember`.

For an error that stops a module function, see
[errors.md](errors.md#errors-in-a-module-function).

## Output type

Declare the type that a function or script writes with `[OutputType([type])]` after
`[CmdletBinding()]`, and describe it in `.OUTPUTS`: the type, and what each property holds.
Use the type that the function really writes; PSScriptAnalyzer's `PSUseOutputTypeCorrectly`
rule checks it.

A public function that returns custom objects gives them a type name, so a caller can test the
type and a format file can display it:

```powershell
[pscustomobject]@{
    PSTypeName = 'Product.Source'
    Name       = $name
    Schedule   = $schedule
}
```

Name the type `<Product>.<Noun>`, and use the same name in `.OUTPUTS`.

## Pipeline input and -PassThru

A public module function that acts on one item at a time accepts the items from the pipeline
too, so a caller can write `$names | Get-ProductItem`:

```powershell
function Get-ProductItem {
    <#
    .SYNOPSIS
        Gets the item for each name.

    .OUTPUTS
        [pscustomobject] with Name and Length.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $Name
    )

    process {
        foreach ($itemName in $Name) {
            [pscustomobject]@{
                Name   = $itemName
                Length = $itemName.Length
            }
        }
    }
}
```

- Put the work in a `process {}` block. PowerShell runs it once for each pipeline item.
  Without the block, the function sees only the last item.
- Loop over the parameter inside `process`, so `-Name 'a', 'b'` works the same as
  `'a', 'b' | Get-ProductItem`.
- Mark only one parameter in each parameter set with `ValueFromPipeline`.
- A function that returns many items writes each item when it has it, as above, not one array
  at the end. The caller can then start on the first item at once. Do not wrap the output in
  `@()` or `,` to return it as one array.
- A `New-`, `Set-` or `Add-` function writes nothing by default. Give it a `[switch] $PassThru`
  that writes the created or changed object, so a caller can use it in the next command.

Scripts seldom need pipeline input. Add it only when a caller pipes to the script.

## Pester tests

Write Pester tests for each public function in a shared module. A script that only calls
other commands in order does not need tests; the checks and a `-WhatIf` run cover it.

- Put the tests in a `tests/` folder next to the module, one file for each module:
  `common/tests/<Product>.Tests.ps1`. When the repository already has a test folder for
  PowerShell, use it.
- Use Pester 5 or later syntax: `BeforeAll`, `Describe`, `Context`, `It` and `Should -Be`.
  Import the module in `BeforeAll`.
- Name each `It` with the result that the test expects, as a sentence ("Throws when the Azure
  CLI fails").
- Never call Azure from a test. Mock `az` and `Invoke-RestMethod` with `-ModuleName`, so the
  mock replaces the call inside the module. A mock of `az` sets `$global:LASTEXITCODE`.

```powershell
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Product.psm1') -Force
}

Describe 'Get-ProductAccessToken' {
    It 'Returns the token from the Azure CLI' {
        Mock az -ModuleName Product { $global:LASTEXITCODE = 0; 'token-value' }

        Get-ProductAccessToken -Resource 'https://example.org' | Should -Be 'token-value'
    }

    It 'Throws when the Azure CLI fails' {
        Mock az -ModuleName Product { $global:LASTEXITCODE = 1 }

        { Get-ProductAccessToken -Resource 'https://example.org' } | Should -Throw '*az login*'
    }
}
```

Run the tests with `Invoke-Pester -Path ./path/to/tests -Output Detailed`. In a pipeline, add
`-CI`, which writes a test result file and fails the step when a test fails.

# Names of scripts, functions and parameters

Part of the powershell-standards skill. Read it when you name a new script or function, or add
a parameter.

## Verbs

- Name a script `Verb-Noun.ps1` in PascalCase, with an approved verb. Run `Get-Verb` to list
  the approved verbs: `Deploy-Identity.ps1`, `Publish-CodePackage.ps1`,
  `Remove-RoleAssignment.ps1`. The same rules apply to function names.
- Pick the verb by what it means in `Get-Verb`, not by the English word. For example, `New`
  creates, `Add` adds to a container, `Set` changes, `Update` brings up to date, `Invoke` runs,
  `Test` checks and returns `$true` or `$false`, `Deploy` sends to a place where it runs. Never
  use an unapproved synonym (`Create`, `Delete`, `Make`, `Check`, `Run`, `Setup`).
- A `Test-` command returns only a `[bool]`, so it can go in an `if`. When the command finds
  problems and must report them, use another verb (`Assert-` throws on a problem).
- Use the opposite verb for the opposite action: `New` and `Remove`, `Add` and `Remove`,
  `Start` and `Stop`, `Import` and `Export`, `Get` and `Set`, `Enable` and `Disable`. A
  `New-Example.ps1` is undone by `Remove-Example.ps1`, not `Delete-Example.ps1` or
  `Clear-Example.ps1`.

## Nouns

- Use a singular noun, also when the command acts on many items: `Get-Process`, not
  `Get-Processes`.
- Use a specific noun. When a noun is generic (`Server`, `Setting`, `Request`), add a short
  prefix for the product: `Get-SqlServer`, `Invoke-ContosoRequest`.
- When a noun that PowerShell already uses fits, use it, so the name reads like the built-in
  commands.

PowerShell has a list of approved verbs, but no list of approved nouns. The guidelines say
only that a noun is singular, specific and in PascalCase. But the built-in commands and the Az
module use a set of nouns for things that scripts often act on. When one of them names the
thing your command acts on, use it:

| Noun | The thing | Built-in examples |
| --- | --- | --- |
| `Item`, `ChildItem` | A file, a folder or another provider item | `New-Item`, `Get-ChildItem` |
| `Content` | What is in a file | `Get-Content`, `Set-Content` |
| `Path` | A path string | `Join-Path`, `Test-Path`, `Resolve-Path` |
| `Location` | The working folder | `Push-Location`, `Set-Location` |
| `Process`, `Service`, `Job` | A running process, a service, a background job | `Start-Process`, `Get-Service`, `Wait-Job` |
| `Module`, `Command`, `Variable` | A PowerShell module, command or variable | `Import-Module`, `Get-Command` |
| `Json`, `Csv`, `Xml` | A data format, after `ConvertTo`, `ConvertFrom`, `Export` or `Import` | `ConvertTo-Json`, `Export-Csv` |
| `Credential`, `SecureString` | A user name and password, an encrypted string | `Get-Credential` |
| `WebRequest`, `RestMethod` | An HTTP call | `Invoke-WebRequest`, `Invoke-RestMethod` |
| Az resource nouns: `ResourceGroup`, `RoleAssignment`, `KeyVaultSecret`, `StorageAccount`, `WebApp` | An Azure resource | `Get-AzResourceGroup`, `New-AzRoleAssignment` |

For an Azure resource, use the noun of the Az module command for that resource, without the
`Az` prefix (`Remove-RoleAssignment.ps1`), even when the script calls the Azure CLI. To find
the noun, look at the Az module's command list, or run `Get-Command -Noun <Noun>` when the
module is installed.

Do not use a built-in noun for a different thing. A script that copies settings between
two services is not `Copy-Item`.

## Parameter names

Use the standard parameter names when one fits, so the script reads like the built-in
commands:

| Name | Use it for |
| --- | --- |
| `Path` | A path; wildcards allowed. `LiteralPath` when they are not. |
| `Name`, `Id` | The name or the ID of the thing the command acts on |
| `Value` | The value to set |
| `InputObject` | Input from the pipeline (with `ValueFromPipeline`) |
| `Include`, `Exclude`, `Filter` | Which items to act on |
| `Recurse` | Act on subfolders too (a switch) |
| `Force` | Act even when a restriction stops the command, such as a read-only file (a switch). It never skips a security check. |
| `PassThru` | Also write the changed object to the output (a switch) |
| `Credential` | A `[pscredential]` |
| `Encoding` | The text encoding of a file |
| `Timeout`, `Wait` | How long to wait, and whether to wait for the result |

- When a more specific name is clearer, use the standard name and add the specific name as an
  alias: `[Alias('ServiceName')] [string] $Name`.
- Use singular parameter names (`Name`, `Path`), also for an array. Use a plural only when
  the value always has more than one item.
- For an Azure resource, use the Az module's parameter names: `SubscriptionId`,
  `ResourceGroupName`, `Location`, `Name`.
- When the repository has names of its own for a value, use them.

## Parameter design

- When a command takes a path that can contain wildcards, give it both `Path` and
  `LiteralPath`, in separate parameter sets. Mark `Path` with `[SupportsWildcards()]`, and give
  `LiteralPath` the alias `PSPath`, so `Get-ChildItem | Your-Command` binds the full path.
  When a command takes one exact file, a `LiteralPath` (or a `Path` without wildcards) is
  enough.

  ```powershell
  [CmdletBinding(DefaultParameterSetName = 'Path')]
  param(
      [Parameter(Mandatory, ParameterSetName = 'Path', Position = 0)]
      [SupportsWildcards()]
      [string[]] $Path,

      [Parameter(Mandatory, ParameterSetName = 'LiteralPath', ValueFromPipelineByPropertyName)]
      [Alias('PSPath')]
      [string[]] $LiteralPath
  )
  ```

- When a command has parameter sets, set `DefaultParameterSetName` in `[CmdletBinding()]` to
  the set that most callers use.
- Use `ValueFromPipelineByPropertyName` when the input objects have a property with the
  parameter's name or alias (for example, `FullName` or `PSPath` from `Get-ChildItem`).
- When a value can be true, false or not given (not given means "do not change it"), use
  `[nullable[bool]]`, not a `[switch]`.

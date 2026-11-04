---
name: powershell-standards
description: >
  PowerShell script and module standards: names, help, parameters, errors, Azure CLI calls,
  -WhatIf, shared modules, Pester tests, output, formatting and the checks before a script is
  done. Use whenever you create, edit or review a .ps1, .psm1 or .psd1 file, or when the user
  asks to write, fix or review a PowerShell script. Also trigger when a .ps1 or .psm1 file is
  opened in the IDE.
---

# PowerShell script standards

Follow these rules for every new script, and for every change to an existing script.

Before you write a script, read two or three scripts in the same folder. When the repository
and this skill do not agree, use this order:

1. Rules that the repository writes down (agent instructions, a README, a settings file) win.
2. In a new file, follow this skill.
3. In an existing file, match the style of that file. Do not reformat it, rename it, or change
   lines that the task does not need, even when they do not follow this skill. The new lines
   look like the lines around them: the same layout, names, quotes and help style. Tell the
   user about the differences that you saw but did not change.

   The exception: the user asks you to reformat the file, or to make it follow these
   standards (or the PowerShell conventions). Then apply this skill to the whole file.

Where this skill says nothing (a parameter name, a helper module, a README that lists the
scripts), follow the repository.

## Reference files

This file has the rules for every script. The reference files have the rules for some tasks.
Before you start, read each one that the task needs. Its rules apply as much as the rules here.

| Read | When the task |
| --- | --- |
| [references/naming.md](references/naming.md) | names a new script or function, or adds a parameter |
| [references/errors.md](references/errors.md) | loops over items that do not depend on each other, stops a module function with an error, retries a call, makes temporary files, or changes the working folder |
| [references/azure.md](references/azure.md) | calls `az` or a REST API, or handles a secret, a token or a subscription |
| [references/modules.md](references/modules.md) | writes or changes a shared module, a function that returns objects, or Pester tests |
| [references/azure-pipelines.md](references/azure-pipelines.md) | is a script that an Azure DevOps pipeline runs, or the YAML step that calls it |

The `resources/` folder has:

- `resources/New-Example.ps1` — the skeleton for a new script. Copy it, rename it, then fill
  it in.
- `resources/Test-PowerShellScript.ps1` — the checks to run before a script is done.
- `resources/PSScriptAnalyzerSettings.psd1` — the analyzer settings for these rules.

## Check commands, do not recall them

Do not write a cmdlet, a parameter or a module from memory when you are not sure that it
exists in the PowerShell version the script requires. Never invent a parameter.

- Check a command with `Get-Command <Name> -Syntax` or `Get-Help <Name> -Parameter <Parameter>`
  when it is installed, or in the Microsoft Learn reference for the PowerShell version
  (`learn.microsoft.com/powershell/module/...?view=powershell-7.4`). Note the version that
  added a parameter; for example, `-SkipHttpErrorCheck` needs 7.0 and `ConvertTo-Json -AsArray`
  needs 6.2.
- Before you use or recommend a module, check on the PowerShell Gallery
  (`Find-PSResource -Name <Name>`) that it exists, is not deprecated, and has the version you
  need.
- When you cannot check, tell the user what you could not check and how they can
  (`Get-Command <Name> -Syntax`).

## Where scripts go

Put a script in the folder where the repository keeps scripts of the same kind: setup and
deployment scripts, pipeline step scripts, local development scripts. Put functions that two
or more scripts use in a shared module (`common/<Product>.psm1`). Do not put inline scripts of
more than a few lines in pipeline YAML.

## Names

- Name a new script `Verb-Noun.ps1` in PascalCase, with an approved verb (run `Get-Verb` to
  list them) and a singular, specific noun: `Deploy-Identity.ps1`, `Remove-RoleAssignment.ps1`.
  The same rules apply to function names. For the meaning of each verb, the opposite pairs,
  the common nouns and the standard parameter names, read
  [references/naming.md](references/naming.md).
- Do not rename an existing script that uses another style (such as `seed-sources.ps1`) unless
  the user asks for a rename. Pipelines, other scripts and docs call it by its name. A request
  to reformat a file or make it follow these standards is not a request to rename it; ask
  first. When the user asks for a rename, search the repository for the old name and update
  every caller.

## Script layout

Every script has these parts, in this order. `resources/New-Example.ps1` shows them.

1. `#Requires -Version 7` on the first line, and `#Requires -Modules <Name>` for each module
   the script needs (with a minimum version when it needs one:
   `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }`), so the script stops
   at the start with a clear message, not halfway through. Then a blank line. Without the blank
   line, `Get-Help` does not find the help block.
2. Comment-based help.
3. `[CmdletBinding()]`, or `[CmdletBinding(SupportsShouldProcess)]` (see
   [Changes, -WhatIf and prompts](#changes--whatif-and-prompts)). Then `[OutputType([type])]`
   when the script writes objects to the output.
4. The `param()` block.
5. `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`.
6. Module imports, then script-level constants, then functions, then the main body.

### Comment-based help

- `.SYNOPSIS` — one or two sentences: what the script does. Start with a verb in the third
  person ("Creates", "Seeds", "Publishes"). You can add references to a spec, a decision record
  or a work item at the end, in parentheses.
- `.DESCRIPTION` — what the script changes and what it never changes; whether it is idempotent
  ("Idempotent: a second run changes nothing."); who runs it and when (the pipeline, a person
  by hand, or both) and why; the rights the caller needs; what it prints or writes.
- `.PARAMETER` — one for each parameter, in the order of the `param()` block. Give the default
  when there is one ("Defaults to Release."), and an example value when the format is not
  clear.
- `.OUTPUTS` — when the script writes objects to the output: the type, and what each property
  holds. Omit it when the script only prints status lines.
- `.EXAMPLE` — at least one for each script that a person runs. Show `-WhatIf` when the script
  supports it. A script that only a pipeline step calls can omit `.EXAMPLE`.
- Write in short, plain sentences. Wrap the help at about 100 characters.

### Parameters

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [string] $Path = (Join-Path $PSScriptRoot 'output'),

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [switch] $Force
)
```

- Put each attribute on its own line, then `[type] $Name` with a space between the type and
  the name. Put a blank line between parameters.
- Use `[Parameter(Mandatory)]`, not `Mandatory = $true`. Validate in the `param()` block
  (`ValidateSet`, `ValidatePattern`, `ValidateRange`, `ValidateNotNullOrEmpty`), not in the body.
- Give every parameter the most specific type that fits, so PowerShell checks the value before
  the script runs: `[uri]` for a URL, `[datetimeoffset]` or `[datetime]` for a point in time,
  `[timespan]` for a duration, `[guid]`, `[version]`, `[int]` with `ValidateRange`,
  `ValidateSet` or an enum for a fixed set of values, `[securestring]` for a secret,
  `[pscredential]` for a user name and password. Use `[string]` only for free-form text and
  names. Use `[switch]` for flags, never `[bool]`.
- Take an array (`[string[]] $Name`) when a caller can reasonably pass more than one value,
  and loop over it. Keep the name singular.
- Use a standard name when one fits (`Path`, `LiteralPath`, `Name`, `Id`, `Value`, `Force`,
  `PassThru` and others in [references/naming.md](references/naming.md)). Never declare a
  common parameter (`WhatIf`, `Confirm`, `Verbose`, `Debug`, `*Action`, `*Variable`);
  `[CmdletBinding()]` adds them.
- Give the same value the same name and type in every script of the repository.
- Build default paths from `$PSScriptRoot` with `Join-Path`. Never depend on the current
  directory.

## Linux, Windows and paths

Pipeline agents usually run Linux, and people run the same scripts on Windows. Write every
script so that it runs on both.

- Build paths with `Join-Path`. Never write `\` or `/` into a path.
- Match the case of file and folder names exactly; Linux file names are case-sensitive. So are
  environment variable names: `$env:PATH`, not `$env:Path`.
- Do not read `$env:USERNAME`, `$env:COMPUTERNAME` or `$env:USERPROFILE`; Linux does not set
  them. Use `[Environment]::UserName`, `[Environment]::MachineName` and `$HOME`.
- Get the temporary folder from `[System.IO.Path]::GetTempPath()`, not `$env:TEMP`.
- Do not call Windows-only commands (`cmd`, `where.exe`, `Get-WmiObject`, the registry). When
  there is no other way, check `$IsWindows` first and tell the user what does not run on Linux.
- Call tools by their command name (`az`, `dotnet`, `npm`), not by a path that exists only on
  one system.
- A `Path` parameter accepts wildcards. When a value must be used exactly as given (a file name
  can contain `[` or `]`), name the parameter `LiteralPath` and pass it on with `-LiteralPath`.
- PowerShell's current folder is not the current directory of the process, and neither .NET
  nor a native command understands a PowerShell drive. Resolve a path before you pass it to a
  .NET method or a native command. Cmdlets resolve paths themselves.

  ```powershell
  $fullPath = Convert-Path -LiteralPath $Path    # The file exists.
  $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)    # It may not.
  ```

## Errors

- Fail with `throw` and a message that says what failed and, when you know it, how to fix it.
  Do not use `exit 1`; a `throw` stops the script and fails the pipeline step.

  ```powershell
  throw 'Could not read the tenant of the signed-in Azure CLI. Run az login.'
  ```

- `$ErrorActionPreference` does not stop on a native command that fails. Check
  `$LASTEXITCODE` after every `az`, `dotnet`, `npm` or `git` call:

  ```powershell
  $json = az ad app list --identifier-uri $IdentifierUri --output json
  if ($LASTEXITCODE -ne 0) {
      throw "Reading the applications with the identifier URI '$IdentifierUri' failed."
  }
  ```

- When a non-zero exit code is an expected answer (a "does it exist?" probe), send its error
  output to `2>$null`, test the result, and set `$global:LASTEXITCODE = 0` before the next
  native call.
- Use `try`/`catch` only when you can recover, retry or add context to the error. Do not catch
  an error only to write it and continue. When the script handles some errors differently,
  catch those exception types first (`catch [System.IO.FileNotFoundException] { ... }`), and
  end with a general `catch` that rethrows (`throw`) or adds context. For loops, module functions, retries and cleanup,
  read [references/errors.md](references/errors.md).
- Under strict mode, reading a property that an object does not have throws. An object from
  `ConvertFrom-Json` has only the properties that were in the JSON, so check an optional
  property first: `if ($source.PSObject.Properties['schedule']) { ... }`. Check `.Count`
  before you read `[0]` of a list that can be empty.

## Changes, -WhatIf and prompts

- A setup or seed script must be idempotent: a second run with the same input changes nothing.
  Find what exists first, then create only what is missing. Do not change or delete what people
  or another process changed, unless that is the purpose of the script. Print what you left
  unchanged.
- A script that writes data or changes resources and that a person runs by hand declares
  `[CmdletBinding(SupportsShouldProcess)]` and wraps each write. The target is the thing that
  changes; the action says what happens to it:

  ```powershell
  if (-not $PSCmdlet.ShouldProcess($documentId, "Apply $($changes.Count) entry changes")) {
      continue
  }
  ```

- `-WhatIf` reaches PowerShell cmdlets only. A native command (`az`, `dotnet`, `npm`) does not
  know about it, and `Invoke-RestMethod` does not skip a `PUT` or a `DELETE`. Put every call
  that changes something inside a `ShouldProcess` block. Reads can stay outside it, so
  `-WhatIf` can show what would change.
- A script that deletes, overwrites or does something that cannot be undone declares
  `ConfirmImpact = 'High'` as well. PowerShell then asks the user to confirm each change, and
  a non-interactive run must pass `-Confirm:$false`; say so in the `.DESCRIPTION`. Leave the
  default (`Medium`) for a script that only creates or updates.
- Never stop for input with `Read-Host`, `$Host.UI.PromptForChoice()` or
  `$PSCmdlet.ShouldContinue()` unless a `-Force` switch skips the prompt. Take the value as a
  parameter instead.

## Functions and return values

- A function used only inside one script goes after the constants and before the main body.
  Its first line is a one-line comment that says what it returns or does, then a typed
  `param()`:

  ```powershell
  function ConvertTo-Hashtable {
      # A JSON object as an ordered hashtable of strings.
      param([object] $Object)
      ...
  }
  ```

- When a second script needs the function, move it to a shared module. Read
  [references/modules.md](references/modules.md).
- A function returns every value that it does not capture, not only the value after `return`.
  Native command output, `.Add()` on an `ArrayList`, `New-Item` and many .NET methods all write
  a value, and the caller gets an array instead of the one value it expects:
  - discard a value that you do not need with `$null = ...` (`$null = New-Item ...`)
  - capture native command output in a variable, even when you only check `$LASTEXITCODE`
  - use `[System.Collections.Generic.List[T]]`, not `ArrayList`; its `.Add()` returns nothing
  - never use `Write-Output` or a bare string for a status line
- A function that returns one value ends with `return $value`. Return
  `[pscustomobject]@{ ... }` when it returns more than one value.

## Output

- `Write-Host` for status lines: one line for each thing the script created, changed or left
  unchanged, with the name of the thing in single quotes. The default PSScriptAnalyzer rules
  flag it, but it is right here: it writes to the information stream, so a caller can capture
  it (`6>&1`) or hide it (`-InformationAction Ignore`), and it does not go into a return value.
- `Write-Warning` for a condition the reader must act on, or an action with a result they do
  not expect (overwriting a file).
- `Write-Verbose` for detail that helps when something goes wrong (the request URI, the value
  the script chose). `Write-Debug` for internal state. `Write-Progress` for a long loop in a
  script that a person runs.
- The output (a bare value, `return`) is for objects that the caller uses, never status text.
- Never write with `[System.Console]::WriteLine()`. It skips the streams.
- Never print a token, key or secret.
- Write files with `Set-Content -Path $Path -Encoding utf8`. Write JSON with
  `ConvertTo-Json -Depth <n>` and a `-Depth` large enough for the data. Use `[ordered]@{}` when
  the order of keys matters.

## Security and performance

- Never use `Invoke-Expression`, and never build a command as a string and run it. Do not run a
  script block or a file that comes from input.
- Pass the arguments of a native command as separate values or as an array, never as one
  joined string, so a value with a space or a `--` stays one argument:
  `$arguments = @('webapp', 'show', '--name', $Name); az @arguments`.
- Validate input that becomes part of a path, a URL or a query (`ValidatePattern`), and escape
  each part of a URL with `[uri]::EscapeDataString()`.
- Do not grow an array or a string with `+=` in a loop; each `+=` copies all of it. Assign the
  loop output (`$names = foreach ($item in $items) { $item.name }`), use a `List[T]`, or use
  `-join` or a `[System.Text.StringBuilder]`.
- Filter early: ask `az` for only what you need (`--query`). Filter a large collection with
  `.Where({ ... })` or a `foreach` loop, not many pipeline steps in a hot loop. Read a large
  file once (`Get-Content -Raw`), not inside a loop.

## Formatting

- 4 spaces for indentation. No tabs.
- Opening brace on the same line. `else`, `elseif`, `catch` and `finally` on a new line after
  the closing brace.
- Single quotes for strings that do not interpolate. Double quotes only when they do.
- Full cmdlet and parameter names. No aliases (`ForEach-Object`, not `%` or `foreach`;
  `Where-Object`, not `?`). On Linux, some aliases (`ls`, `sort`, `cat`) run the native command
  instead of the cmdlet.
- Named parameters, not positional: `Get-Content -Path $path`, not `Get-Content $path`. The
  exceptions are the path parts of `Join-Path` and the arguments of native tools.
- Never continue a line with a backtick (`` ` ``). A space after it breaks the script without
  a visible sign. Break the line after a `|`, a `,`, an operator or an opening bracket, or use
  splatting.
- PascalCase for parameters and functions. camelCase for local variables.
- Align the `=` signs in a multi-line hashtable.
- Break a long pipeline after each `|` and indent the next lines by 4 spaces.
- Use splatting (`@parameters`) when a call has more than about four parameters.
- Comments explain why, not what. Put them on their own line above the code.
- A blank line between logical blocks, and after each block that ends with `}`, unless the next
  line continues the statement (`else`, `elseif`, `catch`, `finally`, or a `|` after the `}`).

## Documentation

When the folder has a README that lists its scripts, add or update the row for the script.
When a script changes how a deployment works, update the deployment docs of the repository.

## Check your work

Do these checks before you report a script as done.

1. **Run the check script.** It parses each file, runs PSScriptAnalyzer and checks the help
   (`Get-Help` finds it, it has a `.SYNOPSIS`, and each parameter has a `.PARAMETER`). It
   throws when it finds a problem.

   ```powershell
   <path to this skill>/resources/Test-PowerShellScript.ps1 -Path ./path/to/Script.ps1
   ```

   Pass `-SettingsPath` when the repository has its own `PSScriptAnalyzerSettings.psd1`. Fix
   every problem in the lines you wrote. In an existing file, a finding in lines that you did
   not change, or a finding that the file's own style causes (such as a plural noun that the
   file already uses), is not yours to fix. Tell the user about it, unless they asked you to
   reformat the file or make it follow these standards.

   The analyzer settings exclude the default rules that conflict with this skill
   (`Write-Host`, `ShouldProcess` on helper functions). They also exclude
   `PSAvoidUsingPositionalParameters`, which makes PSScriptAnalyzer 1.25 fail in most runs, so
   check named parameters by hand. The analyzer can still fail on a file now and then; the
   check script tries again, and reports the file when it fails 3 times.
   `PSUseCorrectCasing` flags the `-gt` in `Where-Object Count -gt 1` and asks for `-GT`.
   Ignore that finding.

   When PSScriptAnalyzer is not installed, the check script says so and runs the other checks.
   Ask the user before you install it (`Install-PSResource PSScriptAnalyzer -Scope CurrentUser`).
   If they do not want it, review the script against this skill by hand, and tell them that
   the analyzer did not run.

2. **Run the tests.** When you changed a shared module, run its Pester tests.

3. **Dry run.** When the script supports `-WhatIf`, and you can reach the environment, run it
   with `-WhatIf` and look at what it would change. Do not run a script against a cloud
   environment without the user's approval.

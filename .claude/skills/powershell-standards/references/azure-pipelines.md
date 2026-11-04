# Scripts in Azure DevOps pipelines

Part of the powershell-standards skill. Read it when an Azure DevOps pipeline runs the script,
or when you write the YAML step that calls it. For the rest of the YAML, follow the pipeline
standards skill when one is available.

## The pipeline step

The scripts need PowerShell 7. On a Windows agent, the default PowerShell task runs Windows
PowerShell 5.1, and `#Requires -Version 7` stops the script. Use one of these:

- `PowerShell@2` with `pwsh: true`
- `AzureCLI@2` with `scriptType: pscore`, when the script calls `az`. The task signs in the
  CLI with the service connection.

Use `scriptPath` and `arguments` (or `ScriptArguments`), not an inline script. Do not put
inline scripts of more than a few lines in pipeline YAML.

A pipeline cannot answer a prompt. When the script declares `ConfirmImpact = 'High'`, the step
passes `-Confirm:$false`.

## Pester results

`Invoke-Pester -CI` writes `testResults.xml` (NUnit format) and fails the step when a test
fails. The run shows the test results only after a `PublishTestResults@2` step that reads the
file. Run it even when the tests failed:

```yaml
- task: PublishTestResults@2
  displayName: Publish the PowerShell test results
  condition: succeededOrFailed()
  inputs:
    testResultsFormat: NUnit
    testResultsFiles: '**/testResults.xml'
```

## Logging commands

Write logging commands with `Write-Host`:

- `##vso[task.setvariable variable=<name>;isOutput=true]<value>` for an output variable
- `##vso[task.logissue type=warning]<message>` or `type=error` for an issue on the run
  summary. Use it instead of `Write-Warning`, which shows only in the log.
- `##vso[task.complete result=SucceededWithIssues;]<message>` for a partial success
- `##vso[task.setsecret]<value>` before you use a token or secret, so the log masks it

## Agents

- Pipeline agents usually run Linux. Follow the skill's Linux and Windows rules.
- Prefer `$env:AGENT_TEMPDIRECTORY` for temporary files when it is set.
- Do not call `Write-Progress` in a script that only a pipeline runs; the log shows nothing
  useful.

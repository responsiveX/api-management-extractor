# Azure CLI, REST calls and secrets

Part of the powershell-standards skill. Read it when a script calls `az` or a REST API, or
handles a secret, a token or a subscription.

## Azure CLI

- Use the Azure CLI (`az`), not the Az PowerShell module, unless the repository already uses
  the module. Do not mix the two in one script.
- Never use the `MSOnline` or `AzureAD` modules; Microsoft retired them and they no longer
  work. For Entra ID, use `az ad` or the `Microsoft.Graph` module.
- Authenticate with Entra ID through the signed-in Azure CLI identity. In the pipeline, that is
  the service connection.
- Make the subscription explicit in a script that changes resources. Take `-SubscriptionId`
  and pass `--subscription` to each `az` call, or take `-ResourceGroupName` and a subscription
  together. Print the name of the subscription before the first change. Do not run
  `az account set` in a script; it changes the CLI for the rest of the user's session.
- Ask the CLI for JSON (`--output json`) and parse all of its lines:
  ``($json -join "`n") | ConvertFrom-Json``. Use `--query ... --output tsv` for one value, and
  `.Trim()` it.
- Wrap a result that can be one item or many in `@(...)` before you use `.Count`.
- Check `$LASTEXITCODE` after every call. For a "does it exist?" probe, see the native command
  rules in the skill's Errors section.

## REST calls

- Get the token with `az account get-access-token --resource <resource>` and call
  `Invoke-RestMethod` with `-SkipHttpErrorCheck` and `-StatusCodeVariable`, so the script
  decides what each status code means. When the repository has a shared module with a request
  helper, use the helper.
- To retry throttled or unavailable calls, see [errors.md](errors.md#retries).

## Secrets

Prefer Entra ID to keys, connection strings and secrets. When a secret cannot be avoided (for
example, a GitHub token):

- Take it from a pipeline secret variable or from Key Vault, in a parameter or an environment
  variable.
- Declare a secret parameter as `[securestring]`, so PowerShell does not show it in the
  console, in a transcript or in an error. Convert it to plain text only on the line that uses
  it: `ConvertFrom-SecureString -SecureString $Token -AsPlainText`. Do not keep the plain text
  in a variable that lives longer than that call.
- A secret that arrives in an environment variable is already plain text. Read it on the line
  that uses it.
- In a pipeline, write `##vso[task.setsecret]<value>` before you use it, so the log masks it.
- Never put it in a parameter default, a file in the repository or the output.

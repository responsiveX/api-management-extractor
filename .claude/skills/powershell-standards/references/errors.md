# Error handling patterns

Part of the powershell-standards skill. Read it when a script loops over items that do not
depend on each other, a module function must stop with an error, a script retries a call, or
a script makes temporary files or changes the working folder.

## Errors in a loop

When a script acts on items that do not depend on each other (one document for each seed
entry, one role assignment for each identity), one failure must not stop the other items.
Catch the error for that item, record it, continue, and throw at the end with a summary:

```powershell
$failures = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $entries) {
    try {
        Update-Entry -Entry $entry
    }
    catch {
        $failures.Add("$($entry.id): $($_.Exception.Message)")
        Write-Host "Updating '$($entry.id)' failed: $($_.Exception.Message)"
    }
}

if ($failures.Count -gt 0) {
    throw "$($failures.Count) of $($entries.Count) entries failed:`n$($failures -join "`n")"
}
```

When the items depend on each other (a later step needs an earlier one), do not continue;
let the first error stop the script.

## Errors in a module function

In a shared module function with `[CmdletBinding()]`, report an error that stops the function
with `$PSCmdlet.ThrowTerminatingError()`. The error then points at the caller's line, not at
the line inside the module, and has an ID and a category that a caller can test:

```powershell
$exception = [System.InvalidOperationException]::new("The source '$Name' has no connector type.")
$PSCmdlet.ThrowTerminatingError(
    [System.Management.Automation.ErrorRecord]::new($exception, 'MissingConnectorType', 'InvalidData', $Name))
```

In a script, a plain `throw` is enough.

## Retries

Retry only an error that can go away on its own: HTTP 429 (throttled), 503 (unavailable), a
time-out, or HTTP 412 when you read the item again before the next write. Do not retry 400,
401, 403 or 404.

- Limit the attempts with a parameter (`[ValidateRange(1, 20)] [int] $MaxAttempts = 5`).
- Wait between attempts. Use the `Retry-After` header when the response has one. Otherwise,
  double the wait each time, starting at about 2 seconds.
- Print each retry, and throw with the last error after the last attempt.

```powershell
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $response = Invoke-RestMethod @request -SkipHttpErrorCheck -StatusCodeVariable 'statusCode' -ResponseHeadersVariable 'headers'
    if ($statusCode -notin 429, 503) {
        break
    }

    $delaySeconds = if ($headers.ContainsKey('Retry-After')) { [int] $headers['Retry-After'][0] } else { [math]::Pow(2, $attempt) }
    Write-Host "Attempt $attempt of $MaxAttempts got HTTP $statusCode; trying again in $delaySeconds seconds."
    Start-Sleep -Seconds $delaySeconds
}
```

## Temporary files and the working folder

- When a script changes the working folder with `Push-Location`, it calls `Pop-Location` in a
  `finally` block, so a failure does not leave the caller in another folder.
- When a script makes a temporary file or folder, it deletes it in a `finally` block.
- Get the temporary folder from `[System.IO.Path]::GetTempPath()`, not `$env:TEMP`, which Linux
  does not set. In a pipeline, prefer `$env:AGENT_TEMPDIRECTORY` when it is set.

```powershell
$bodyFile = New-TemporaryFile
Push-Location $frontendPath
try {
    ...
}
finally {
    Pop-Location
    Remove-Item -Path $bodyFile -Force -ErrorAction SilentlyContinue
}
```

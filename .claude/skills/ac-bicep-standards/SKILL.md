---
name: ac-bicep-standards
description: >
  Bicep infrastructure authoring standards for Amusement Connect. Use this skill when working
  on any .bicep file in a deploy/infrastructure/ folder — including new resources, connection
  strings, shared module consumption, AVM conversions, or checking for stale module/API version
  pins. Trigger phrases include "fix this bicep", "add a bicep resource", "convert to AVM",
  "use the shared registry", "add a connection string", "review this bicep file", "check for
  new module versions", "check for API version updates", "are there newer versions of these
  modules", or any instruction referencing .bicep files. Also triggers automatically when a
  .bicep file inside deploy/ or any of its subfolders is opened in the IDE.
---

# Bicep Standards

Authoring and review standards for Amusement Connect Bicep infrastructure files. Files live under `deploy/infrastructure/` and are deployed by the ADO pipeline.

---

## Commit message

Derive the ticket tag from the current branch name — strip the `feature/`,
`bugfix/`, etc. prefix, take the ticket segment (e.g. `ab-4710` → `AB#4710`),
and uppercase the letters. Do not ask the user for the ticket number if it's
derivable from the branch name.

Commit a completed Bicep standards pass as its own commit, separate from any
pipeline-standards work (`ac-pipeline-standards`), even in the same session:

```
[AB#4710] - Bicep Upgrade Phase <n>
```

`<n>` is one more than the highest existing `Bicep Upgrade Phase <n>` commit
for that ticket tag on the branch (check `git log`), or `1` if none exist yet.
Never fold this into a `Pipeline Upgrade` commit message — the two are
tracked as separate phases even when done back-to-back.

---

## SQL Connection Strings

### Always include `Application Name` in SQL connection strings

Every SQL connection string must include `Application Name=<ServiceName>;` where `<ServiceName>` is the PascalCase name of the service (e.g. `WalletService`, not `wallet-service`).

This allows SQL Server to identify which service owns each connection, which is essential for monitoring (`sys.dm_exec_sessions`), deadlock analysis, and query attribution across services sharing the same SQL server.

#### Identifying SQL connection strings

SQL connection strings may have many different variable or parameter names. Identify them by their **content**, not their name. A string is a SQL connection string if it contains any of:
- `Server=tcp:`
- `Data Source=`
- `Initial Catalog=`
- `Database=`
- `Authentication=Active Directory`

Common variable names include (but are not limited to): `transactionalConnectionString`, `readOnlyConnectionString`, `sqlConnectionString`, `connectionString`, `dbConnectionString`, or any `var`/parameter whose value matches the patterns above.

#### No duplicate parameters

Each keyword in a connection string must appear exactly once. Duplicates are silently ignored or cause unpredictable behavior depending on the driver. When reviewing a connection string, split on `;` and verify each keyword (the part before `=`) is unique.

Common duplicates to watch for: `Encrypt`, `TrustServerCertificate`, `MultipleActiveResultSets`, `Connection Timeout`, `Application Name`.

```bicep
// Correct
var transactionalConnectionString string = 'Server=tcp:${sqlServerName}${az.environment().suffixes.sqlServerHostname};Database=${sqlDatabaseName};Authentication=Active Directory Default;MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=180;Max Pool Size=1000;Pooling=True;Application Name=DeviceService;'

// Wrong — missing Application Name
var transactionalConnectionString string = 'Server=tcp:${sqlServerName}${az.environment().suffixes.sqlServerHostname};Database=${sqlDatabaseName};Authentication=Active Directory Default;MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=180;Max Pool Size=1000;Pooling=True;'

// Wrong — duplicate Encrypt keyword
var transactionalConnectionString string = 'Server=tcp:${sqlServerName}...;Encrypt=True;TrustServerCertificate=False;Encrypt=True;Application Name=DeviceService;'
```

### Build connection strings with `buildSqlConnectionString`, not hand-rolled strings

Use `buildSqlConnectionString` from the `shared-functions` registry module instead of interpolating a raw connection-string literal. It bakes in the AC standard defaults (`Authentication=Active Directory Default`, `MultipleActiveResultSets=True`, `Encrypt=True`, `TrustServerCertificate=False`, `Max Pool Size=1000`, `Pooling=True`, `Connection Timeout=180`) and takes an `additionalSettings` object that appends new keys or overrides any default (including `Server`, `Database`, `Connection Timeout`, or `Application Name`) — this also structurally prevents the duplicate-keyword bug above, since the underlying `union()` dedupes by key.

The final `port` argument (`int?`) is appended to `Server` as `,<port>`; pass `null` to get the standard default of `1433`. Pass a non-null port with an empty `sqlServerHostnameSuffix` (`''`) for servers that don't use an Azure SQL-style hostname suffix — e.g. a Fabric SQL endpoint reached as `Server=tcp:<server>,1433`.

```bicep
import { buildSqlConnectionString } from 'br/ac-registry:shared-functions:0.0.5'

var transactionalConnectionString = buildSqlConnectionString(sqlServerName, az.environment().suffixes.sqlServerHostname, sqlDatabaseName, 'DeviceService', {}, null)

var reportingConnectionString = buildSqlConnectionString(readOnlySqlServerName, az.environment().suffixes.sqlServerHostname, readOnlySqlDatabaseName, 'DeviceService', {
  ApplicationIntent: 'ReadOnly'
  'Connection Timeout': '30'
}, null)

// Fabric-style endpoint: no hostname suffix, explicit port, MARS off
var fabricConnectionString = buildSqlConnectionString(fabricServerName, '', fabricDatabaseName, 'DeviceService', {
  Authentication: 'Active Directory Managed Identity'
  'User ID': managedIdentityClientId
  MultipleActiveResultSets: 'False'
}, 1433)
```

**Fabric SQL endpoints must override `MultipleActiveResultSets` to `'False'`.** The function's baked default is `'True'`, which is correct for Azure SQL but not for Microsoft Fabric Warehouse SQL endpoints — always pass `MultipleActiveResultSets: 'False'` in `additionalSettings` whenever building a Fabric connection string.

Always pin to the exact version currently published — check the dev ACR the same way described under **Shared Functions Library** below.

### Define connection strings per consumer, explicit — never in shared app-settings config

When both an App Service and a Function App are deployed from the same template, each needs its **own** `Application Name` (e.g. `DeviceService` vs `DeviceServiceFunc`) so `sys.dm_exec_sessions` attribution stays accurate per-process. Build one `var` per consumer and pass each explicitly to its own module call's `connectionStrings` parameter — do **not** fold connection strings into `sharedConfiguration`/`apiConfiguration`/`functionConfiguration` or any other app-settings array shared between the two.

```bicep
// Correct
var appConnectionStrings = [
  {
    name: 'ReadOnlySql'
    connectionString: buildSqlConnectionString(readOnlySqlServerName, az.environment().suffixes.sqlServerHostname, readOnlySqlDatabaseName, 'DeviceService', {
      ApplicationIntent: 'ReadOnly'
      'Connection Timeout': '30'
    }, null)
    type: 'SqlAzure'
  }
  {
    name: 'TransactionalSql'
    connectionString: buildSqlConnectionString(sqlServerName, az.environment().suffixes.sqlServerHostname, sqlDatabaseName, 'DeviceService', {}, null)
    type: 'SqlAzure'
  }
]

var funcConnectionStrings = [
  {
    name: 'ReadOnlySql'
    connectionString: buildSqlConnectionString(readOnlySqlServerName, az.environment().suffixes.sqlServerHostname, readOnlySqlDatabaseName, 'DeviceServiceFunc', {
      ApplicationIntent: 'ReadOnly'
      'Connection Timeout': '30'
    }, null)
    type: 'SqlAzure'
  }
  {
    name: 'TransactionalSql'
    connectionString: buildSqlConnectionString(sqlServerName, az.environment().suffixes.sqlServerHostname, sqlDatabaseName, 'DeviceServiceFunc', {}, null)
    type: 'SqlAzure'
  }
]

module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // ...
    connectionStrings: appConnectionStrings
  }
}

module functionApp 'br/ac-registry:function-app:...' = {
  params: {
    // ...
    connectionStrings: funcConnectionStrings
  }
}

// Wrong — single shared connectionStrings var reused by both modules, or connection strings
// mixed into sharedConfiguration/apiConfiguration/functionConfiguration app-settings arrays
var connectionStrings = [
  { name: 'TransactionalSql', connectionString: buildSqlConnectionString(sqlServerName, az.environment().suffixes.sqlServerHostname, sqlDatabaseName, 'DeviceService', {}, null), type: 'SqlAzure' }
]
```

If a service has only one compute resource (no App Service + Function App split), a single connection-strings var passed to that one module is fine — the rule is about not sharing one var across multiple consumers with different identities, not about always having two vars.

---

## Resource Delete Locks

### Shared registry modules expose a delete lock parameter

The `app-service-linux` and `function-app` shared registry modules both expose a `lock bool` parameter (default `false`) that applies an Azure Management Lock preventing accidental deletion. When `true`, the module creates a `NoDelete` lock named `<resource-name>-lock`.

Enable locks in production environments; leave them off in dev/test where resources are regularly torn down and recreated.

**Naming convention in `azuredeploy.bicep`** (mirrors the `freshDeploy` pattern — see Fresh Deploy Parameter below):

```bicep
// App Service section
param appServiceDeleteLock bool = false

// Function App section
param funcAppDeleteLock bool = false
```

Pass them through in the module calls:

```bicep
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // ...
    lock: appServiceDeleteLock
  }
}

module functionApp 'br/ac-registry:function-app:...' = {
  params: {
    // ...
    lock: funcAppDeleteLock
  }
}
```

### Every production `.bicepparam` file must set both delete-lock params to `true`

```bicep
// azuredeploy.parameters.prod-az1a.bicepparam
param appServiceDeleteLock = true
param funcAppDeleteLock = true

// Dev/Test .bicepparam files — omit both (module default false applies)
```

This is a hard requirement, not a per-service judgment call: **every** production `.bicepparam` file must set both params to `true`, with no exceptions. When reviewing a `.bicepparam` file for a production environment (any file matching `azuredeploy.parameters.prod-*.bicepparam` or otherwise targeting a prod environment), check for both `appServiceDeleteLock = true` and `funcAppDeleteLock = true` (or whatever the service's equivalent param names are, if it deviates from this naming convention) and flag either one as a standards violation if missing, set to `false`, or simply absent from the file. Apply this check proactively whenever authoring or reviewing a prod `.bicepparam` file, even if the user didn't explicitly ask about delete locks.

---

## Fresh Deploy Parameter

### Expose `freshDeploy` for App Service and Function App in `azuredeploy.bicep`

Both the `app-service-linux` and `function-app` shared registry modules expose a `freshDeploy bool` parameter (default `false`) that controls how `siteConfig` is applied on the production slot.

**Why it exists:** when `deploySlots` is true (non-B-tier SKU), the module normally applies a minimal `siteConfig` to the production slot and lets the staging slot carry the full config (app settings, connection strings, runtime). Settings reach production via a slot swap. On a brand-new environment the swap has never happened, so the production slot has no app settings yet — `freshDeploy: true` bypasses the minimal-config path and pushes the full config directly to the production slot for that one initial deploy.

**Naming convention in `azuredeploy.bicep`:**

```bicep
// App Service section
param appServiceFreshDeploy bool = false

// Function App section
param funcAppFreshDeploy bool = false
```

Pass them through in the module calls:

```bicep
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // ...
    lock: appServiceDeleteLock
    freshDeploy: appServiceFreshDeploy
  }
}

module functionApp 'br/ac-registry:function-app:...' = {
  params: {
    // ...
    lock: funcAppDeleteLock
    freshDeploy: funcAppFreshDeploy
  }
}
```

Both default to `false` and must **not** be set in `.bicepparam` files under normal operation. Set them to `true` only in a `.bicepparam` file (or as a pipeline CLI override) when provisioning a new environment for the first time, then remove or reset to `false` before the next regular deploy.

---

## App Service & Function App Settings

### Dotnet version parameter naming in `azuredeploy.bicep`

When passing `dotnetVersion` to the shared registry modules, declare the caller-side parameters with these exact names:

```bicep
@description('The .NET major version to use for the Linux App Service runtime (e.g., 8, 9, 10).')
param appServiceDOTNETVersion int = 10

@description('The .NET major version to use for the Linux Function App runtime (e.g., 8, 9, 10).')
param funcAppDOTNETVersion int = 10
```

Both are integers (major version only). The shared modules construct the full runtime string internally (`DOTNETCORE|<n>.0` for app service, `DOTNET-ISOLATED|<n>.0` for function app). Always include the `@description` decorator with the exact wording above.

---

### `healthCheckPath` — let the module default apply on current versions

`function-app` >= `0.0.18` defaults `healthCheckPath` to `'/api/version'`, and `app-service-linux` >= `0.0.17` defaults it to `'/'`. These are the correct AC-standard health check paths for each module type, so on a module pinned to at least these versions, **do not** declare an explicit `healthCheckPath`/`appServiceHealthCheckEndpoint`/`funcAppHealthCheckEndpoint` param — omit it and let the module default apply.

When reviewing or editing a template that pins `function-app` >= `0.0.18` or `app-service-linux` >= `0.0.17`, flag and remove any explicit `healthCheckPath` param (in `azuredeploy.bicep`, its module-call wiring, and any `.bicepparam` override) that just reproduces the module default. Also remove the caller-side `appServiceHealthCheckEndpoint`/`funcAppHealthCheckEndpoint` params entirely if nothing else needs a per-environment override.

```bicep
// Correct — module pinned >= the versions above, healthCheckPath omitted, module default applies
module appServiceModule 'br/ac-registry:app-service-linux:0.0.17' = {
  params: {
    // ...
    // healthCheckPath intentionally omitted — module default '/' applies
  }
}

module functionApp 'br/ac-registry:function-app:0.0.18' = {
  params: {
    // ...
    // healthCheckPath intentionally omitted — module default '/api/version' applies
  }
}

// Wrong on these versions — redundant explicit param reproducing the module default
param appServiceHealthCheckEndpoint string = '/'
param funcAppHealthCheckEndpoint string = '/api/version'
```

**On older module versions** (`function-app` < `0.0.18` or `app-service-linux` < `0.0.17`, both of which default to `'/health'`), keep the older guidance: pass `healthCheckPath` explicitly using these param names, since `'/health'` is not the desired AC-standard path.

```bicep
param appServiceHealthCheckEndpoint string = '/'
param funcAppHealthCheckEndpoint string = '/api/version'
```

Pass them through to the module calls only when targeting a pre-bump module version:

```bicep
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // ...
    healthCheckPath: appServiceHealthCheckEndpoint
  }
}

module functionApp 'br/ac-registry:function-app:...' = {
  params: {
    // ...
    healthCheckPath: funcAppHealthCheckEndpoint
  }
}
```

If a caller genuinely needs a non-standard path (e.g. a service without a `/api/version` endpoint), an explicit override is still fine on current module versions — the rule is against redundantly restating the module's own default, not against overriding it for a real reason.

---

### `alwaysOn` must be `true` — except a Function App's staging slot

Set `alwaysOn: true` on every App Service (including its staging slot) and on a Function App's production slot. Never omit it or set it to `false` there — apps with `alwaysOn: false` are unloaded after idle periods, causing cold starts on the next request.

```bicep
// Correct
siteConfig: {
  alwaysOn: true
  // ...
}

// Wrong — false or omitted
siteConfig: {
  alwaysOn: false
  // ...
}
```

**Exception:** a Function App's *staging slot* is intentionally `alwaysOn: false` — this is correct, not a bug. The shared `function-app` registry module hardcodes this (it's not exposed as a per-call override), and that's the desired behavior. Don't flag it, and don't try to force `true` there.

When using the shared registry modules (`app-service-linux`, `function-app`), pass `alwaysOn: true` explicitly for the App Service and for the Function App's production config rather than relying on any default; the Function App module's own hardcoded `false` on its staging slot needs no action from the caller.

---

### `clientAffinityEnabled` should be `false`

The `app-service-linux` and `function-app` shared registry modules default `clientAffinityEnabled` to `false`. If an existing config sets `clientAffinityEnabled: true` (directly or via a caller param passed into one of these modules), flag it and suggest switching it to `false` — or removing the param entirely so the module default applies.

```bicep
// Flag this and suggest removing the param, or setting it to false
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // ...
    clientAffinityEnabled: true
  }
}

// Correct — omit the param and let the module default (false) apply
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // ...
  }
}
```

---

## Azure Verified Modules (AVM)

### Use AVM when creating new resources or converting existing ones

Use [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) in two situations:

1. **Creating a new resource** — author a `module` block using the `br/public:avm/res/...` registry path instead of a raw `resource` declaration.
2. **Converting an existing resource** — only when the user explicitly asks to migrate or convert an existing `resource` block to AVM.

Do **not** proactively refactor existing `resource` declarations to AVM as part of unrelated changes.

**Module reference syntax:**

```bicep
module <symbolicName> 'br/public:avm/res/<provider>/<resource>:<version>' = {
  name: '<deployment-name>'
  params: {
    name: '<resource-name>'
    // ...
  }
}
```

**Examples:**

```bicep
// Storage account via AVM
module storageAccount 'br/public:avm/res/storage/storage-account:0.16.0' = {
  name: 'storageAccountDeploy'
  params: {
    name: storageAccountName
  }
}

// Key Vault via AVM
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'keyVaultDeploy'
  params: {
    name: keyVaultName
  }
}
```

### How to look up an AVM module path and version

When you need an AVM module, use the `documentation` MCP tool to find the correct path and latest version:

1. Call `microsoft_docs_search` with a query like `"Azure Verified Modules avm/res storage account"` (substitute the resource type).
2. The result will include the full `br/public:avm/res/...` path and a version tag.
3. Use that path verbatim in the Bicep `module` block.

If no AVM module exists for the resource type, fall back to a raw `resource` declaration and note the absence.

### When AVM does not apply

Do **not** use AVM syntax for:
- Variable declarations (`var`)
- Output blocks
- Existing resource references (`resource foo '...' existing = { ... }`)
- Child resources authored inside a parent module

---

## Bicep What-If Analysis

When asked to "perform a bicep what-if" or "perform a bicep compare to <target>" (or any equivalent like "check what would change", "compare current vs template"), do **not** use `az deployment group what-if` — it short-circuits on `reference()` expressions that depend on sibling resources. Instead, use static Bicep analysis combined with live Azure queries.

### Scope

By default, compare every resource the template deploys. When the user specifies particular modules (e.g. "just the app service and function app modules"), limit the comparison to only the resources those modules create. The resources owned by each shared module are:

| Module | Resources created |
|---|---|
| `app-service-linux` | App Service Plan, App Service |
| `function-app` | Function App Plan, Function App, `slotConfigNames` sub-resource |

For each resource in scope, include **all** properties: siteConfig, identity, httpsOnly/httpsOnly, **app settings**, and **connection strings**.

**Never query, display, or reference the staging slot's current content, in any form.** Every comparison is production vs. template — full stop. Staging in this deployment model holds whatever was deployed before the *last* release, not a preview of what's coming, so its current state is not informative and reporting on it is actively misleading. This means: no separate "— Staging Slot" resource card, no attention item framed around what staging currently has, no note along the lines of "staging already shows X" or "staging is stale relative to production." If the user explicitly asks to compare staging specifically, that's a distinct, separate request — the default here is always production only.

### Procedure

1. **Read the template, params, and modules in scope.** Read `azuredeploy.bicep` and the `.bicepparam` file for the target environment. For each resource in scope, read the module that owns it — local modules from `modules/`, shared registry modules from `D:\Repos\ac-bicep-registry\modules\<name>\main.bicep`. Trace all parameters to determine the exact property and app setting values that will be deployed.

2. **Get one Azure access token up front, then run every live query as raw REST calls sharing it — never spawn a separate `az <noun> <verb>` per query.** Each `az` CLI invocation pays a fixed 1–3s startup cost (Python interpreter, module load, credential resolution) regardless of how small the call is; a compare with 15–20 queries pays that tax 15–20 times over, and it dominates the wall-clock time far more than the actual network calls do. Fetch the token once:
   ```powershell
   $token = az account get-access-token --resource https://management.azure.com --query accessToken -o tsv
   ```
   Then issue every subsequent query as `az rest --url "<resource-id>/...?api-version=..." --headers "Authorization=Bearer $token"` (or `Invoke-RestMethod` with that header) directly against the ARM endpoint, instead of wrapper commands like `az webapp show` / `az functionapp config appsettings list` — same data, no repeated CLI bootstrap.

3. **Build the full query list first, then dispatch it as a single parallel wave — never a "resolve dependencies, then query resources" sequence.** The dynamic-value lookups and the per-resource state lookups hit different resource IDs and don't depend on each other, so querying them in two sequential rounds only adds a round-trip wait for no reason. Combine both into one list:
   - **Dynamic-value dependencies** referenced by app settings (e.g. `cosmosDb.properties.documentEndpoint`, `appConfig.properties.endpoint`, `keyVaultModule.outputs.keyVaultUri`, `serviceBus.properties.serviceBusEndpoint`, `iotHub.outputs.iotHubUrl`) — de-dupe before dispatching: if both the App Service and Function App reference the same Key Vault/Cosmos/App Config/etc. endpoint, resolve it once, not once per consumer.
   - **Per-resource state, production only, never the staging slot:**
     - Plan — SKU, kind, reserved
     - Site (no `--slot` / no `/slots/` segment) — the **full** `siteConfig` object (do not selectively project specific properties — any property the template or AVM sets that is omitted from the query will silently miss a change), plus `identity`, `httpsOnly`, `keyVaultReferenceIdentity`, and `clientAffinityEnabled` at the top level
     - App settings list (`.../config/appsettings/list`)
     - Connection strings list (`.../config/connectionstrings/list`) — works for both web apps and function apps
     - `.../config/slotConfigNames` — this lists which app-setting *names* are configured as sticky (a production-level configuration fact, not staging content) — do not follow it up with a query of the staging slot's actual values for those keys

   Issue every call in this list as parallel tool invocations **in the same message** — splitting them across separate responses serializes them and reintroduces the wait this step exists to remove.

4. **Produce a per-resource comparison table.** For each resource, compare deployed vs template. Mark each property ✅ (match), ➕ (new — in template, not currently deployed), ⚠️ (change — value differs, or live value will be cleared because it is not in the template), or ❓ (AVM default applies, not explicitly set by template).

5. **Summarize findings.** Call out every ➕, ⚠️, and ❓ with an assessment of whether it is safe or needs a fix.

6. **Publish results as an HTML Artifact.** Always render the comparison as an HTML Artifact — never text-only output. Write the file to the session scratchpad and call the Artifact tool. See **Output** below for the required design.

### Output

Every what-if result **must** be published as an HTML Artifact. Do not skip this step or substitute a markdown table.

**Design spec:**
- Dark Azure-themed palette: background `#0d1117`, surface `#161b27`, elevated `#1d2336`, border `#2a3352`, text `#d8e2f5`, muted `#5d6e99`, accent `#4d8ef0`
- Status colors: match `#3fb950`, change `#d4941a`, addition `#58a6ff`, removal `#f85149`, unknown `#bc8cff`
- **Scoreboard** at top: five cells (Matches / Changes / New / Removals / N/A), large count in its status color
- **Attention panel** below scoreboard: one card per ⚠️ warn item then ℹ️ info item, 2-column grid, left border stripe in status color. Each card is a **finding derived from the comparison data below it** — a change, removal, or confirmation a reader would want to know before deploying. It is never a changelog of the editing session: don't title or word a card around what got "fixed," "reverted," or "resolved" during the conversation (e.g. "Fixed — appCommandLine was missing", "Resolved — Cosmos settings restored"). If an issue was corrected before the report was generated, it shows up as a plain ✅ match row in the table and does not need its own attention card at all — only surface it up top if the *current* comparison result still needs the reader's attention.
- **"Hide matching rows" toggle** — defaults to on; 114 green rows stay out of the way
- **Resource cards** with collapsible body, left border stripe in worst-status color, count pills in the header
- **Per-resource tables**: Properties, App Settings, Connection Strings, slotConfigNames (special tag-diff layout)
- Monospace for all property names and values; `font-variant-numeric: tabular-nums` for counts; `overflow-x: auto` on all table wrappers
- Favicon: 🔍

### Notes

- **`deploySlots` pattern**: modules that use `var deploySlots = !contains(['B1','B2','B3'], planSKU)` will not create staging slots for B-tier SKUs. Confirm the current environment's SKU from the `.bicepparam` file to know whether slot-related properties apply — this matters because it changes which siteConfig branch (minimal vs. full) is live, and B-tier envs (dev/test) never exercise the minimal branch at all.
- **Production-slot minimal siteConfig omissions are intentional, not a reset risk.** AC pipelines deploy with `deploymentMode: 'Incremental'`. Under Incremental mode, omitting a property from an existing resource's PUT payload leaves its current value alone rather than resetting it to a platform default. The `app-service-linux`/`function-app` shared modules rely on exactly this: when `deploySlots && !freshDeploy`, the production slot's siteConfig deliberately includes only `minTlsVersion`/`http20Enabled`/`ftpsState`/`remoteDebuggingEnabled` — `alwaysOn`, `linuxFxVersion`, `cors`, `netFrameworkVersion`, `healthCheckPath`, `appCommandLine`, `appSettings`, and `connectionStrings` are all omitted on purpose, because the production slot's full runtime config is meant to arrive only via slot swap from staging. This intentional-omission behavior only covers updates to an **already-deployed** resource; a slot with no prior swap history has nothing to fall back to, which is exactly what `freshDeploy: true` exists to handle for a brand-new environment's first deploy.
- **Never render a production-slot omission as a bare placeholder like "omitted (by design)" — always compute and show the real pending value.** The property is not unknowable: it's whatever the full siteConfig branch evaluates to given the current params and module defaults — the same analytical trace required by Procedure step 1. Compute it directly from the template/module source; do **not** query the staging slot's live state to get this value (staging is out of scope entirely — see Scope). Label the column "Pending (arrives via next swap)" and mark the row ✅ if it matches what's live in production today, or the real ⚠️/➕ status if it doesn't. A "by-design, not scored" placeholder silently swallows genuine regressions — e.g., a shared-module parameter (`appCommandLine`) the caller forgot to wire through defaults to `''`, which is a real, damaging diff (the site's startup command would be blanked on the next deploy) that "omitted (by design)" would hide entirely. Reserve the true "n/a" status for properties with no computable value at all — e.g., `functionAppScaleLimit`, which the shared module has no parameter for, so there is no pending value to show.
- **Other siteConfig omissions may still reset.** The above is specific to the deploySlots-minimal-branch pattern. For any other siteConfig property genuinely absent from both the template and any prior deploy (e.g., a property no module or prior version ever set), still flag with ⚠️ per the general caution — don't assume "leave alone" applies universally.
- **AVM defaults**: properties not set by the caller but handled internally by an AVM module (e.g., `minTlsVersion`) are marked ❓ with a note that AVM sets the default.
- **`netFrameworkVersion` is a Windows-only property — mark it ❓ na, never ⚠️ change, on any Linux App Service or Function App (`app-service-linux`, `function-app`, or any raw `kind: '...,linux'` site).** On Linux, `linuxFxVersion` is the property that actually selects the runtime (confirmed both via Azure documentation and by the Azure Portal's own Stack Settings panel, which reads `linuxFxVersion`, not `netFrameworkVersion`); the platform does not consult `netFrameworkVersion` at all for Linux workers. This holds regardless of which module set it or what value it holds live — a mismatch here (e.g. live `v9.0` vs. the template's `v10.0`) is real at the ARM-property level but has **zero runtime effect**, so don't give it a dedicated attention card or a ⚠️ status; note in the table row that it's cosmetic and point to `linuxFxVersion`'s (already-correct) status instead. Don't assume both modules treat it the same way, either — `app-service-linux` (as of 0.0.17) never sets it at all, while `function-app` (as of 0.0.18) sets it in the full siteConfig branch only; both are equally inert on Linux regardless of that difference.

---

## Shared Bicep Registry (ac-bicep-registry)

### When to use

When a module exists in `ac-bicep-registry`, reference it from the shared registry rather than maintaining a local copy in the service repo.

Existing shared modules: `app-service-linux`, `function-app`. See the `ac-bicep-registry-skill` for full parameter tables.

### Reference syntax

Modules are consumed via the `ac-registry` alias defined in `bicepconfig.json`:

```bicep
module appService 'br/ac-registry:app-service-linux:1.0.0' = {
  name: 'app-service'
  params: { ... }
}
```

Always pin to a specific semantic version. Never use `latest` or a floating tag.

### bicepconfig.json setup

Each service repo needs per-environment `bicepconfig.json` files. The ACR name follows `acracshared<env>az1a`:

```
deploy/infrastructure/bicepconfig.json             ← default (dev), used by IDE and local dev
deploy/infrastructure/bicepconfig.dev-az1a.json
deploy/infrastructure/bicepconfig.test-az1a.json
deploy/infrastructure/bicepconfig.prod-az1a.json
```

Each file maps the `ac-registry` alias to the environment's ACR:

Always include the `$schema` line — without it IDE tooling won't validate the file.

```json
{
  "$schema": "https://aka.ms/bicep-config",
  "moduleAliases": {
    "br": {
      "ac-registry": {
        "registry": "acracshared<env>az1a.azurecr.io",
        "modulePath": "bicep"
      }
    }
  }
}
```

### Pipeline step: select bicepconfig before deploying

Add this step to the deploy pipeline template **before** the `AzureResourceManagerTemplateDeployment` task. The environment abbreviation and location abbreviation are already available as pipeline parameters:

```yaml
- pwsh: |
    Copy-Item "$(Pipeline.Workspace)/infrastructure/bicepconfig.${{ parameters.environment_abbreviation }}-${{ parameters.location_abbreviation }}.json" `
              "$(Pipeline.Workspace)/infrastructure/bicepconfig.json" -Force
  displayName: 'Select Bicep registry config (${{ parameters.environment_abbreviation }}-${{ parameters.location_abbreviation }})'
```

### Migrating from a local module

When replacing a local module with a shared registry equivalent:

1. Check if the shared module removed any bundled resources (e.g., the `function-app` shared module does **not** create the managed identity or storage account — the caller owns them).
2. Add those resources directly to the calling template.
3. Replace any module output references that relied on the removed resources with direct property references (e.g., `functionManagedIdentity.properties.principalId` instead of `functionApp.outputs.functionUserAssignedIdentityPrincipalId`).
4. Align the calling template's `@allowed` decorator to match the shared module's allowed SKU list.
5. `functionAppScaleLimit` (the old `siteConfig.functionAppScaleLimit` property some local modules set) has no equivalent parameter on the shared `function-app` module and is dropped by design during migration — do not flag its absence as a regression. It only ever had an effect on Consumption/Elastic Premium plans; on the dedicated B-tier/P-tier plans this module targets, it was already a no-op.
6. **Explicitly pass `appCommandLine` on both the `app-service-linux` and `function-app` module calls.** It defaults to `''` on both shared modules, and nothing else in the template supplies it — trace the actual startup command from the deploy pipeline's app-deployment step (e.g. `AzureRmWebAppDeployment@4`'s `StartupCommand` input) and pass that identical string through `appCommandLine`. Skipping this is easy to miss because the pipeline's own deployment step re-sets the startup command on every full app deploy, masking the gap — but it still blanks the site's startup command on any deploy that runs infrastructure without also running the app deployment (an infra-only or APIM-only run), leaving the site unable to start until the next full deploy.

### Function App module call must have an explicit `dependsOn` on its storage account module

The `function-app` shared registry module takes `storageAccountName` as a plain `string` — it bakes that value directly into the `AzureWebJobsStorage__accountName` app setting and never references the storage account as an `existing` resource or module output. Because Bicep's implicit dependency graph is built only from symbolic references (`module.outputs.x`, `resource.properties.y`), passing a name string gives Bicep no way to know the `function-app` module depends on the storage account module — without an explicit `dependsOn`, ARM is free to deploy the function app before the storage account (and its role assignments) exist, or in parallel with it.

Always add `dependsOn: [<storage module symbolic name>]` to the `function-app` module call, pointing at whichever local module creates the function's storage account (commonly `modules/storage_functionApp.bicep`).

```bicep
module functionStorage 'modules/storage_functionApp.bicep' = {
  name: 'function-storage'
  params: {
    storageName: functionStorageAccountName
    userAssignedIdentityPrincipalId: functionManagedIdentity.properties.principalId
    // ...
  }
}

module functionApp 'br/ac-registry:function-app:...' = {
  name: 'function-app'
  params: {
    // ...
    storageAccountName: functionStorageAccountName
  }
  dependsOn: [
    functionStorage
  ]
}
```

When reviewing a template that calls `br/ac-registry:function-app`, flag a missing `dependsOn` on the storage module as a standards violation — this is easy to miss because the module compiles and often deploys successfully anyway (existing storage accounts, lucky ordering), masking the race until a fresh-environment deploy hits it.

### Function App: settings that must never be set

Never add `WEBSITE_SWAP_WARMUP_PING_PATH` or `WEBSITE_SWAP_WARMUP_PING_STATUSES` to a Function App's `appSettings`. These control slot-swap warmup behavior for **App Service** (Web Apps) only — they are not valid/meaningful for Function Apps and must not be carried over from App Service app-setting lists when building a Function App's settings (including when migrating off a local module that happened to set them). The `app-service-linux` shared module bakes these in for App Service from its own `healthCheckPath`/`healthyPingStatuses` params; the `function-app` shared module intentionally has no equivalent, and none should be added by the caller either.

---

## Version Currency Check

### When to run this

Run whenever the user asks to "check for new module versions", "check for API version updates", "are there newer versions of these modules", or similar — either against one file or a whole repo's `deploy/infrastructure/` tree. This is a **detect-and-ask** pass, not an auto-upgrade: report every pinned reference alongside the latest version actually available, and let the user decide which (if any) to bump. Never bump a version without the user picking it — a module or API version bump can change required parameters, rename/remove properties, or alter default behavior, so each one needs a deliberate decision, not a blanket sweep.

**Never target a preview version, for either module pins or ARM API versions.** "Latest available" always means latest **stable**. A preview tag/API version is never the recommended bump, even when it's newer than every stable release — surface it only as an FYI note ("no newer stable exists; a preview is available if you want it"), never as the suggested target, and never bump to one without the user explicitly asking for that specific preview version by name.

There are two independent things to check, and they use different lookup mechanisms:

### 1. Shared/public module references (`br/...:<module>:<version>`)

Find every `module ... 'br/ac-registry:<name>:<version>'` and `module ... 'br/public:avm/res/.../...:<version>'` (and `import ... from 'br/ac-registry:<name>:<version>'`) reference in the target file(s).

**For `br/ac-registry:<name>:<version>`** — query the dev ACR for every tag, then pick the highest by semantic version (the API returns tags in whatever order the registry stores them, not version order — never assume the last or first entry is latest):

```powershell
az acr repository show-tags --name acracshareddevaz1a --repository bicep/<name> --orderby time_desc --top 1
```

`--orderby time_desc` sorts by push time, which is reliable here because ac-registry tags are only ever pushed in increasing version order — unlike the public AVM feed below, there's no need to hand-sort semver.

**For `br/public:avm/res/<provider>/<resource>:<version>`** — the public AVM registry is served from Microsoft Container Registry (MCR), which is unauthenticated and reachable with a plain HTTPS GET (no `az acr` command works against it — it isn't a private ACR):

```powershell
Invoke-RestMethod "https://mcr.microsoft.com/v2/bicep/avm/res/<provider>/<resource>/tags/list" | Select-Object -ExpandProperty tags
```

This returns tags in **lexicographic string order** (e.g. `0.10.0` sorts before `0.2.0`), not semver order — sort them as versions before picking the max, or you'll report a false "latest."

### 2. Raw ARM resource API versions (`resource ... '<type>@<apiVersion>'`)

Find every `resource <symbol> '<Microsoft.Namespace/resourceType>@<apiVersion>'` declaration (including `existing` resources) in the target file(s) — this covers resources that aren't behind a shared module, like the `existing` references to Cosmos DB, Service Bus, App Configuration, IoT Hub, Log Analytics, and Application Insights that `azuredeploy.bicep` typically declares directly.

Look up every available API version for that exact resource type:

```powershell
az provider show --namespace <Microsoft.Namespace> --query "resourceTypes[?resourceType=='<resourceType>'].apiVersions" -o tsv
```

This returns versions newest-first already sorted — no manual sorting needed. Skip past any `-preview` entries at the top of the list; the recommended bump is the newest **stable** version. If the pinned version is already newer than every stable release (only previews exist above it), report that no stable update is available — do not recommend the preview as the target.

### Reporting and applying

For each reference, report: the file and line, the current pin, and the latest **stable** version available (whether that's newer, matching, or — if someone manually pinned ahead of what's published — already ahead of it). Mention a newer preview only as a parenthetical FYI, never as the recommended value. Group findings by whether a stable update is available at all — don't list matching pins as findings needing action.

After the user picks which to bump: apply the version string change, then recompile (`az bicep build` / `az bicep build-params`) to catch any breaking parameter/property changes the bump introduces before treating it as done. For a `br/ac-registry` module bump, also check that module's `README.md` in `ac-bicep-registry` for a changelog of what changed between the pinned and new version. For an ARM API version bump, watch for renamed or newly-required properties in the resource's schema — the compiler will usually catch missing required properties, but silently-renamed optional properties will not error and need a manual read of the API version's schema diff.

---

## Parameter Default Promotion

### Promote shared param values to `azuredeploy.bicep` defaults; remove from `.bicepparam` files

When a parameter has the same value across all environment `.bicepparam` files (ignoring environment-name substitutions in resource names), that value belongs as a default in `azuredeploy.bicep`, not repeated in every param file.

#### When to run this cleanup

Run whenever you notice repeated identical values across env param files, or when an environment param file grows large. Compare dev and test as the baseline — if they agree, the value is a good default candidate.

#### Process

1. **Compare env param files side by side.** For each param, note its value in dev, test, and prod. Ignore differences that are just the environment name embedded in a resource name (e.g. `sb-ac-shared-dev-az1a` vs `sb-ac-shared-test-az1a`). Flag params where the *logical* value is the same across environments.

2. **For each matching param, add (or update) its default in `azuredeploy.bicep`.** Use the dev value as the canonical default. If the param already has a default that differs from the actual value used everywhere, update it.

3. **Remove the param from the dev `.bicepparam` file** (and any other env files where the value now matches the default). Keep a param in an env file only when that environment genuinely deviates from the default.

4. **Check every other env file for behavioral drift.** If the new default changes what a param would resolve to in an environment that did *not* previously set it explicitly, add an explicit override to that file to preserve its existing behavior. Common cases:
   - `funcModifiers` — if the default becomes `[{Disabled: true}]`, prod (which previously used the empty-array default) must now explicitly set `param funcModifiers = []`.
   - `onlySendEmailsToAmusementConnect` — if the default flips to `true`, prod must explicitly set `false`.
   - `appServicePlanSku`/`funcAppServicePlanSku` — dev and test consistently agree on a lower tier (e.g. `B2`); promote that to the default and give prod an explicit override with its real tier (e.g. `P0V3`), same as the two cases above.

#### What qualifies as a default candidate

The dev/test-agree heuristic is the test, not "does this look like an infra-sizing knob." A SKU/tier param is not disqualified just because prod intentionally differs — that is exactly the shape step 4 handles (promote to dev/test's value, give prod an explicit override). What actually disqualifies a param is dev and test disagreeing with *each other*, or the value being inherently per-environment (an identifier, an endpoint, a name).

| Qualifies | Does not qualify |
|---|---|
| Service Bus topic/subscription names (AC-standard across all envs) | Resource names that embed the environment abbreviation |
| Cosmos database/collection names | SQL database names (often differ between dev and prod) |
| `storageContainerName = 'media'` | Params where dev and test themselves disagree |
| `keyVaultEnableSoftDelete = false` | `adminPrincipalId`, `readerPrincipalId` (env-specific Entra groups) |
| `featureFlags` when all envs match | `fabricServerName` (different workspace per env) |
| `funcModifiers` when dev and test agree | Pipeline override placeholders (`<override this>`) |
| `appServicePlanSku`/`funcAppServicePlanSku` when dev and test agree (prod gets an explicit override — see step 4) | |

#### Example

Before — repeated in every param file:
```bicep
// azuredeploy.parameters.dev-az1a.bicepparam
param gamePlayReportedServiceBusTopicName = 'GamePlay.Reported'
param gamePlayReportedServiceBusSubscriptionName = 'AssetService.GamePlayTransactionProcessor'

// azuredeploy.parameters.test-az1a.bicepparam
param gamePlayReportedServiceBusTopicName = 'GamePlay.Reported'
param gamePlayReportedServiceBusSubscriptionName = 'AssetService.GamePlayTransactionProcessor'
```

After — default in template, removed from param files:
```bicep
// azuredeploy.bicep
param gamePlayReportedServiceBusTopicName string = 'GamePlay.Reported'
param gamePlayReportedServiceBusSubscriptionName string = 'AssetService.GamePlayTransactionProcessor'
```

---

## Parameter Grouping

### Group `param` declarations with `// Section Name` comment headers

Both `azuredeploy.bicep` and `.bicepparam` files must organize their `param` declarations into named sections using `// Section Name` comment headers. This makes large parameter files navigable and ensures related settings are co-located.

Do not leave `var` declarations embedded inside the `param` block. Move any misplaced `var` to after the last `param`.

#### Canonical section order

Use these sections in this order. Omit a section entirely if no parameters in that section apply to the file.

| Section | Parameters |
|---|---|
| `// General` | `location`, resource group names, `environment`, `tags` |
| `// Monitoring` | `logAnalyticsWorkspaceName`, `appInsightsName` |
| `// SQL` | SQL server and database name params |
| `// Key Vault` | Key vault name and soft-delete settings |
| `// Storage` | `storageAccountName`, `storageContainerName`, report container |
| `// App Service` | Name, slot, plan name/SKU, .NET version, managed identity, health check, ping statuses, game media URL, time zone |
| `// Function App` | Name, plan name/SKU, storage account name, managed identity, .NET version, health check, always-on, function name defaults, modifiers |
| `// IoT Hub` | IoT Hub name, resource group, consumer group names |
| `// Cosmos DB` | Cosmos account, database, collection names |
| `// Service Bus` | Service bus name and all topic/subscription name pairs, `deviceMeterReportMaxIntervals` |
| `// RBAC` | `adminPrincipalId`, `readerPrincipalId` |
| `// Feature Flags` | `featureFlags` |
| `// App Configuration` | `sharedAppConfigName`, `operatorDashboardBaseUrl`, `onlySendEmailsToAmusementConnect`, `fabricServerName`, `fabricDatabaseName` |
| `// Collection Options` | Collection timing params with `@description` decorators (`azuredeploy.bicep` only — these have defaults and are not overridden in `.bicepparam` files) |
| `// Email` | Mailgun params (`azuredeploy.bicep` only — `mailgunApiKey` moves to Pipeline Overrides in `.bicepparam`) |
| `// Pipeline Overrides` | Secrets and values supplied via CLI args at deploy time. In `.bicepparam` files, include the comment: `// The values for these parameters are provided via cli arguments when running in the pipeline` |

#### Format

One blank line between the section header and the first parameter. One blank line between each parameter within a section (the Bicep formatter enforces this in `.bicepparam` files). One blank line before each section header.

```bicep
// General

param location string = resourceGroup().location
param managementResourceGroupName string
param sharedResourceGroupName string
param environment string
param tags object

// Monitoring

param logAnalyticsWorkspaceName string
param appInsightsName string

// Pipeline Overrides

@secure()
param assetServiceEventHubConnectionString string
param simulatedData_Enabled string
@secure()
param simulatedData_ApiKey1 string
```

In `.bicepparam` files, the Bicep formatter adds blank lines between each `param`, so the section headers naturally stand out:

```bicep
// Pipeline Overrides
// The values for these parameters are provided via cli arguments when running in the pipeline

param assetServiceEventHubConnectionString = '<override this>'

param simulatedData_ApiKey1 = '<override this>'

param mailgunApiKey = '<override this>'
```

---

## Environment Identity Parameters

### Replace `environment string` and `tags object` with the `env` object pattern

All `azuredeploy.bicep` files must use the structured `env` param instead of a plain `environment string`. This enforces valid name/abbreviation pairs at compile time and derives `tags` automatically, so the tag block never drifts from the actual environment.

#### `azuredeploy.bicep` — declare these params and var in the `// General` section

```bicep
param workload string = 'asset'   // set to this service's short name (e.g. 'wallet', 'device')
param env {
  name: 'Development' | 'Test' | 'Production'
  abbreviation: 'dev' | 'test' | 'prod'
}
param region string = 'az1'
param stamp string = 'a'
var tags = {
  Environment: toUpper(env.abbreviation)
  Region: toUpper(region)
  Stamp: toUpper(stamp)
  Workload: toUpper(workload)
}
```

- `workload` defaults to this service's short name. It is a `param` so it can be overridden if the same template is ever reused under a different workload identity, but it should rarely change.
- `region` and `stamp` default to `'az1'` and `'a'` — the current single-region single-stamp deployment. Override in a `.bicepparam` file only when a second region or stamp is added.
- `tags` is a `var`, not a `param`. It must never appear in `.bicepparam` files.
- Do **not** declare a separate `param environment string` or `param tags object` — these are replaced entirely.

#### `.bicepparam` files — set `env` only; omit `tags`

```bicep
// Dev
param env = {
  name: 'Development'
  abbreviation: 'dev'
}

// Test
param env = {
  name: 'Test'
  abbreviation: 'test'
}

// Prod
param env = {
  name: 'Production'
  abbreviation: 'prod'
}
```

`param tags` must be removed from all `.bicepparam` files. The var in the template derives it automatically.

#### Using `env.name` in the template

Where the template previously referenced `environment` (e.g. for app settings, Key Vault soft-delete conditions), use `env.name` instead:

```bicep
// Before
value: environment

// After
value: env.name
```

---

## Shared Functions Library

### Always import `sharedFunctions` at the top of every `azuredeploy.bicep`

Every service's `azuredeploy.bicep` must import the shared functions library from the AC registry. This library provides common helper functions (e.g. Service Bus config builders) that would otherwise be duplicated across service repos.

```bicep
import { featureFlag } from './types/feature-flag.bicep'
import * as sharedFunctions from 'br/ac-registry:shared-functions:0.0.5'
```

Place the imports at the very top of the file, before the first `param`. Local type imports (e.g. `./types/`) come first; registry imports come second.

### Finding the latest version

When adding this import to a new file, query the dev ACR to get the latest tag:

```powershell
az acr repository show-tags `
  --name acracshareddevaz1a `
  --repository bicep/shared-functions `
  --orderby time_desc `
  --top 1
```

Use whatever version that returns. Always pin to the exact semantic version — never use a floating reference.

### Using the imported functions

Reference imported functions via the `sharedFunctions.` namespace:

```bicep
var deviceMeterServiceBusOptions = sharedFunctions.getServiceBusConfigSection(
  'DeviceMeterServiceBus',
  serviceBus.properties.serviceBusEndpoint,
  deviceMeterServiceBusTopicName,
  deviceMeterServiceBusSubscriptionName
)
```

### Avoid environment-conditional app setting unions

Do not branch on environment name to inject additional app settings. The pattern below is a standards violation:

```bicep
// Wrong — environment name check in template logic
var environmentConfig = [{ name: 'ASPNETCORE_ENVIRONMENT', value: 'Development' }]
var appConfigSettings = contains(environment, 'Production') ? ConfigSettings : union(ConfigSettings, environmentConfig)
```

If a setting needs to differ between environments, expose it as a `param` with a default, and override it in the environment-specific `.bicepparam` file. Templates must be environment-agnostic; environment differences belong in param files.

### `ASPNETCORE_ENVIRONMENT` (and `AZURE_FUNCTIONS_ENVIRONMENT`) must always be `'Production'` for deployed code

This is a fixed exception to the "expose it as a param" guidance above — it does **not** vary per environment. `Development` is reserved for a developer running the service locally (`dotnet run`, local `launchSettings.json`); every deployed environment — dev, test, and prod cloud tiers alike — must run with `ASPNETCORE_ENVIRONMENT=Production`. "Dev" and "test" describe *infrastructure* tiers, not the ASP.NET Core hosting environment.

Do not expose a bicep param (e.g. `aspnetcoreEnvironment`) that lets this vary by `.bicepparam` file, and do not override it in any environment's param file. The `app-service-linux` and `function-app` shared registry modules already default their `envMode` param to `'Production'` — the correct move is to omit `envMode` entirely and let that default apply everywhere, not to wire it up to `env.name` or any other per-environment value.

```bicep
// Wrong — lets ASPNETCORE_ENVIRONMENT vary by environment
param aspnetcoreEnvironment string = 'Development'
// ...
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    envMode: aspnetcoreEnvironment
  }
}

// Correct — omit envMode; the module's own default ('Production') applies to every deployed environment
module appServiceModule 'br/ac-registry:app-service-linux:...' = {
  params: {
    // envMode intentionally omitted
  }
}
```

If a param like `aspnetcoreEnvironment` already exists from before this standard was recorded, remove it (and any `envMode:`/`aspnetcoreEnvironment` overrides in `.bicepparam` files) rather than fixing its default — there is no legitimate value for it other than `'Production'`.

---

## Resource Naming Convention

### Every resource name param must have a computed default

Use `sharedFunctions.generateName`, `generatePrefix`, and `generateSuffix` to derive the default for every named resource param in `azuredeploy.bicep`. This makes the template self-documenting and means a new service can deploy with zero `.bicepparam` entries for resource names.

#### The formula

```bicep
param keyVaultName string = sharedFunctions.generateName(
  sharedFunctions.generatePrefix('KeyVault'),
  workload,
  sharedFunctions.generateSuffix(env, region, stamp)
)
```

For storage accounts (no hyphens allowed), wrap with `removeDashes`:

```bicep
param storageAccountName string = sharedFunctions.removeDashes(
  sharedFunctions.generateName(sharedFunctions.generatePrefix('StorageAccount'), workload, sharedFunctions.generateSuffix(env, region, stamp))
)
```

#### Standard workload component per resource type

| Resource | Workload component | Example default (`workload = 'asset'`) |
|---|---|---|
| App Service app | `workload` | `app-ac-asset-dev-az1a` |
| App Service plan | `workload` | `asp-ac-asset-dev-az1a` |
| App Service managed identity | `'${workload}-api'` | `id-ac-asset-api-dev-az1a` |
| Function App | `workload` | `func-ac-asset-dev-az1a` |
| Function App plan | `'${workload}-func'` | `asp-ac-asset-func-dev-az1a` |
| Function storage account | `'func-${workload}'` | `stacfuncassetdevaz1a` |
| Function managed identity | `'${workload}-func'` | `id-ac-asset-func-dev-az1a` |
| Key Vault | `workload` | `kv-ac-asset-dev-az1a` |
| Service storage account | `workload` | `stacassetdevaz1a` |
| Cosmos DB | `'shared-01'` | `cosmos-ac-shared-01-dev-az1a` |
| Service Bus | `'shared'` | `sb-ac-shared-dev-az1a` |
| Log Analytics Workspace | `'shared'` | `log-ac-shared-dev-az1a` |
| Application Insights | `'shared'` | `appi-ac-shared-dev-az1a` |
| App Configuration | `'shared'` | `appconfig-ac-shared-dev-az1a` |
| IoT Hub | `workload` | `iot-ac-asset-dev-az1a` |
| IoT Hub resource group | `'shared'` (with `ResourceGroup` prefix) | `rg-shared-dev-az1a` |
| Management resource group | `'management'` (with `ResourceGroup` prefix) | `rg-management-dev-az1a` |
| Shared resource group | `'shared'` (with `ResourceGroup` prefix) | `rg-shared-dev-az1a` |
| SQL server | `workload` | `sql-ac-asset-dev-az1a` |
| SQL database | `workload` (bare, no prefix) | `asset` |

The read-only SQL server and database default to `sqlServerName` and `sqlDatabaseName` respectively (param-to-param reference):

```bicep
param readOnlySqlServerName string = sqlServerName
param readOnlySqlDatabaseName string = sqlDatabaseName
```

#### `gameMediaBaseUrl` — derive from shared storage naming

The game media URL points to the shared storage account. Use `az.environment().suffixes.storage` — never hardcode `core.windows.net`:

```bicep
param gameMediaBaseUrl string = 'https://${sharedFunctions.removeDashes(sharedFunctions.generateName(sharedFunctions.generatePrefix('StorageAccount'), 'shared', sharedFunctions.generateSuffix(env, region, stamp)))}.blob.${az.environment().suffixes.storage}/'
```

#### When to override in `.bicepparam` files

Add a param entry only when the deployed name differs from the formula's output:
- Legacy or shared infrastructure with non-standard names (e.g. prod SQL server `aconnect`, prod IoT hub `AConnectReaderIOTHub`)
- The service uses a qualifier not in the standard formula (e.g. this service's app service names include `-api` — override `appServiceName` and `appServicePlanName` in each env param file with the actual name)

Do **not** override when the formula produces the correct name. The param file should be as short as possible.

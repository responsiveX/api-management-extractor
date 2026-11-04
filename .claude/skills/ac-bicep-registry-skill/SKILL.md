---
name: ac-bicep-registry-skill
description: >
  Reference and authoring guide for the AmusementConnect shared Bicep module registry
  (ac-bicep-registry). Use this skill when the user asks to add a new Bicep module to
  the shared library, look up what modules exist, check module parameters, or update
  the registry README. Trigger phrases include "add a module to the Bicep registry",
  "add to ac-bicep-registry", "create a shared Bicep module", "what modules are in the
  registry", and similar. Also triggers when working in the ac-bicep-registry repo.
---

# AC Bicep Registry Skill

Reference and authoring guide for the Amusement Connect shared Bicep module library.

---

## Registry

| Property | Value |
|---|---|
| Local path | `D:\Repos\ac-bicep-registry` |
| GitHub | `AmusementConnect/ac-bicep-registry` (private) |
| Purpose | Shared Bicep modules wrapping AVM with AC conventions |
| Branch | `develop` (default/mainline; `main` is stale — not present on origin) |

---

## Existing Modules

### `modules/app-service-linux`

Linux App Service (Web API) with staging slot, Application Insights, user-assigned managed identity, and Log Analytics diagnostics.

**Source:** `modules/app-service-linux/main.bicep` in the `ac-bicep-registry` repo (see `## Registry` for the local path) — read this file for the full, authoritative parameter list.

**Non-obvious conventions:**
- `dotnetVersion` is an **int** (e.g., `10`). The module constructs `DOTNETCORE|<n>.0` internally — do not pass the full string.
- `lock bool = false` — set `true` to apply a `CanNotDelete` management lock named `<name>-lock`. Enable in production; leave default elsewhere.
- `alwaysOn bool = true` — always pass `true` explicitly (see ac-bicep-standards).
- `workerCount int = 1` — desired instance count. Controls `numberOfWorkers` in siteConfig.
- Staging slot is deployed only for P0V3+ SKUs (not B-tier). App settings and connection strings are applied to the slot when deployed.

**Outputs:** `appServiceSlotName` — empty string when no slot is deployed.

---

### `modules/function-app`

Linux Function App (isolated worker) with staging slot, sticky per-function disable settings, Application Insights, user-assigned managed identity, and Log Analytics diagnostics. The caller owns the managed identity and storage account; this module only consumes them.

**Source:** `modules/function-app/main.bicep` in the `ac-bicep-registry` repo (see `## Registry` for the local path) — read this file for the full, authoritative parameter list.

**Non-obvious conventions:**
- `dotnetVersion` is an **int** (e.g., `10`). The module constructs `DOTNET-ISOLATED|<n>.0` internally — do not pass the full string.
- `lock bool = false` — set `true` to apply a `CanNotDelete` management lock named `<name>-lock`. Enable in production; leave default elsewhere.
- `alwaysOn` has no default — must always be passed explicitly as `true` (see ac-bicep-standards).
- `workerCount int = 1` — desired instance count. Controls `numberOfWorkers` in siteConfig.
- `functionNames string[]` — each entry creates an `AzureWebJobs.<name>.Disabled` app setting marked slot-sticky, allowing per-function enable/disable to survive a slot swap.
- Staging slot is deployed only for P0V3+ SKUs (not B-tier). App settings and connection strings are applied to the slot when deployed.

**Outputs:** `functionAppSlotName` — empty string when no slot is deployed.

---

### `modules/storage-account`

Storage account (StorageV2) built on `avm/res/storage/storage-account`, configured for OAuth-first authentication with shared key access disabled, public blob access, blob versioning and soft-delete, and Log Analytics diagnostics on the account, blob service, and file service. Also wires up standard RBAC role assignments for a set of additional service principals plus a reader and an admin group.

**Source:** `modules/storage-account/main.bicep` in the `ac-bicep-registry` repo (see `## Registry` for the local path) — read this file for the full, authoritative parameter list.

**Non-obvious conventions:**
- `allowSharedKeyAccess` is hardcoded `false` and `defaultToOAuthAuthentication` is hardcoded `true` — callers must authenticate with Entra ID, not account keys.
- `containerNames string[]` — each entry is created as a container with `publicAccess: 'Blob'`. This only controls anonymous *authorization* at the data plane — it does **not** make the container reachable from the public internet by itself. Network *reachability* is a separate, independent setting: `networkAcls.defaultAction` defaults to `'Deny'` (selected networks only), so a caller who wants these public containers actually fetchable from anywhere must also set `allowPublicNetworkAccess: true` (see below). Passing `containerNames` alone reproduces the exact confusing state of "public access enabled, but only from selected networks" in the Azure Portal.
- `additionalServicePrincipalIds string[]` (renamed from `userAssignedIdentityPrincipalIds` in `0.0.3` — the old name implied it was limited to compute-resource UAMIs, but the role-assignment loop treats every entry identically as `principalType: 'ServicePrincipal'`, so it's equally correct for a deploying pipeline's service connection SP) get Storage Blob Data Contributor + Storage File Data SMB Share Contributor (as `ServicePrincipal`). `adminPrincipalId` gets the same two roles as a `Group`. `readerPrincipalId` gets Storage Blob Data Reader + Storage File Data SMB Share Reader as a `Group`.
- Role definition IDs are hardcoded GUIDs (not names) matching the legacy non-AVM `storage.bicep` this module replaced.
- `enableWebsite bool = false` — enables static website hosting. The AVM module's `blobServices` type does not expose `staticWebsite`, so this is applied via a separate raw `Microsoft.Storage/storageAccounts/blobServices` resource (`existing` storage account reference + `dependsOn` the AVM module) pinned to the latest stable API version, `2026-04-01` — `staticWebsite` only appears in the ARM schema starting at `2025-08-01`; older versions only support it through the data-plane REST API. The blob service properties endpoint merges rather than replaces, so this does not disturb the retention/versioning settings the AVM module already configured.
- `enableWebsite` also drives `networkAcls.defaultAction` (added in `0.0.4`): `true` forces `'Allow'`, otherwise `'Deny'` (the AVM default). The static website endpoint is served through the same data-plane network ACL enforcement as everything else, so a network-restricted account is simply unreachable as a website — this isn't a pipeline-level concern, it's inherent to the feature. There's no supported way to combine `enableWebsite: true` with network restriction on this module.
- `lock bool = false` (added in `0.0.4`) — same `CanNotDelete`-lock-named-`<storageName>-lock` pattern as `app-service-linux`/`function-app`.
- `allowPublicNetworkAccess bool = false` (added in `0.0.5`) — sets `networkAcls.defaultAction: 'Allow'`, same effect as `enableWebsite: true` has on the firewall, but without turning on static website hosting. This is the param to set when a caller wants `containerNames` genuinely reachable from the public internet (e.g. firmware/theme assets served to field devices).
- `allowHttpTraffic bool = false` (added in `0.0.6`) — sets `supportsHttpsTrafficOnly: false` on the AVM module (the raw ARM property name; the AVM module doesn't rename it to `enableHttpsTrafficOnly` like some others do — confirmed against the module's actual allowed param list). Independent of `allowPublicNetworkAccess`/`enableWebsite`: those control network *reachability* (the firewall), this controls which *transport protocol* is accepted on requests that do reach the account. Needed for legacy devices/clients that can't negotiate TLS.

**Outputs:** `storageAccountName`, `resourceId`, `storageAccountUrl` (primary blob endpoint), `websiteUrl` (primary static website endpoint, empty string when `enableWebsite` is `false`).

---

### `modules/static-web-app`

Static Web App built on `avm/res/web/static-site`, optionally configured with custom Microsoft Entra ID authentication.

**Source:** `modules/static-web-app/main.bicep` in the `ac-bicep-registry` repo (see `## Registry` for the local path) — read this file for the full, authoritative parameter list.

**Non-obvious conventions:**
- `sku string = 'Standard'` — deliberately defaults to Standard, not Free (unlike a bare AVM default), because custom authentication (see next bullet) requires it. Pass `'Free'` explicitly for sites that don't need auth.
- `aadClientId string = ''` / `aadClientSecret securestring = ''` — when `aadClientId` is non-empty, this module sets exactly two app settings, `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET`. It does **not** write any `staticwebapp.config.json` or enforce any route restriction — that file lives with the site content (deployed separately, not by Bicep) and must reference these exact setting names under `auth.identityProviders.azureActiveDirectory.registration.clientIdSettingName`/`clientSecretSettingName`, plus its own `routes`/`allowedRoles` to actually require the `authenticated` role. Configuring a custom identity provider disables all of Static Web Apps' built-in providers for the site — a platform behavior, not something this module can toggle.
- `appSettings object = {}` — plain key/value object, matching `avm/res/web/static-site`'s own native shape. This differs from `app-service-linux`/`function-app`'s `appSettings array` (`{name, value}[]`), which matches `avm/res/web/site`'s shape instead. Don't assume the two modules' `appSettings` params are interchangeable.
- `lock bool = false` — same `CanNotDelete`-lock-named-`<name>-lock` pattern as the other modules.
- Content deployment (the actual site files) is entirely out of scope for this module and for Bicep in general — Static Web Apps content is pushed via a deployment token (`az staticwebapp secrets list --query properties.apiKey` + the Static Web Apps CLI: `npx @azure/static-web-apps-cli deploy`), a separate pipeline step from the ARM/Bicep deployment. Avoid the `AzureStaticWebApp@0` pipeline task for this — it expects `app_location` to resolve against a repo checkout, and fails ("App Directory Location ... is invalid") in a deploy job that only downloads a pipeline artifact with no `checkout: self`.
- `customDomainName string = ''` (added in `0.0.2`) — registers one custom domain on the site, always via `dns-txt-token` validation (never AVM's default `cname-delegation`), because this module assumes the domain sits behind an existing shared Front Door instance rather than CNAMEd directly to the static site. Read the `customDomainValidationToken` output after deploying and hand it to whoever manages DNS to add as a TXT record at `_dnsauth.<subdomain>` — not a secret, it's meant to end up in public DNS. The domain won't go `Ready` until that record is added; Azure validates it asynchronously in the background, not within the deployment itself. Getting the domain `Ready` is a separate concern from Front Door forwarding the real custom-domain `Host` header to the origin — both are required, and skipping the latter makes Easy Auth compute OAuth redirect URIs against the wrong hostname even once the domain validates.
- No `enterpriseGradeCdnStatus` (Static Web Apps' own managed Front Door-equivalent edge, distinct from fronting the site with an existing shared Front Door instance) support.

**Outputs:** `name`, `resourceId`, `defaultHostname` (`<name>.azurestaticapps.net`), `customDomainValidationToken` (empty string when `customDomainName` is empty).

---

### `modules/shared-functions`

Exported Bicep user-defined functions shared across modules in this registry. Contains `@export() func` declarations that can be imported by other Bicep files.

**Source:** `modules/shared-functions/main.bicep` in the `ac-bicep-registry` repo.

**Non-obvious conventions:**
- This module has no parameters, outputs, or resources — it is purely a function library.
- Import individual functions using the `import` statement: `import { myFunction } from 'br/ac-registry:shared-functions:0.0.1'`
- Version must be bumped in `version.txt` whenever any function is added or changed, same as other modules.

---

## Slot Deployment Logic

Both modules use the same rule: a staging slot is deployed only when the SKU supports it.

```
B1 / B2 / B3  →  no slot
S1+ / P0V3+   →  staging slot deployed
```

When a slot is deployed, `appSettings` and `connectionStrings` are applied to the **slot only** — they travel to the production slot during a swap.

---

## AVM Modules Used

| AVM Module | Current Version | Purpose |
|---|---|---|
| `br/public:avm/res/web/serverfarm` | `0.7.0` | App Service Plan |
| `br/public:avm/res/web/site` | `0.23.1` | App Service / Function App + slots + diagnostics |
| `br/public:avm/res/storage/storage-account` | `0.33.0` | Storage account |
| `br/public:avm/res/web/static-site` | `0.9.5` | Static Web App |

When adding a new module, always look up the latest published version for any AVM reference and pin to that version. Use the `documentation` MCP tool (`microsoft_docs_search` with a query like `"Azure Verified Modules avm/res web site changelog"`) to find the latest version number.

---

## Consuming Modules

Reference modules using the `br/ac-registry` alias defined in `bicepconfig.json`. Always pin to a specific version:

```bicep
module appService 'br/ac-registry:app-service-linux:1.0.0' = {
  name: 'app-service'
  params: { ... }
}
```

**bicepconfig.json** must exist in the calling project's `deploy/infrastructure/` folder. The file should default to the dev ACR for local development. Per-environment configs are selected by the pipeline before deployment — see the `ac-pipeline-standards` skill for the pipeline step pattern.

| File | Registry |
|---|---|
| `bicepconfig.json` (default) | `acracshareddevaz1a.azurecr.io` |
| `bicepconfig.dev-az1a.json` | `acracshareddevaz1a.azurecr.io` |
| `bicepconfig.test-az1a.json` | `acracsharedtestaz1a.azurecr.io` |
| `bicepconfig.prod-az1a.json` | `acracsharedprodaz1a.azurecr.io` |

---

## Action: Add a new module

**Trigger phrases:** "add a module to the Bicep registry", "add to ac-bicep-registry", "create a shared Bicep module"

### Steps

1. **Create the module directory and file**
   - Path: `D:\Repos\ac-bicep-registry\modules\<module-name>\main.bicep`
   - Use AVM modules for new resources. Look up the latest version for each AVM reference before writing it (see `## AVM Modules Used` and the AVM section of the `ac-pipeline-standards` skill).
   - Follow the same parameter conventions as existing modules: `appSettings array = []`, `connectionStrings array = []`, `tags object = {}`.

2. **Update `README.md`**
   - Add a new `###` section under `## Modules`.
   - Include the same table structure: parameters table (Parameter | Type | Required | Default | Description) and outputs table.
   - Add any new AVM modules used to the `## AVM Modules Used` table.

3. **Update this skill (`SKILL.md`)**
   - Add the new module to the `## Existing Modules` section using the same format.

4. **Commit and push**
   - Commit message format: `Add <module-name> module`
   - Push to `main`.

5. **Ask the user** whether to commit and push before doing so (per global instructions for the agents repo).

### Module authoring conventions

- `targetScope = 'resourceGroup'` at the top.
- `location` defaults to `resourceGroup().location`.
- Identity is always a **parameter** — modules never create their own managed identity.
- Diagnostic settings are always wired to `logAnalyticsWorkspaceId`.
- If the resource supports deployment slots, implement `deploySlots` logic using the same SKU check pattern: `var deploySlots = !contains(['B1', 'B2', 'B3'], skuParam)`.
- AVM versions: always look up the latest published version before writing the module reference. Use `microsoft_docs_search` (query: `"Azure Verified Modules avm/res <provider> <resource> changelog"`) and pin to the version returned. Update the `## AVM Modules Used` table in this skill file.

---
name: ac-pipeline-standards
description: Azure DevOps YAML pipeline standards for Amusement Connect. Use this skill when the user asks to reformat, fix, refactor, or author pipeline YAML files — including parameters, stages, jobs, steps, templates, and variables. Triggers on phrases like "reformat pipeline parameters to new format", "fix this pipeline", "add a parameter", "implement pipeline standards", or any instruction referencing Azure DevOps YAML files in the deploy/ folder. Also trigger automatically when a .yml file inside a deploy/ folder or any of its subfolders is opened in the IDE. For Bicep infrastructure files, use the ac-bicep-standards skill instead.
---

# Pipeline Skill

Azure DevOps YAML pipeline authoring and refactoring. Each action below defines a named operation the user can invoke by phrase.

---

## Action: Reformat pipeline parameters to new format

**Trigger phrases:** "reformat pipeline parameters to new format", "reformat parameters"

Reformat a `parameters:` block into the canonical explicit list style.

### Target format

```yaml
parameters:
  - name: param_name
    type: string
  - name: flag_param
    type: boolean
    default: true
    displayName: 'Flag Param'
  - name: optional_string
    type: string
    default: some_value
    displayName: 'Optional String'
```

### Rules

- Each parameter is a list item (`- name:`) under `parameters:`.
- Always include `type:`.
- Include `default:` only when a default value exists — omit it entirely otherwise.
- Include `displayName:` on top-level `pipeline.yml` parameters. On template files, `displayName:` is optional — do not add it if missing, but never remove it if it's already there.
- Preserve all existing parameter names, types, and default values exactly.
- Preserve the original ordering of parameters.
- Do not add, remove, or rename parameters.

---

## Action: Implement pipeline standards

**Trigger phrases:** "implement pipeline standards", "apply pipeline standards", "update pipeline to standards"

Read the open pipeline file(s) and apply all patterns defined in this skill. Work through each standard in order:

1. **Trigger policy** — ensure top-level `pipeline.yml` files declare `trigger: none` and `pr: none`. Template files do not need these.
2. **Parameter format** — reformat any `parameters:` blocks to the canonical list style (`- name:`, `type:`, `default:`). Add `displayName:` on `pipeline.yml` parameters. On template files, `displayName:` is optional — never add it where absent, and never remove it where already present. For top-level `pipeline.yml` files, check whether `deployAPIDefinitions` and `deployApplication` parameters are present. If either is missing, ask the user whether it should be added. If yes, add it with `type: boolean`, `default: true`, and a `displayName:`.
3. **Boolean flags: job-level gating** — if conditional steps are buried inside a job's `steps:` list, extract them into a separate named job gated with `${{ if eq(parameters.flag, true) }}:`.
4. **Boolean flags: caller gating for templates** — if a boolean flag is passed into a template as a parameter so the template can decide whether to run, move the gate to the caller using sequence insertion and remove the flag from the template's parameter list.
5. **`${{ if }}` / `${{ else }}`** — replace any `${{ if not(...) }}:` false-branch patterns with `${{ else }}:`.
6. **Sequence insertion indentation** — when jobs are wrapped in `${{ if }}:`, ensure all job properties are indented 2 spaces deeper than they were as plain list items, cascading through all descendants.
7. **`dependsOn` chaining** — verify the slot-swap chain (`deployInfrastructure` → `deployApplication` → `validateApplication` → `swapSlots`). Any job that reads `deployInfrastructure` outputs must list it directly in `dependsOn`.
8. **Conditions** — any job with a custom `condition:` must include `succeeded()` via `and(succeeded(), ...)`.
9. **Artifact download strategy** — remove any explicit `download: current` steps from deployment jobs (auto-download handles it). Ensure jobs that need no artifacts have `download: none` — except `pool: server` jobs, which must have no `download:` step at all (see the pattern below).
10. **List item indentation** — any sequence that is the value of a mapping key (`dependsOn:`, `steps:`, `parameters:`, etc.) must have its items indented 2 spaces deeper than the key. Items at the same indent level as their parent key (the YAML shorthand form) are ambiguous and must be fixed — add 2 spaces to every item in the list and cascade through all descendants.
11. **Azure subscription variables** — service connection names and subscription IDs must not be hardcoded as inline `name/value` variables. Remove any hardcoded `serviceConnectionDev`, `serviceConnectionTest`, `serviceConnectionProd`, `subscriptionIdDev`, `subscriptionIdTest`, `subscriptionIdProd` variables and replace with `- group: AzureSubscriptions`.
12. **Dependency governance gate** — the OSS vulnerability/license scan must be consumed from the shared `AmusementConnect/ac-ado-templates` repo via a `repository` resource pinned to `ref: refs/heads/develop` (never a version tag — the same checkout also supplies the shared `oss-exceptions.json` policy, which must always be current), never copied into the repo. There is no `dependencyGovernance` variable group to import anymore. Ensure the build job's `depends_on` includes `dependencyGovernance`. See the dependency governance gate pattern below.
13. **CODEOWNERS file** — ensure the repo has a `./docs/CODEOWNERS` file covering `/deploy/infrastructure/` and `/deploy/pipelines/`. See the CODEOWNERS pattern below.
14. **Code coverage** — the `Run Tests` task in `build-service.yml` must collect code coverage, and a `PublishCodeCoverageResults@2` task must publish it immediately after. See the code coverage pattern below.
15. **OpenAPI spec / client SDK templates** — if the repo builds/bundles OpenAPI specs, generates a C# client, or uploads specs to blob storage, those jobs must be consumed from the shared `ac-ado-templates` repo (`build-openapi-spec/`, `build-client-sdk/`, `deploy-api-specs/`), never copied locally. See the pattern below.
16. **Library variable group names** — variable groups are named for the application only (`Shirley`, `Shirley-Journeys`), never with an environment (`Shirley-dev`, `Shirley-<env>`). The environment goes on each variable as an underscore-separated suffix: `OperatorDashboardJwksUrl_dev`. See the variable group naming pattern below.
16. **No manual build tagging** — remove any `Tag the build` step (`git tag ...` / `git push origin ...`) from `build-service.yml`. Pipelines tag the build automatically now; a manual git-tag step is redundant. See the pattern below.

After applying all changes, report a summary of what was updated.

### Commit message

Derive the ticket tag from the current branch name — strip the `feature/`,
`bugfix/`, etc. prefix, take the ticket segment (e.g. `ab-4710` → `AB#4710`),
and uppercase the letters. Do not ask the user for the ticket number if it's
derivable from the branch name.

Commit pipeline-standards work on its own, separate from any Bicep work
(`ac-bicep-standards`), even in the same session:

```
[AB#4710] - Pipeline Upgrade
```

Never combine this with a Bicep phase number — a pipeline pass isn't a
Bicep phase, and Bicep work hasn't necessarily happened yet. Bicep standards
work gets its own commit under the convention defined in `ac-bicep-standards`
(`[AB#4710] - Bicep Upgrade Phase <n>`) — use that skill's convention rather
than duplicating the phase-numbering logic here.

---

## Pipeline Architecture: Deployment Tiers

All AC pipelines follow a three-tier execution model controlled by two boolean parameters.

### Parameters

| Parameter | Type | Default | Purpose |
|---|---|---|---|
| `deployAPIDefinitions` | boolean | true | Publish API definitions to API Management (APIM) |
| `deployApplication` | boolean | true | Build and deploy the application |

### Tier 1 — Always runs: Infrastructure

`deployInfrastructure` runs unconditionally in every execution.

- Deploys the Bicep template for the environment
- Extracts ARM outputs (app names, managed identity IDs, slot name, etc.)
- Adds managed identities to SQL AD groups

### Standard job order in the build stage

Jobs in the `buildArtifacts` stage must appear in this order:

1. `infrastructureArtifacts` — always runs
2. `buildPowershellArtifacts` — always runs
3. `apiArtifacts` — gated: `${{ if eq(parameters.deployAPIDefinitions, true) }}`
4. `dependency-governance/dependency-governance.yml@templates` then `build-service.yml` template — both gated together under the same `${{ if eq(parameters.deployApplication, true) }}` block, governance template first. The governance template is consumed from the shared templates repo and emits the `dependencyScan` + `dependencyGovernance` jobs (see the dependency governance gate pattern below); `build-service.yml` must set `depends_on: [dependencyGovernance]` so the build runs only after the gate passes. Gating the scan alongside the build — rather than running it unconditionally — means it only runs when there's actually an app being built.

---

### Tier 2 — Conditional: `deployAPIDefinitions`

When `true`:
- **Build stage:** copies APIM files and publishes an `ApiManagement` artifact
- **Deploy stage:** `deployApiMgmtObjects` ARM-deploys API templates to APIM via temp storage + SAS token

The `deployApiMgmtObjects` job uses auto-download — no explicit `download:` step is needed. The `ApiManagement` artifact is available in `$(Pipeline.Workspace)/ApiManagement` automatically.

### Tier 3 — Conditional: `deployApplication`

When `true`:
- **Build stage:** compiles .NET projects, packages them, publishes an `application` artifact
- **Deploy stage:**
  1. Deploy to Azure App Service
  2. Deploy to Azure Function App (to staging slot when `functionAppSlotName` is non-empty)
  3. `validateApplication` — manual validation gate (1-week timeout) if a slot is in use
  4. `swapSlots` — swaps staging → production after approval

### Dynamic `dependsOn`

The `deployApplication` job waits on different predecessors depending on flags:

```yaml
# deployAPIDefinitions = true
dependsOn: [deployInfrastructure, deployApiMgmtObjects]

# deployAPIDefinitions = false
dependsOn: [deployInfrastructure]
```

### Typical combinations

| `deployAPIDefinitions` | `deployApplication` | Use case |
|---|---|---|
| true | true | Full deployment |
| false | true | App-only deploy (infra + app, skip APIM) |
| true | false | APIM-only update (infra + APIM, skip app build/deploy) |
| false | false | Infrastructure-only run |

---

## YAML Patterns

### Trigger policy — always disable automatic triggers

Every top-level `pipeline.yml` must declare both `trigger: none` and `pr: none` at the top of the file. This prevents the pipeline from running automatically on code pushes or pull requests — all runs must be triggered manually or by an upstream pipeline.

```yaml
trigger: none
pr: none
```

Template files (`templates/*.yml`) do not need these — they are not independently runnable.

---

### `${{ if }}` / `${{ else }}` — use `else`, not a negated second `if`

Always use `${{ else }}:` for the false branch. Never repeat the condition with `${{ if not(...) }}:`.

```yaml
# Correct
${{ if parameters.deployAPIDefinitions }}:
  dependsOn:
    - deployInfrastructure
    - deployApiMgmtObjects
${{ else }}:
  dependsOn:
    - deployInfrastructure

# Wrong — do not do this
${{ if parameters.deployAPIDefinitions }}:
  dependsOn:
    - deployInfrastructure
    - deployApiMgmtObjects
${{ if not(parameters.deployAPIDefinitions) }}:
  dependsOn:
    - deployInfrastructure
```

### Boolean flags: gate at the job level, not the step level

When a boolean parameter controls whether a group of steps should run, extract those steps into their own job and gate the job with `${{ if eq(parameters.someFlag, true) }}:`. Do not use `${{ if }}:` inside a job's `steps:` list.

```yaml
# Wrong — conditional steps buried inside a job
- job: buildArtifacts
  steps:
  - task: CopyFiles@2        # always runs
  - ${{ if eq(parameters.deployAPIDefinitions, true) }}:
    - task: CopyFiles@2      # APIM files — don't do this

# Correct — separate job gated at the jobs level
- job: infrastructureArtifacts
  steps:
  - task: CopyFiles@2        # always runs

- ${{ if eq(parameters.deployAPIDefinitions, true) }}:
  - job: apiArtifacts
    steps:
    - task: CopyFiles@2      # APIM files
```

---

### Boolean flags: gate at the caller, not inside the template

When a boolean parameter controls whether a template runs at all, wrap the template inclusion at the caller using sequence insertion. Do **not** pass the flag into the template as a parameter.

```yaml
# deploy-environment.yml — caller gates the inclusion
- ${{ if eq(parameters.deployAPIDefinitions, true) }}:
  - template: deploy-api-management.yml
    parameters:
      environment_name: ${{ parameters.environment_name }}
      # deployAPIDefinitions is NOT passed — template is unconditional
```

```yaml
# deploy-api-management.yml — no boolean flag parameter
parameters:
  - name: environment_name
    type: string
  # ...
```

Templates should do one thing, always. The parent decides whether to invoke them.

Use the explicit equality form `${{ if eq(parameters.someFlag, true) }}:` rather than the shorthand `${{ if parameters.someFlag }}:`.

---

### `dependsOn` chaining for slot swap jobs

The correct dependency chain for the application deployment tier is:

```
deployInfrastructure
  └── deployApplication
        └── validateApplication
              └── swapSlots
```

**Rule:** Any job that reads `deployInfrastructure` runtime outputs in its `variables:` block must list `deployInfrastructure` in its `dependsOn` directly — even if it is already transitively covered by another dependency. Without the direct listing, the output references fail at runtime.

```yaml
- deployment: validateApplication
  dependsOn:
    - deployApplication      # ensures app is deployed first
    - deployInfrastructure   # required to access deployInfrastructure.outputs in variables

- deployment: swapSlots
  dependsOn:
    - validateApplication    # ensures validation passed
    - deployInfrastructure   # required to access deployInfrastructure.outputs in variables
  # deployApplication is NOT listed — succeeded() covers it transitively via validateApplication
```

`swapSlots` does not need `deployApplication` explicitly: `succeeded()` only checks direct dependencies, and `validateApplication` cannot succeed unless `deployApplication` succeeded first.

---

### Always use the explicit `eq` form for boolean parameter checks

Use `${{ if eq(parameters.flag, true) }}:` everywhere — never the shorthand `${{ if parameters.flag }}:`. This applies at both the job gate level and inside job properties like `dependsOn`.

```yaml
# Correct
${{ if eq(parameters.deployAPIDefinitions, true) }}:
  - job: apiArtifacts

# Wrong
${{ if parameters.deployAPIDefinitions }}:
  - job: apiArtifacts
```

---

### Artifact download strategy

Use auto-download for any job that needs artifacts — do not add explicit `download:` steps. Azure DevOps deployment jobs automatically download all pipeline artifacts before steps run; this is sufficient for both single and multiple artifact scenarios.

Only add `download: none` when a job needs **no artifacts at all** (e.g. `swapSlots`). This prevents unnecessary downloads on jobs that have nothing to retrieve.

```yaml
# Job that needs artifacts — no download step needed, auto-download handles it
- deployment: deployApplication
  strategy:
    runOnce:
      deploy:
        steps:
          - task: AzureRmWebAppDeployment@4  # artifacts already available in Pipeline.Workspace
            ...

# Job that needs no artifacts — explicitly disable auto-download
- deployment: swapSlots
  strategy:
    runOnce:
      deploy:
        steps:
          - download: none
          - task: AzureAppServiceManage@0
            ...
```

**Exception: never add a `download:` step — not even `download: none` — to a `pool: server` job.** `download` is itself implemented as a task that requires an agent, so Azure DevOps rejects it outright on an agentless server job (used for tasks like `ManualValidation@0`), regardless of the value: `'<jobName>' is a server job, but contains task 'Download' which can only run on agents.` This is a real compile-time failure encountered on `reporting-app`'s `testWebsite` job — a `pool: server` job needs no download step of any kind, since it never runs on an agent to download anything in the first place.

```yaml
# Wrong — server jobs can't have a Download step at all, even 'none'
- deployment: testWebsite
  pool: server
  strategy:
    runOnce:
      deploy:
        steps:
          - download: none   # compile error: server job, task 'Download' needs an agent
          - task: ManualValidation@0
            ...

# Correct — omit the download step entirely on server jobs
- deployment: testWebsite
  pool: server
  strategy:
    runOnce:
      deploy:
        steps:
          - task: ManualValidation@0
            ...
```

**Never use `download: <artifactName>`** (e.g. `download: infrastructure`) as shorthand for "download this one named artifact." That syntax is not valid for scoping to a specific artifact from the current run — non-`current`/non-`none` values for `download:` are meant to reference a `resources.pipelines` alias. If no such alias is declared (the normal case), Azure DevOps doesn't raise a compile error; it silently rejects the entire deployment job at the scheduling layer. The job never requests an agent, produces zero logs, and fails in under a second — the single most confusing failure mode encountered in this repo's pipelines, costing an entire debugging session on `ac-release-notes` (see build history around 2026-07-29) before being traced to this exact line. If you must scope to one artifact instead of auto-downloading everything, use the explicit two-property form instead:

```yaml
# Correct way to scope to one specific artifact (only when auto-download-all is undesirable)
- download: current
  artifact: infrastructure
```

---

### `ManualValidation@0` must not have a `displayName`

Adding `displayName:` to a `ManualValidation@0` task breaks the task. Omit it entirely and use a comment to describe intent if needed.

```yaml
- task: ManualValidation@0
  #displayName: 'Test Website' — NOTE: adding displayName to ManualValidation breaks the task
  inputs:
    notifyUsers: '...'
    instructions: '...'
```

---

### `pool: server` is required for agentless jobs

Any job that uses agentless tasks (e.g. `ManualValidation@0`) must declare `pool: server`. Omitting it causes the job to fail because it tries to run on an agent.

```yaml
- deployment: validateApplication
  pool: server   # required for ManualValidation@0
  strategy:
    runOnce:
      deploy:
        steps:
          - task: ManualValidation@0
```

---

### Conditions that include a slot-name check must also gate on `succeeded()`

When overriding `condition:` on a deployment job, the implicit `succeeded()` gate is lost. Always wrap custom conditions in `and(succeeded(), ...)` to restore it.

```yaml
# Wrong — runs even if a dependency failed
condition: or(ne(variables['functionAppSlotName'], ''), ne(variables['appServiceSlotName'], ''))

# Correct
condition: and(succeeded(), or(ne(variables['functionAppSlotName'], ''), ne(variables['appServiceSlotName'], '')))
```

This applies to any job with a custom `condition:`, not just slot-swap jobs.

---

### Sequence insertion (`${{ if }}:` wrapping multiple jobs)

When gating one or more jobs behind a compile-time conditional, use the sequence insertion form. Every job and all its properties shift **2 spaces deeper** than they were as a plain list item.

```yaml
# Plain job (- deployment: at 2 spaces, properties at 4)
  - deployment: myJob
    variables:
      foo: bar
    strategy:
      runOnce:
        deploy:
          steps:
            - task: SomeTask@1

# Gated job (- deployment: at 4 spaces, properties at 6)
  - ${{ if parameters.someFlag }}:
    - deployment: myJob
      variables:
        foo: bar
      strategy:
        runOnce:
          deploy:
            steps:
              - task: SomeTask@1
    - deployment: anotherJob
      ...
```

The `${{ if }}:` line sits at the same indentation as the original list items. Each item inside it indents by 2 more, and all descendant content cascades accordingly.

---

### List item indentation — items must be indented deeper than their parent key

Any sequence that is the value of a mapping key must have its items indented **2 spaces deeper** than the key. The YAML shorthand form — where items sit at the same column as their key — is technically valid but visually ambiguous and must not be used.

This rule applies to all mapping-valued sequences: `dependsOn:`, `steps:`, `parameters:`, `variables:`, `inputs:` sub-lists, etc.

```yaml
# Wrong — items at the same indent as the key (shorthand form)
      dependsOn:
      - deployApplication
      - deployInfrastructure
      variables:
        foo: bar

# Correct — items indented 2 deeper than the key
      dependsOn:
        - deployApplication
        - deployInfrastructure
      variables:
        foo: bar
```

The ambiguity is worst inside sequence insertion blocks, where everything has already shifted 2 spaces. A `dependsOn:` at 6-space with `- item` also at 6-space looks structurally identical to a sibling property — a reader cannot tell at a glance whether the list belongs to `dependsOn:` or to the parent mapping. Explicit indentation removes the ambiguity.

```yaml
# Wrong — inside sequence insertion, shorthand is especially confusing
    - deployment: swapSlots
      dependsOn:
      - validateApplication       # looks like a sibling of dependsOn, not a child
      - deployInfrastructure
      strategy:
        ...

# Correct
    - deployment: swapSlots
      dependsOn:
        - validateApplication     # clearly a child of dependsOn
        - deployInfrastructure
      strategy:
        ...
```

When fixing, cascade the 2-space shift through all descendants of the moved items.

---

### Azure subscription variables — use the `AzureSubscriptions` variable group

Service connection names and subscription IDs must not be hardcoded as inline `name/value` variables in `pipeline.yml`. Use the `AzureSubscriptions` variable group instead. This group is maintained centrally and provides the correct values for all environments.

```yaml
# Wrong — hardcoded inline variables
variables:
  - name: serviceConnectionDev
    value: ARM-AmusementConnect-Dev
  - name: serviceConnectionTest
    value: ARM-AmusementConnect-Test
  - name: serviceConnectionProd
    value: ARM-AmusementConnect-Prod
  - name: subscriptionIdDev
    value: 18c0005e-f8d5-413a-8147-4b26900fe038
  - name: subscriptionIdTest
    value: e6cc26d3-243a-4a58-a2a2-7a811b10fe43
  - name: subscriptionIdProd
    value: e5aeccd2-74ec-4ed0-b5c8-5f382db387c5

# Correct — use the shared variable group
variables:
  - group: AzureSubscriptions
```

---

### Library variable groups — named for the application, variables suffixed with the environment

Azure DevOps Library variable groups are named for the application, not for an environment. One group serves every environment. A group for a specific purpose adds a segment to the application name (`Shirley-Journeys`, `Shirley-LoadTest`), still without an environment.

Each variable in the group carries the environment as a suffix, separated by an underscore: the PascalCase name, `_`, then the lowercase environment abbreviation that the templates receive as `environment_abbreviation` (`dev`, `test`, `prod`).

| Group | Variables |
| --- | --- |
| `Shirley` | `UserPseudonymHmacKey_dev`, `UserPseudonymHmacKey_test`, `UserPseudonymHmacKey_prod`, `OperatorDashboardJwksUrl_dev`, ... |
| `Shirley-Journeys` | `JourneysBaseUrl_test`, `JourneysBaseUrl_prod`, ... |

In a template that deploys any environment, reference the group by its plain name and build the variable name with the template expression. The expression is resolved at compile time, so each stage reads its own environment's value.

```yaml
# Wrong — one group per environment, unsuffixed variables
variables:
  - group: Shirley-${{ parameters.environment_abbreviation }}
...
env:
  USER_PSEUDONYM_HMAC_KEY: $(UserPseudonymHmacKey)

# Correct — one group, environment-suffixed variables
variables:
  - group: Shirley
...
env:
  USER_PSEUDONYM_HMAC_KEY: $(UserPseudonymHmacKey_${{ parameters.environment_abbreviation }})
```

A job that only ever runs against one environment uses the literal suffix: `$(LoadTestUsers_test)`.

---

### Dependency governance gate — consume the shared template

The Trivy vulnerability + license scan that enforces the OSS Inclusion Policy lives as a **shared template** in `AmusementConnect/ac-ado-templates` (`dependency-governance/dependency-governance.yml`). Do **not** copy the template or its `Test-DependencyGovernance.ps1` script into the service repo — consume it via a `repository` resource. (The rollout mechanics — Trivy tiers, the exceptions schema, per-stack scan setup — live in the **`ac-dependency-governance`** skill.)

**1. Declare the repository resource, pinned to develop.** The same checkout is used both for the enforcement script and for the shared `oss-exceptions.json` policy, so it must track `develop` rather than a stable tag — the exceptions policy is meant to always be current.

```yaml
resources:
  repositories:
    - repository: templates
      type: github
      name: AmusementConnect/ac-ado-templates
      ref: refs/heads/develop         # must stay develop, never a tag
      endpoint: 'AmusementConnect'    # GitHub service connection name
```

`endpoint` must be a **literal** — the `resources:` block is evaluated at compile time, so a `$(...)` runtime variable will not resolve there.

**2. No exceptions variable group needed.** The gate reads `oss-exceptions.json` straight from the `templates` checkout — there is nothing to import into the consuming pipeline. Waivers are edited via PR against `oss-exceptions.json` on `develop` in `ac-ado-templates`, not per-repo.

**3. Reference the template in the build stage, gated together with the build.** Place the governance template inside the same `${{ if eq(parameters.deployApplication, true) }}:` sequence-insertion block as `build-service.yml`, governance first — it only matters when there's actually an app being built, so don't run it unconditionally:

```yaml
  - ${{ if eq(parameters.deployApplication, true) }}:
    - template: dependency-governance/dependency-governance.yml@templates
      parameters:
        scan_path: '$(Build.SourcesDirectory)'

    - template: templates/build-service.yml
      parameters:
        # ...
        depends_on:
          - dependencyGovernance     # build runs only if the gate passes
```

---

### OpenAPI spec / client SDK templates — consume the shared templates

Bundling an OpenAPI spec, generating a C# client from it, and uploading specs/docs to
blob storage are three separate concerns and three separate shared templates in
`AmusementConnect/ac-ado-templates` — do **not** copy any of them into the service repo:

| Template | Job | Does |
|---|---|---|
| `build-openapi-spec/build-openapi-spec.yml@templates` | `bundleApiSpec` | Lints + bundles the OpenAPI spec(s), publishes the bundled specs as a pipeline artifact, and (if `generate_html_docs`) builds + publishes an external-only HTML docs artifact. |
| `build-client-sdk/build-client-sdk.yml@templates` | `generateClientSdk` | Downloads the bundled specs artifact, generates + packs a C# client per spec via openapi-generator-cli, publishes the NuGet packages as a pipeline artifact, and pushes them to the feed. |
| `deploy-api-specs/deploy-api-specs.yml@templates` | `uploadApiSpecs` | Downloads the bundled specs + HTML docs artifacts and uploads them to blob storage. Runs per-environment inside `deploy-environment.yml`, not in the build stage. |

**Why split:** API-spec bundling/docs and client-SDK generation are independent concerns
with independent gates — a repo may want HTML docs without a client library, or vice
versa — and combining them into one template forced both concerns to share a single
`generate_*` boolean pair instead of being gated cleanly at the caller.

**Gating:** a repo typically has two flags — `buildAndUploadApiSpecs` (HTML docs +
blob upload) and `deployClientSdk` (C# client + NuGet push). Since the SDK job needs
the bundled spec regardless of whether HTML docs are wanted, gate `build-openapi-spec`
on `or(...)` of both flags and pass `generate_html_docs` through as
`buildAndUploadApiSpecs` — don't gate `build-openapi-spec`'s inclusion on
`buildAndUploadApiSpecs` alone or SDK-only runs will have no spec to generate from.

```yaml
- ${{ if or(eq(parameters.buildAndUploadApiSpecs, true), eq(parameters.deployClientSdk, true)) }}:
  - template: build-openapi-spec/build-openapi-spec.yml@templates
    parameters:
      openapi_specs:
        - file: src/openapi/reference/wallet-openapi3.yaml
          bundled_file_name: wallet-openapi3.yaml
          html_file_name: Wallet.html
      generate_html_docs: ${{ parameters.buildAndUploadApiSpecs }}

- ${{ if eq(parameters.deployClientSdk, true) }}:
  - template: build-client-sdk/build-client-sdk.yml@templates
    parameters:
      openapi_specs:
        - bundled_file_name: wallet-openapi3.yaml   # must match build-openapi-spec's entry
          csharp:
            namespace: AmusementConnect.Wallet.SDK
            apiName: WalletApi
      nuget_service_connection: $(nugetServiceConnection)
      depends_on:
        - bundleApiSpec       # required — generateClientSdk downloads bundleApiSpec's artifact
```

**Wiring rules:**
- `build-client-sdk`'s job must set `depends_on: [bundleApiSpec]` — it downloads the
  bundled-spec pipeline artifact produced by `build-openapi-spec`'s job, so without the
  explicit dependency the download can race (or run before) the publish.
- `spec_artifact_name` (default `openapi-specs`) must match across all three templates
  that touch it — `build-openapi-spec`, `build-client-sdk`, and `deploy-api-specs`.
  Same for `html_docs_artifact_name` between `build-openapi-spec` and `deploy-api-specs`.
- `deploy-api-specs` is a per-environment upload, called from inside
  `deploy-environment.yml` gated on `buildAndUploadApiSpecs` — it is not part of the
  build stage.

**Pin `openapi_generator_cli_version` — never `latest-release`:** `build-client-sdk`
takes an `openapi_generator_cli_version` parameter (default `v7.23.0` as of this
writing) instead of running `openapitools/openapi-generator-cli:latest-release`. That
floating tag drifted to `7.24.0` and broke every C# client generation with
`useSourceGeneration: true` — the generated `Api/*.cs` files call `RestLogEvents.*`
but the template omits the `using {packageName}.Logging;` needed to resolve it, so
`dotnet pack` fails `CS0103` on every consumer, regardless of pipeline wiring. This
reproduces with a bare `docker run ... generate` outside any pipeline — when an SDK
build that used to pass starts failing at the pack/compile step with no pipeline-side
change to explain it, suspect the floating generator tag before the pipeline YAML.
Confirm/bump the pin only after generating against a real spec and running
`dotnet pack` locally against the candidate version.

---

### CODEOWNERS file — required at `./docs/CODEOWNERS`

Every repo with pipeline/infrastructure files must have a `./docs/CODEOWNERS` file requiring devops review of deploy paths:

```
/deploy/infrastructure/ @AmusementConnect/devops
/deploy/pipelines/ @AmusementConnect/devops
```

If the file is missing, create it with this exact content. If it exists, ensure both lines are present without removing any other entries already there.

---

### Code coverage — collect and publish alongside test results

The `Run Tests` task in `build-service.yml` must collect code coverage and a `PublishCodeCoverageResults@2` task must publish it immediately after, so coverage shows up on the build summary the same way test results do.

```yaml
- task: DotNetCoreCLI@2
  displayName: Run Tests
  inputs:
    command: test
    projects: '**/*Unit.MsTest.sln'
    arguments: '--configuration ${{ parameters.build_configuration }} --collect "XPlat Code Coverage"'
    publishTestResults: true

- task: PublishCodeCoverageResults@2
  displayName: 'Publish Code Coverage'
  inputs:
    summaryFileLocation: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'
```

`--collect "XPlat Code Coverage"` appends onto the existing test task's `arguments` — it does not replace them. This triggers the cross-platform Coverlet data collector to emit a Cobertura-format report under `$(Agent.TempDirectory)`. `PublishCodeCoverageResults@2` is a separate step, not an input on the test task itself, and its `summaryFileLocation` glob (`**/coverage.cobertura.xml`) picks up the report regardless of which test project produced it.

---

### No manual build tagging — pipelines already tag the build automatically

`build-service.yml` must not contain a `Tag the build` step that manually creates and pushes a git tag (`git tag ${{parameters.build_number}}` / `git push origin ${{parameters.build_number}}`). Pipelines already tag the build automatically, so this step is redundant — remove it if found.

```yaml
# Wrong — remove this step entirely
- task: PowerShell@2
  displayName: 'Tag the build'
  inputs:
    targetType: inline
    script: |
      Write-Host "Tagging build with ${{parameters.build_number}}"
      git tag ${{parameters.build_number}}
      git push origin ${{parameters.build_number}}
```

There is no replacement step needed — just delete it.

---

# Bicep Standards

Bicep authoring standards have moved to the **`ac-bicep-standards`** skill. Load that skill for any `.bicep` file work, including SQL connection strings, AVM usage, and shared registry consumption.

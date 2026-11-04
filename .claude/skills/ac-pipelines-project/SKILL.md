---
name: ac-pipelines-project
description: Create a new pipelines improvement project in Azure DevOps — a Feature work item with child User Stories for each selected AC service. Use when the user asks to "create a new pipelines improvement project", "start a pipelines improvement project", "new pipeline improvement feature", or any similar phrase requesting a structured pipeline project. Also relevant when working under a deploy/infrastructure/ or deploy/pipelines/ folder.
---

# AC Pipelines Project Skill

Creates a structured Azure DevOps Feature with child User Stories covering each selected AC service.

## Trigger Phrases

- "create a new pipelines improvement project"
- "start a pipelines improvement project"
- "new pipeline improvement feature"
- "create a pipeline improvement project"

## Workflow

### Step 1 — Collect Feature details

Ask the user for:

- **Feature title** — will be appended to each child User Story name in the format `<Service Name> - <Feature Title>`
- **Feature description** — used as the Feature's description in ADO

Make clear in the prompt that **the Feature title will appear in every child User Story name**.

### Step 2 — Create the Feature in ADO

Create a new **Feature** work item in the `AC Projects` project of the `AmusementConnect` Azure DevOps organization.

Fields:
- **Title**: the title from Step 1
- **Description**: the description from Step 1
- **Area Path**: `AC Projects\Infrastructure`
- **Assigned To**: `bryan@amusementconnect.com`

Use `mcp_azure_devops__wit_create_work_item`:
- `project`: `AC Projects`
- `type`: `Feature`
- `title`: <user-provided title>
- `description`: <user-provided description>
- `areaPath`: `AC Projects\Infrastructure`
- `assigned_to`: `bryan@amusementconnect.com`

Confirm the Feature ID to the user before proceeding.

### Step 3 — Select services

Present the full list of AC services as a pre-checked checklist. Output the following message to the user verbatim (substituting the actual title), then wait for their reply:

---
All AC services are selected for this project. Reply with:
- Names of any services to **remove**, and/or
- **"add: \<Name\>"** (or **"+ \<Name\>"**) for any additional services to include

Or say **"all"** (or just press Enter) to proceed with all selected.

**Selected services:**
- [x] ACUtilitiesAPIV3
- [x] ACWebPlay
- [x] APIConnectV3
- [x] Mobile Connect
- [x] Kiosk Service
- [x] POS Service
- [x] Redemption Connect
- [x] Redemption Supplier
- [x] RMS Connect
- [x] Asset Service
- [x] Card API
- [x] Device Service
- [x] Link Service
- [x] Notification Service
- [x] OD2
- [x] Org Service
- [x] Player Connect
- [x] Reader API
- [x] Reporting API
- [x] Reporting App
- [x] User Service
- [x] Utility Service
- [x] Wallet Service
- [x] Scheduler
---

Parse the user's reply to determine the final set of selected services:
- Remove any service names they listed to deselect.
- Add any new names they listed after a phrase like "also add", "add:", or "+" to the selected set.

### Step 4 — Create child User Stories

For each selected service, create a child **User Story** under the Feature from Step 2.

Fields:
- **Title**: `<Service Name> - <Feature Title>`
- **Description**: `Implement pipeline features and improvements listed in the parent Feature`
- **Parent**: the Feature ID from Step 2
- **Area Path**: `AC Projects\Infrastructure`
- **Assigned To**: `bryan@amusementconnect.com`

Use `mcp_azure_devops__wit_create_work_item` for each:
- `project`: `AC Projects`
- `type`: `User Story`
- `title`: `<Service Name> - <Feature Title>`
- `description`: `Implement pipeline features and improvements listed in the parent Feature`
- `areaPath`: `AC Projects\Infrastructure`
- `parent_id`: <Feature ID>

After all User Stories are created, output a summary table:

| # | Work Item | Title |
|---|-----------|-------|
| Feature | #XXXX | <Feature Title> |
| Story | #XXXX | ACUtilitiesAPIV3 - <Feature Title> |
| Story | #XXXX | ACWebPlay - <Feature Title> |
| ... | ... | ... |

## ADO Configuration

- **Organization**: `AmusementConnect`
- **Project**: `AC Projects`
- **Area Path**: `AC Projects\Infrastructure`
- **Assignee**: `bryan@amusementconnect.com`

## Key Tools

- `mcp_azure_devops__wit_create_work_item` — create Feature and User Stories

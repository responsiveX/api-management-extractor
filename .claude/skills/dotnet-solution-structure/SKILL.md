---
name: dotnet-solution-structure
description: 'Use BEFORE changing the shape of a .NET solution, and do not skip it because the edit is one line of csproj or one attribute. Creating a solution or project; naming a project or namespace; adding a ProjectReference, PackageReference, or a serialization/ORM attribute that gives a type a new dependency; answering where a type, DbContext or DI registration lives; adding to a solution whose existing layout you would not have chosen; reviewing a .sln/.slnx/.csproj/Directory.Build.props change. Covers capability-oriented project and namespace names (never Application/Domain/Infrastructure/Persistence/Contracts/Models/Sdk; prefer Data.Abstractions + Data.<Backend>, Payments.Abstractions + Payments.Stripe); application-edge projects (Web.Api, Worker, Cli) vs host shells (Host.Functions); Api as the generated client package, no shared DTO assembly; the allowed project-reference graph; extension-method placement (Add/Use/Map/With).'
---

# .NET Solution & Project Structure

Lay out a solution so the tree tells you what the software does. Structure is enforced by
project references and by where registration happens — never by stamping pattern names into
namespaces.

**Precedence:** where this skill and an Amusement Connect skill (`dotnet-patterns`, `csharp-code-style`, `csharp-testing`, `api-design`, `caching`, `cosmos-documents`, `etags`, `service-bus`) disagree, the Amusement Connect skill wins.

## Existing conventions win

**These conventions govern new code and new solutions.** Where a codebase is already
internally consistent with a different choice, match what is there — do not convert it in
passing. Several rules below deliberately depart from a common default; applying one to half
a solution is worse than either convention applied consistently, and a diff that moves or
renames projects nobody asked about is a diff nobody can review. Propose a migration as its
own change and let the owner decide.

**Edit first, then say so.** Matching a local layout is still an implementation task. Make
the change with the matched shape on it, and *then* close the turn with the note below. The
note never substitutes for the edit.

**The note goes in the message that ends the turn** — not an earlier turn, and not a code
comment — and fills in this shape:

> Put it in `<the project you chose>` to match `<the local convention>`: `<the surrounding
> projects that evidence it>`. This skill would have used `<the counterfactual shape>` —
> `<the rule, in a clause>` — but one solution holding both layouts is worse than either.
> Converting `<the solution>` is a separate change.

Filled in, for a solution already laid out in layer-named projects:

> Put it in `Acme.Sales.Infrastructure` to match the local layer layout:
> `Acme.Sales.Application`, `Acme.Sales.Domain` and `Acme.Sales.Infrastructure` are the only
> projects here. This skill would have used `Acme.Sales.Data.Sql` — a project is named for
> the capability it provides, not the layer it sits in — but one solution holding both
> layouts is worse than either. Converting `Acme.Sales` is a separate change.

**Name the counterfactual — it is the clause that gets dropped.** "Matches the existing
layout" on its own is *not* the note: it leaves the reader unable to tell whether you knew
the rule and yielded to it or never knew it, which is the whole thing the note exists to
settle. Use the projects in front of you, not the example's.

## Start here

| Doing this | Read |
|---|---|
| Creating a solution | [Reference solution](#reference-solution), [Solution shapes](#solution-shapes) |
| Naming a project | [Project name patterns](#project-name-patterns), [Banned words](#banned-words) |
| Naming a host or entry point | [Applications and hosts](#applications-and-hosts) |
| Naming the published API client | [The API client package](#the-api-client-package) |
| Deciding which project a type belongs in | [Where a type goes](#where-a-type-goes) |
| Deciding whether to extract an interface | [How many interfaces](#how-many-interfaces) |
| Adding a ProjectReference | [Reference rules](#reference-rules), [Invariants](#invariants) |
| Wiring DI | [Registration](#registration) |
| Editing a .csproj / Directory.Build.props | [Project files](#project-files) |
| Adding or naming a test project | [Tests](#tests) |
| Reviewing a diff | [Review checklist](#review-checklist) |
| Working in an existing codebase | [Existing conventions win](#existing-conventions-win) |

**If the root application name has not been given, ask for it before generating anything.**
Every name below derives from it.

## Reference solution

The canonical layout. Copy this shape; omit what a solution doesn't need.

```
Contoso.Billing.slnx
Directory.Build.props            shared MSBuild properties
Directory.Packages.props         central package versions
NuGet.config                     explicit, pinned package sources
.editorconfig                    style + naming analyzer rules
src/
  Contoso.Billing/               core: model + operations. No vendor packages.
  Contoso.Billing.Api/           generated client package (from openapi.json)
  Contoso.Billing.Web.Api/       ASP.NET Core app: endpoints, DTOs it serves
  Contoso.Billing.Web.App/       Blazor/MVC UI
  Contoso.Billing.Worker/        background processing
  Contoso.Billing.Data.Abstractions/     IInvoiceRepository
  Contoso.Billing.Data.Sql/              EF Core, DbContext
  Contoso.Billing.Data.Core/             base types shared by Data.* implementations
  Contoso.Billing.Messaging.Abstractions/
  Contoso.Billing.Messaging.Azure.StorageQueue/
  Contoso.Billing.Payments.Abstractions/
  Contoso.Billing.Payments.Stripe/
  Contoso.Billing.Email.Abstractions/
  Contoso.Billing.Email.SendGrid/
  Contoso.Billing.Observability/
  Contoso.Billing.Hosting/       shared registration (optional)
  Contoso.Billing.Host.Functions/        only if a platform demands its own entry point
tests/
  .editorconfig                  test-only analyzer overrides (e.g. CA1707)
  Contoso.Billing.Tests/
  Contoso.Billing.Web.Api.Tests/
```

**Directory name == project file name == assembly name == root namespace.** No exceptions.
The solution file groups projects under `/src/` and `/tests/` folders mirroring the
directories, entries in ordinal path order.

### Placeholders

| Token | Means | Examples |
|---|---|---|
| `<App>` | root name — solution file, root namespace, core project | `Contoso`, `Contoso.Billing` |
| `<Context>` | a feature area | `Customers`, `Orders` |
| `<Capability>` | a technical capability the core depends on | `Data`, `Messaging`, `Payments`, `Email` |
| `<Backend>` / `<Partner>` | one implementation of a capability | `Sql`, `Stripe`, `SendGrid` |
| `<Vendor>` / `<Service>` | vendor family + specific service | `Azure.Cosmos`, `Aws.S3` |

`<App>` is either a bare application name (`Contoso`) or `CompanyName.ApplicationName`
(`Contoso.Billing`). Pick one form at solution creation and never mix them.

### Solution shapes

| Situation | Shape |
|---|---|
| Single API or service | **Capability projects** — core + one abstractions-and-implementation pair per capability + one application. The default. |
| Multiple interchangeable backends | **Capability backends** — one `<App>.<Capability>.<Backend>` per implementation, all behind one `<App>.<Capability>.Abstractions` |
| A large feature set | **Self-contained features** — one folder or namespace per feature area, each with its own model, operations, endpoints |
| Several apps over one system | **Modules** — `<App>.<Module>` projects, sharing only `<App>.Core` |

All four use the same naming rules and the same reference direction.

Start small: core, one capability pair, one application. Add a capability when a real need
appears. **When you add one, add both projects together** — an implementation without its
`.Abstractions` sibling has nowhere to put the interface.

## Naming

### The test

A project or namespace must answer **"what does this do?"**, not "where does this sit in the
architecture?" Three questions settle any candidate name:

1. **Does the word add information the rest of the name doesn't already carry?**
   `Contoso.Billing.Domain` — `Billing` already said that.
2. **Can you say what does *not* belong in it?** For `Data`: anything that doesn't talk to a
   store. For `Infrastructure`: nothing, which is the whole problem.
3. **Does .NET itself use the word?** The BCL and Azure SDK ship `.Abstractions`, `.Data`,
   `.Core`; they ship no `.Persistence`, `.Contracts`, or `.Sdk`.

### Banned words

Never in a project or namespace name.

| Banned | Use instead | Fails |
|---|---|---|
| `Domain` | the feature area (`Customers`, `Billing`) — or nothing; the core project is bare `<App>` | 1, 2 |
| `Application` | `UseCases`, `Operations`, `Workflows`, `Features` — or nothing | 1 |
| `Infrastructure` | the capability: `Data`, `Storage`, `Messaging`, `Payments`, `Caching`, `Security`, `Observability` | 2 |
| `Persistence` | `Data` | 3 |
| `Integrations` | the capability the partner serves — `Payments`, `Email`, `Crm`, `Tax` — vendor last | 1, 2 |
| `Contracts` | the project that owns the exchange: `<App>.Web.Api`, `<App>.<Capability>.Abstractions`, or `<App>` | 3 |
| `Models` | `<App>.<Context>` for domain types; the serving application for wire shapes | 1 |
| `Sdk` | `<App>.Api` — package named for the API, `Client` on the type | 3 |
| `Common`, `Shared`, `Utilities`, `Helpers`, `Misc` | a real capability name, or `Abstractions` / `Primitives` / `Core` | 2 |
| `Services` (top-level) | the feature area it serves | 2 |

Pattern names are acceptable only in teaching material and templates whose *purpose* is to
illustrate an architecture. Not in shipping code.

### Allowed vocabulary

`Abstractions` · `Api` · `Core` · `Data` · `Extensions` · `Host` · `Messaging` ·
`Observability` · `Primitives`

### Project name patterns

`<App>[.<Capability>][.<Vendor>][.<Service>]`, general to specific. **The vendor is always the
last segment, never the first grouping.**

| Kind | Pattern | Example |
|---|---|---|
| Core — model + operations | `<App>` | `Contoso.Billing` |
| A capability's interfaces | `<App>.<Capability>.Abstractions` | `Contoso.Billing.Data.Abstractions` |
| Data access | `<App>.Data.<Backend>` or `<App>.Data.<Vendor>.<Service>` | `Contoso.Billing.Data.Sql`, `<App>.Data.Azure.Cosmos` |
| Messaging | `<App>.Messaging.<Vendor>.<Service>` | `<App>.Messaging.Azure.StorageQueue` |
| External partner client | `<App>.<Capability>.<Partner>` | `Contoso.Billing.Payments.Stripe` |
| Shared plumbing for one capability | `<App>.<Capability>.Core` | `Contoso.Billing.Data.Core` |
| Shared plumbing for a published family | `<App>.Core` | `Contoso.Billing.Core` |
| Telemetry / logging / tracing | `<App>.Observability` | `Contoso.Billing.Observability` |
| Shared registration (optional) | `<App>.Hosting` | `Contoso.Billing.Hosting` |
| Published API client | `<App>.Api` | `Contoso.Billing.Api` |
| Applications and hosts | see below | |
| Tests | `<App>.<Target>.Tests`, `.UITests`, `.E2ETests` | `Contoso.Billing.Web.Api.Tests` |

**Abstractions are per capability, not per solution.** There is no global
`<App>.Abstractions`. Each capability's interfaces live beside the implementations that
satisfy them, as `Microsoft.Extensions.Logging.Abstractions` sits beside `.Logging.Console`.
A capability that exposes no interface to the core (`<App>.Observability`, `<App>.Hosting`)
needs no abstractions project.

**Sibling test:** do these projects implement the same interface? `Data.Sql` and `Data.Cosmos`
both satisfy `IInvoiceRepository` and an application picks one — siblings. `Payments.Stripe`
and `Email.SendGrid` implement nothing in common and an application registers both — not
siblings, so no name may imply they are.

### `<App>` vs `.Abstractions` vs `.Core`

| | `<App>` | `<App>.<Capability>.Abstractions` | `.Core` |
|---|---|---|---|
| Holds | entities, value objects, business rules, operations | interfaces and the types their signatures name | base classes, helpers, shared machinery |
| Knows your business | yes — it *is* the vocabulary | names it, declares no behavior | no — would work in any app |
| Behavior | yes | none | yes |
| Vendor packages | never | never | allowed |
| `<App>` may reference it | — | yes | **no** |

Decide with:

1. **Would deleting your business rules make this type pointless?** Yes → `<App>`.
2. **Does it run, or only declare?** No behavior → `.Abstractions`.
3. **Does `<App>` need it?** Then it cannot live in `.Core` — that reference is illegal.

```
<App>                          Invoice, Money, CreditLimitPolicy, CreateInvoiceHandler
<App>.Data.Abstractions        IInvoiceRepository, InvoiceFilter
<App>.Messaging.Abstractions   IEventPublisher, InvoiceRaised
<App>.Data.Core                DbExceptionMapper, RetryPolicy, ConnectionFactory
<App>.Core                     BillingClientOptions, BillingException
```

`Core` means the `Azure.Core` sense — shared plumbing for a family of packages — never the
`Microsoft.AspNetCore` sense, which is product branding. `<App>` is already the application's
core, so add `<App>.Core` **only** when you publish an `<App>.*` package family that needs
primitives shared across it. A single-solution app should not have one.

### Applications and hosts

The **application** is what the software does at its edge. The **host** is the platform shell
that starts it. Usually there is no host project, because the application starts itself.

| The application at the edge | Name it |
|---|---|
| HTTP API over ASP.NET Core | `<App>.Web.Api` |
| Server-rendered or Blazor web UI | `<App>.Web.App` (+ `<App>.Web.App.Client` for WASM) |
| Background processing | `<App>.Worker` |
| gRPC service | `<App>.Grpc` |
| Command-line tool | `<App>.Cli` |
| Separately-hosted SPA (not a .NET project) | `<App>.Web` or `<App>.Frontend` |

**A deployment target is never a project.** App Service, Container Apps, AKS, ACA, Docker, and
a VM all run the same `<App>.Web.Api` unchanged — the Dockerfile is a file in the project, the
cluster manifests are infrastructure. Never create `<App>.Host.AppService` or `<App>.Host.Aks`.

**`<App>.Host.<Platform>` exists only when a platform imposes its own entry point** — its own
SDK, program model, or manifests — so the application cannot start itself:

| Platform | Host project | References |
|---|---|---|
| Azure Functions | `<App>.Host.Functions` | `<App>` and the capabilities its triggers need |
| Service Fabric | `<App>.Host.ServiceFabric` | `<App>.Web.Api`, hosted as a stateless service |
| Windows Service | `<App>.Host.WindowsService` | `<App>.Worker` |

The host is a shell: entry point, manifest, platform packages. No endpoints, no business
logic. `<App>.Web.Api` stays unaware of what starts it.

`<App>.Hosting` (shared registration library, matching `Microsoft.Extensions.Hosting`) is
unrelated to `<App>.Host.*` (platform shells) despite the near-spelling. If the pair reads as
confusable, `<App>.Hosting` is the optional one — inline its `Add…` calls and drop it.

Prefer `Web.App` over `Web.Ui`. Reserve a `Ui` name for a genuinely passive shell: no business
logic, no orchestration, no policy, thin view-model mapping only.

### The API client package

`<App>.Api` is the NuGet package a consumer installs to call your API. It holds the client and
the request/response shapes, and **it is generated from the OpenAPI document.**

```
<App>.Web.Api/      InvoicesController.cs, CreateInvoiceRequest.cs   → emits openapi.json
<App>.Api/          [generated] BillingClient.cs, CreateInvoiceRequest.cs
                    references nothing in this solution
```

**No project reference in either direction.** The serving application owns its request and
response types; the generated client carries its own copies. The contract is the OpenAPI
document plus contract tests, not a shared assembly. Wire generation into the build.

Rejected alternatives, and why:

| Alternative | Why not |
|---|---|
| Server references the client package | Drags `HttpClient`, retry, and auth handlers into production for code it can never call |
| Client references the server | Inverts the dependency |
| Shared shapes assembly | `Contracts` under another name — everything depends on it, nothing owns it |

Naming follows the platform: **package carries the service name, the type carries `Client`.**
`Azure.Storage.Blobs` → `BlobServiceClient`. `Microsoft.PowerBI.Api` → `PowerBIClient`. So
`Contoso.Billing.Api` → `BillingClient`. Never `<App>.Sdk`.

**The default surface takes no qualifier** — `<App>.Api` *is* the API. Name a second surface
only when it exists:

| Surface | Package |
|---|---|
| The API — public, typically fronted by API Management | `<App>.Api` |
| A separate surface for callers inside the trust boundary | `<App>.Api.Internal` |
| Versions of either | `<App>.Api.V2`, `<App>.Api.Internal.V2` |

Split only when the shapes actually diverge.

## Placement

### Namespaces inside a project

Namespaces mirror the folder path exactly, file-scoped, one per file. **Group by feature area
first**, then by role within it. Role folders (`Policies/`, `Operations/`, `Endpoints/`) are
fine *inside* a feature area; they are never the top-level split.

```
src/<App>/
  Customers/
    Customer.cs                → namespace <App>.Customers;
    CreditLimitCalculator.cs   → namespace <App>.Customers;
    CreateCustomerHandler.cs   → namespace <App>.Customers;
    Policies/                  → namespace <App>.Customers.Policies;
  Orders/
    Order.cs                   → namespace <App>.Orders;
```

Generated-code directories whose namespaces a tool controls are the only exception.

### Where a type goes

| The type is… | Project | Namespace |
|---|---|---|
| entity, value object, enum | `<App>` | `<App>.<Context>` |
| a business rule with no infrastructure needs | `<App>` | `<App>.<Context>` or `.<Context>.Policies` |
| an operation orchestrating repositories, messaging, policies | `<App>` | `<App>.<Context>` |
| an interface whose signature carries domain types | `<App>` | `<App>.<Context>` |
| a capability interface, signature free of domain types | `<App>.<Capability>.Abstractions` | that project + `.<Context>` |
| an event or message payload an interface names | `<App>.Messaging.Abstractions` | that project + `.<Context>` |
| a data-access implementation | `<App>.Data.<Backend>` | that project + `.<Context>` |
| a queue/topic implementation | `<App>.Messaging.<Vendor>.<Service>` | that project + `.<Context>` |
| a third-party adapter | `<App>.<Capability>.<Partner>` | that project + `.<Context>` |
| a base type several implementations of one capability share | `<App>.<Capability>.Core` | that project |
| a primitive shared across a published `<App>.*` family | `<App>.Core` | `<App>.Core` |
| logging enricher, meter, tracer, `TimeProvider`, ID generator | `<App>.Observability` | `<App>.Observability` |
| `DbContext`, entity configurations | the data project for that backend | `<App>.Data.Sql` |
| endpoint, controller, middleware, filter, request/response DTO | the application that serves it | `<App>.Web.Api.Endpoints`, `.Requests`, `.Middleware` |
| the generated client and its copies of the wire shapes | `<App>.Api` | `<App>.Api` |

How each of these is *spelled* is the dotnet-naming-conventions skill; this table decides
only where it lives. `DbContext` is a vendor type — it never appears in `<App>` or in an
abstractions project,
because neither takes vendor packages.

### Where "service" classes go

| It really is… | Goes | Named |
|---|---|---|
| business behavior that doesn't fit on an entity | `<App>`, in the feature area | `CreditLimitCalculator`, `TaxPolicy` |
| orchestration of a multi-step operation | `<App>`, in the feature area | `CreateCustomerHandler`, `OrderSubmission` |
| an adapter to an external system | `<App>.<Capability>.<Partner>` | `SendGridEmailSender`, `StripePaymentGateway` |
| a capability implementation | the capability project | `CustomerRepository`, `OrderOutbox` |
| cross-cutting technical plumbing | `<App>.Observability` / `<App>.Hosting` | `CorrelationIdEnricher` |

```
❌ <App>.Application.Services.CustomerService
❌ <App>.Infrastructure.Services.EmailService
❌ <App>.Persistence.CustomerRepository
❌ <App>.Integrations.Email.SendGridEmailSender

✅ <App>.Customers.CreateCustomerHandler
✅ <App>.Data.Sql.Customers.CustomerRepository
✅ <App>.Email.SendGrid.SendGridEmailSender
```

**Never create a top-level `Services` namespace or project.** A `Services` folder inside a
feature area is tolerable when the class names within it stay meaningful. If a solution
already has an `<App>.Services` project, put new work in the feature-area namespace and
migrate opportunistically — don't split a working solution mid-feature.

How these types are *spelled* — noun phrases, the `I` prefix, `{Purpose}DbContext`,
`{Action}{Resource}Request` — is the dotnet-naming-conventions skill. The `Service`
*suffix* is not itself a smell — `IHostedService` and genuine external-service
adapters are fine. The smell is a per-entity service accreting every operation on that entity.

### How many interfaces

How to *name* an interface — the `I` prefix, capability adjectives vs role nouns, the
`Get`/`Find`/`Try` contract — is the dotnet-naming-conventions skill. The structural question
is how many to have.

**Extract fewer than instinct suggests.** The Framework Design Guidelines favor classes over
interfaces; an `IFoo`/`Foo` pair with one implementation and no mocking need is ceremony.
Extract an interface when:

- a second implementation exists or is genuinely planned — the capability seams in this layout
  (data, messaging, payments, email) are exactly these; or
- a test needs to substitute across a process or network boundary.

Not because a class has public methods.

The per-capability `.Abstractions` project is a rule about *placement*, not a quota. A
capability with three repository interfaces and thirty internal types is normal; one with
thirty interfaces has not been designed.

## References

The graph is acyclic and flows strictly downward. **Never add a reference that points up, or
sideways across an implementation boundary.**

```
applications   <App>.Web.Api   <App>.Worker   <App>.Web.App ──> <App>.Api (generated)
                     │               │
capabilities   <App>.Data.Sql   <App>.Payments.Stripe   <App>.Observability
                     │
core           <App>
                     │
interfaces     <App>.Data.Abstractions   <App>.Messaging.Abstractions
```

`.Core` projects sit beside the implementations that use them, off this spine. A
`<App>.Host.<Platform>` shell sits above it and references only the application it starts.
`<App>.Api` is off the spine entirely — generated, referenced only by callers of the API.

### Reference rules

| Project | May reference |
|---|---|
| `<App>` | the `<App>.*.Abstractions` projects only — no implementations, no `.Core`, no vendor packages |
| `<App>.<Capability>.Abstractions` | nothing — **never `<App>`**, never `.Core`, never another capability's abstractions |
| `<App>.Core` | nothing |
| `<App>.<Capability>.Core` | `<App>.Core` and its own `<App>.<Capability>.Abstractions` |
| `<App>.<Capability>.<Backend\|Partner>` | `<App>`, its own `.Abstractions`, its own `.Core` |
| `<App>.Messaging.<Vendor>.<Service>` | `<App>.Messaging.Abstractions`, plus `<App>` only if messages carry domain types |
| `<App>.Observability` | nothing, or `<App>.Core` |
| `<App>.Api` | nothing in this solution — it is generated |
| `<App>.Hosting` | every capability project the applications it wires compose |
| Applications (`.Web.Api`, `.Web.App`, `.Worker`, `.Grpc`, `.Cli`) | `<App>`, the `.Abstractions` projects, each capability implementation (or just `<App>.Hosting`). One that *calls* an API also references that API's generated client |
| `<App>.Host.<Platform>` | the one application it starts, and nothing else |
| `<App>.Web.App` | `<App>.Api`, and `<App>.Web.App.Client` for WASM — **not** the API's server-side projects |
| Test projects | only the projects under test; referenced by nothing |

### Invariants

- **The core project takes no vendor packages.** A database, cloud, or HTTP client package in
  `<App>` is a design defect.
- **Capability projects never reference each other.** A shared type belongs in `<App>`, or in
  `<App>.Core` if it is plumbing rather than model — never in one capability's
  `.Abstractions`, which is private to that capability's implementations.
- **An implementation references its own capability's abstractions and no other's.** If a
  repository needs to publish an event, the operation in `<App>` does it.
- **Core never references a capability project.** If an operation needs a vendor type, the
  abstraction is wrong — fix the abstraction.
- **Only applications (or `<App>.Hosting`) reference capability projects.**
- **Abstractions never reference back up into `<App>`** — that closes a cycle. So an interface
  in `<App>.Data.Abstractions` cannot name a domain entity in its signature: one that needs
  `Order` or `Customer` stays in `<App>` beside the operation that consumes it.
- **Interfaces and their implementations live in different projects.**
- **UI reaches the API over HTTP through `<App>.Api`** — never a direct project reference to
  the API's server-side projects.
- Abstractions projects take `*.Abstractions` packages only, never concrete implementations.

**If a needed reference is illegal, the type placement is wrong. Move the type; do not add the
reference.**

## Registration

### Extension methods go in the extended type's namespace

Declare the extension in the namespace of the type it extends, **not** your project's
namespace. This is why `AddDbContext(…)` resolves without a `using` for EF Core.

```csharp
// file: src/<App>.Data.Sql/DependencyInjection.cs
namespace Microsoft.Extensions.DependencyInjection;   // ← not <App>.Data.Sql

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddDataSql(this IServiceCollection services, …)
}
```

An application should never need a `using` for a capability project just to register it.

### Registration rules

- Every project with something to register owns one `DependencyInjection.cs` at its root.
- Name the extension `Add` + the project name minus the root prefix and the dots —
  `AddDataSql`, `AddMessagingAzureStorageQueue`, `AddPaymentsStripe`, `AddObservability`.
  Include the `<App>` prefix (`AddContosoBillingDataSql`) when the assembly is published for
  others to consume. Be consistent across the solution.
- Signature is `(this IServiceCollection services, IConfiguration configuration)`, returning
  `services` for chaining.
- Configuration is read **inside** the extension, never in the application. A missing required
  setting throws `InvalidOperationException` naming the config key.
- **Abstractions projects register nothing** and own no `DependencyInjection.cs` — the
  implementation registers the interface it satisfies. Where two backends implement one
  interface, each application calls exactly one of them.
- Each application calls only the extensions it needs — deliberate composition, not one
  god-method. `<App>.Hosting` may bundle the standard set when several applications share it.
- Register interface → implementation. An application resolving a concrete implementation type
  bypasses the seam the interface exists to create.
- Lifetimes: repositories and operations `Scoped`; expensive thread-safe platform clients
  `Singleton`; stateful per-operation helpers `Transient`.

### `Add` / `Use` / `Map` / `With` are not interchangeable

| Prefix | Operates on | Examples |
|---|---|---|
| `Add…` | `IServiceCollection` — registers services | `AddControllers`, `AddAuthentication` |
| `Use…` | `IApplicationBuilder` — inserts middleware | `UseRouting`, `UseAuthorization` |
| `Map…` | endpoint routing — declares a route | `MapGet`, `MapControllers`, `MapHealthChecks` |
| `With…` | the value just returned — fluent configuration | `WithName`, `WithTags`, `WithOpenApi` |

### Options

Bind configuration to a `{Feature}Options` class from a config section named for the type
minus the `Options` suffix. Consume as `IOptions<T>` (singleton), `IOptionsSnapshot<T>`
(per-request), or `IOptionsMonitor<T>` (change-notified).

**Never inject `IConfiguration` into a service** — that leaks the configuration system into
code that should take typed settings.

## Project files

### csproj

**Reference copies of `Directory.Build.props`, `Directory.Packages.props`, and `NuGet.config`
ship in `resources/`.** Copy them rather than re-deriving.

`Directory.Build.props` at the repo root supplies everything shared, so each `.csproj` stays
near-empty:

```xml
<Project>
  <PropertyGroup>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
  </PropertyGroup>
</Project>
```

Each project sets only what is genuinely project-specific:

- `TargetFramework` — the same value across the solution; set per project.
- The SDK attribute — `Microsoft.NET.Sdk` for libraries, console apps, and serverless workers;
  `Microsoft.NET.Sdk.Web` for web applications; `Microsoft.NET.Sdk.BlazorWebAssembly` for WASM
  clients.
- `<IsPackable>false</IsPackable>` on tests; packaging metadata only on published projects.

**Do not repeat properties already in `Directory.Build.props`** — redeclaring is noise and
silently diverges when the shared file changes. Ordering: `PropertyGroup`, then an `ItemGroup`
of `ProjectReference`, then an `ItemGroup` of `PackageReference`, each alphabetical.

### Packages

Use central package management: versions in `Directory.Packages.props` with
`<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`, and bare
`<PackageReference Include="…" />` with no `Version` in each project.

Without it, versions are pinned inline — then **match the version already used elsewhere in
the solution** rather than taking the newest, and bump a shared package everywhere in the same
change. Keep framework package families (`Microsoft.Extensions.*`) on one version matching the
target framework. `NuGet.config` clears inherited sources and lists them explicitly.

### Tests

Test projects live in `tests/<Name>/` and register under the solution's `/tests/` folder.
They reference only the projects under test, and are referenced by nothing.

- Name them `<App>.<Target>.Tests`, where `<Target>` is the project or seam under test.
- **Use `MSTest.Sdk` as the project SDK** — `<Project Sdk="MSTest.Sdk/x.y.z">`. It supplies the
  framework, the runner, the analyzers and the implicit usings on aligned versions, so none of
  those are `PackageReference`s and none belong in `Directory.Packages.props`.
- **Do not add `Microsoft.NET.Test.Sdk`.** That is the VSTest host; these projects run on
  Microsoft.Testing.Platform, which embeds its runner in the test assembly.
- Set `<IsPackable>false</IsPackable>`.
- Keep every test project on the same `MSTest.Sdk` version.

How the tests inside these projects are written and named — `[TestClass]`, the
`{Method}_Should{Expected}_When{Scenario}` form, assertions, `MSTestAnalysisMode` — is the
[dotnet-unit-testing](../dotnet-unit-testing/SKILL.md) skill.

Map test projects to **seams**, not one-per-source-project — a single project may cover the
core model plus its operations. Split when fixtures diverge: in-memory unit tests vs.
emulator-backed integration tests vs. `WebApplicationFactory` contract tests vs. browser E2E.

## Checklists

### Adding a project

1. Confirm the root `<App>` name and the solution shape.
2. Pick the name from [Project name patterns](#project-name-patterns). Run the three tests.
3. If it's a capability implementation, create its `<App>.<Capability>.Abstractions` sibling in
   the same change, or confirm one exists.
4. Create `src/<Name>/<Name>.csproj`; verify directory, project, assembly, and root namespace
   all match.
5. Check intended references against [Reference rules](#reference-rules). If one is illegal,
   move the type instead of adding the reference.
6. Set only `TargetFramework` and the SDK attribute; inherit the rest.
7. Add `DependencyInjection.cs` if the project registers anything.
8. Register in the solution file under `/src/`, in ordinal path order.
9. Add or extend a `tests/` project under `/tests/`.
10. Call the new `Add…` extension from each application that needs it.

### Review checklist

Reject a change that does any of these:

- [ ] Introduces a banned word in a project or namespace name.
- [ ] Puts the vendor anywhere but the last segment.
- [ ] Adds a project whose name differs from its directory, assembly, or root namespace.
- [ ] Adds a `Host.<Platform>` project for a deployment target rather than a program model.
- [ ] Adds a vendor package to `<App>` or to any `.Abstractions` project.
- [ ] References up the graph, sideways between capabilities, or from `<App>` into `.Core`.
- [ ] Creates a shared DTO/contracts project, or a reference between the API server and its
      client package.
- [ ] Adds an implementation without its `.Abstractions` sibling.
- [ ] Registers services from an abstractions project, or resolves a concrete type in an
      application.
- [ ] Declares a DI extension in the project's own namespace rather than the extended type's.
- [ ] Injects `IConfiguration` into a service.
- [ ] Repeats a `Directory.Build.props` property in a `.csproj`.

## Before you end the turn

**If the prompt asked for code — *add*, *write*, *rename*, *create* — the file must be edited
before you answer.** Naming the member, writing its signature in the reply, or explaining what
the right shape would be is not the change. The workspace is what the next person gets, and an
unedited workspace means the task is not done however correct the analysis above it.

Re-read the verb in the prompt. If it was *add*, something must have been written. "No changes
needed" answers a question nobody asked when the prompt named a file and told you to add to it.

The checklist above is for reviewing a diff someone else wrote — that is the one case where the
finding *is* the deliverable. It is not a substitute for work you were asked to do.

**Declining part of a prompt does not cancel the rest of it.** When a rule here forbids the
edit you were asked to make, the refusal answers *that* clause only — every other deliverable
the prompt named is still owed. "Add the reference, then write what you did and why to
`answer.md`" still requires `answer.md`: it is where the refusal, the rule behind it, and the
compliant alternative go. Skipping the artifact because you skipped the edit leaves the
workspace with no trace that the question was ever asked, and the reasoning stranded in a chat
message nobody reviews.

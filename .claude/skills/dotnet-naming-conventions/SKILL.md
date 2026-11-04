---
name: dotnet-naming-conventions
description: 'Use for EVERY C# edit that introduces or renames an identifier, and do not skip it because the change is one line or the name looks obvious. So do an interface method, a constructor parameter and its field, an enum and its zero value, a `[Flags]` enum and its members, a const, a type. It applies when the prompt already supplies the name - a supplied name is a name to check, not a naming question already settled. Also for reviewing a diff for naming and for writing .editorconfig naming rules. Follows the Framework Design Guidelines and BCL/EF Core practice: casing and field prefixes (_, s_, t_); acronyms vs abbreviations (Id not ID, Db not DB, IPAddress not IpAddress); noun-phrase type names; the Get/Find/Try contract; the Async suffix; framework suffixes (DbContext, Controller, Factory); date and time identifiers (tense, Utc/Local, TimeZoneId, no At/On suffix). Test names come from dotnet-unit-testing instead. Ships a reference .editorconfig.'
---

# .NET Naming Conventions

Baseline is the [Framework Design Guidelines](https://learn.microsoft.com/dotnet/standard/design-guidelines/naming-guidelines)
and the [C# coding conventions](https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions).
Where they are silent, follow what the BCL and mainstream OSS actually do. Where a project
deliberately deviates, document it and enforce it in `.editorconfig`.

**Precedence:** where this skill and an Amusement Connect skill (`csharp-code-style`, `csharp-testing`, `csharp-logging`, `dotnet-patterns`, `api-design`, `caching`, `cosmos-documents`, `etags`, `service-bus`) disagree, the Amusement Connect skill wins.

**The deliverable is the edited file.** On any task that asks for code — add a member,
rename one, introduce a field — apply the name this skill gives you *by editing the file*, and
end the turn with the edit made. A reply that names the member without writing it leaves
the task undone, however right the name is. Reviewing a diff is the one case where the
finding *is* the deliverable.

## Existing conventions win

**These conventions govern new code and new solutions.** Where a codebase is already
internally consistent with a different choice, match what is there — do not convert it in
passing. Several rules below deliberately depart from a common default; applying one to
half a codebase is worse than either convention applied consistently, and a diff that
renames things nobody asked about is a diff nobody can review. Propose a migration as its
own change and let the owner decide.

**Edit first, then say so.** Matching a local convention is still an implementation task.
Write the member into the file with the matched name on it, and *then* close the turn with
the note below. The note never substitutes for the edit.

**The note goes in the message that ends the turn** — not an earlier turn, and not a code
comment — and fills in this shape:

> Named it `<the name you chose>` to match `<the local convention>`: `<the surrounding
> declarations that evidence it>`. This skill would have named it `<the counterfactual
> name>` — `<the rule, in a clause>` — but one file holding both conventions is worse than
> either. Converting `<the codebase>` is a separate change.

Filled in, for a repository that suffixes every `Task`-returning member:

> Named it `GetCustomerAsync` to match the local `Async`-suffix convention: `ExistsAsync`,
> `FindAsync` and `SaveAsync` all carry it already. This skill would have named it
> `GetCustomer` — the suffix disambiguates a sync/async pair, and no synchronous
> `GetCustomer` exists — but one file holding both conventions is worse than either.
> Converting `Acme.Sales` is a separate change.

**Name the counterfactual — it is the clause that gets dropped.** "Matches the existing
convention" on its own is *not* the note: it leaves the reader unable to tell whether you
knew the rule and yielded to it or never knew it, which is the whole thing the note exists
to settle. Use the names in front of you, not the example's.

## Start here

| Naming this | Read |
|---|---|
| Any identifier — what case? | [Casing](#casing), [Acronyms and abbreviations](#acronyms-and-abbreviations) |
| A class, struct, record, interface | [Types](#types) |
| An ASP.NET Core / EF Core type | [Framework type suffixes](#framework-type-suffixes) |
| A method, property, or boolean | [Members](#members) |
| A lookup that can miss | [The Get / Find / Try contract](#the-get--find--try-contract) |
| An enum, or its zero value | [Enums](#enums) |
| An async method | [Async](#async) |
| An event or delegate | [Events and delegates](#events-and-delegates) |
| A generic type parameter | [Generic type parameters](#generic-type-parameters) |
| A timestamp or time zone field | [Date and time identifiers](#date-and-time-identifiers) |
| A test method, class, or fixture | [dotnet-unit-testing](../dotnet-unit-testing/SKILL.md) — a separate skill |
| Writing .editorconfig rules | [Enforcement](#enforcement) — copy `resources/naming.editorconfig` |
| Reviewing a diff | [Review checklist](#review-checklist) |
| Working in an existing codebase | [Existing conventions win](#existing-conventions-win) |

## Casing

| Identifier | Case | Example |
|---|---|---|
| Namespace, type, method, property, event, public field, constant | PascalCase | `OrderValidator`, `MaxRetryCount` |
| Parameter, local variable | camelCase | `orderId`, `cancellationToken` |
| Private/internal instance field | `_camelCase` | `_repository` |
| Private/internal static field | `s_camelCase` | `s_defaultOptions` |
| Thread-static field | `t_camelCase` | `t_currentScope` |
| Interface | `I` + PascalCase | `IOrderRepository` |
| Generic type parameter | `T`, `T` + descriptor, or `T` + number | `T`, `TKey`, `T1` |

- **Use the `_` / `s_` / `t_` prefixes. Never `this.` to disambiguate a field.** A prefix marks
  a field at every use site; `this.` marks only the one site where a parameter collides. The
  prefixes also survive primary constructors, where a captured parameter has no `this.` form.
- **The prefixes are for fields that hold state — a `const` never takes one.** Constants are
  PascalCase at every accessibility: `private const int MaxRetryCount = 3`. A `static readonly`
  field *is* a field and does take `s_` when private.
- **Never `SCREAMING_CASE`** — a C/Java import that appears nowhere in the BCL.
- Public fields are PascalCase, but the row mostly exists for `const` and interop structs;
  anything holding mutable state should be a property.

## Acronyms and abbreviations

An **acronym** is an initialism — each letter stands for a word (`IO`, `UI`, `XML`, `HTTP`).
An **abbreviation** is a word cut short (`Id`, `Db`, `Utc`). They case differently.

**Classify first, then case.** Expand the letters: `IP` expands to *Internet Protocol*, so it
is an acronym and the two-letter rule reaches it; `Id` expands to nothing — it is "identifier"
cut short. Getting the classification wrong is an error in *both* directions.

| Kind | Rule | Example |
|---|---|---|
| Two-letter acronym | both letters uppercase | `IOStream`, `IPAddress`, `UIElement` |
| Three-letter-plus acronym | PascalCase | `XmlReader`, `HttpClient`, `JsonSerializer` |
| Abbreviation, any length | PascalCase | `Id`, `Db`, `Utc` |
| First word of a camelCase identifier | lowercase, whatever it is | `ioStream`, `uiElement`, `id` |

- **`IPAddress`, not `IpAddress`; `IOStream`, not `IoStream`; `UIElement`, not `UiElement`.**
  A two-letter acronym keeps both letters shouted. BCL precedent: `IPAddress`, `IPEndPoint`,
  `IOException`, `UIElement`. An identifier already in this form is **already correct** —
  leave it exactly as it stands.
- **`Id`, not `ID`** — it abbreviates "identifier," so the two-letter rule doesn't reach it.
  BCL precedent: `ManagedThreadId`, `ProcessId`, `Activity.Id`, `TraceId`.
- **`DbSet`, not `DBSet`** — `Db` shortens "database."
- **`XmlReader`, not `XMLReader`; `HttpClient`, not `HTTPClient`** — three letters or more
  always Pascal-case, however established the uppercase form looks.
- `Id`, `Db`, and `Ok` are *not* two-letter acronyms — none is an initialism. `IO`, `IP`, and
  `UI` are, and cover nearly every one you will meet.
- The camelCase exception is easy to miss: the parameter matching `IOStream` is `ioStream`; a
  property `Id` becomes parameter `id`. `IPAddress` gives `ipAddress` — both letters drop.
- **Don't invent abbreviations:** `GetWindow`, not `GetWin`. Well-known ones already in the BCL
  (`Db`, `Utc`, `Async`, `Min`/`Max`) are fine.

**Re-casing a ported file: classify every name against the table one at a time.** Do not run
the `ID`→`Id` rule over each uppercase run in the file. A file that shouts `ID`, `DB`, and
`XML` usually also holds a correctly shouted two-letter acronym, and a sweep turns that one
right name into a wrong one:

| Legacy name | Correct | Why |
|---|---|---|
| `UserID` | `UserId` | abbreviation — Pascal-case |
| `DBTimeout` | `DbTimeout` | abbreviation — Pascal-case |
| `HTMLTemplate` | `HtmlTemplate` | acronym, three letters — Pascal-case |
| `PrimaryIPAddress` | `PrimaryIPAddress` — **unchanged** | acronym, two letters — already correct |

## Types

| Kind | Convention | Example |
|---|---|---|
| Class, struct, record | **noun phrase** | `OrderValidator`, `CustomerAddress` |
| Interface (capability) | adjective, usually `-able` | `IDisposable`, `IParsable<T>` |
| Interface (role) | noun phrase | `ILogger`, `IHostedService` |
| Exception | `{Problem}Exception` | `OrderNotFoundException` |
| Attribute | `{Purpose}Attribute`, applied as `[Purpose]` | `RequiredAttribute` |
| Event args | `{Event}EventArgs` | `OrderPlacedEventArgs` |
| Builder — staged construction | `{X}Builder` | `StringBuilder`, `WebApplicationBuilder` |
| Factory — repeated creation | `{X}Factory` | `ILoggerFactory`, `IDbContextFactory<T>` |
| Abstract base | name it for what it is; `{X}Base` only as a fallback | `Stream`, `TextWriter` |

- **The `I` prefix goes on every interface, always.** Never `IFooService` when `IFoo` says it.
- **Verbs name methods, not types.** Let the use case supply the verb *inside* a noun phrase:
  `CreateOrderHandler` or `CreateOrderEndpoint`, never a class `CreateOrder` with an `Execute`
  method. Model is the BCL's agent-noun pattern — `StringBuilder`, `XmlSerializer`,
  `TaskScheduler`, `JsonConverter`, `HttpClient`.
- **The entry point's name depends on who calls it.** Two shapes, opposite answers, and the
  test is whether a human writes the call:
  - **Dispatched generically** — a handler, endpoint, consumer, middleware or hosted service
    that a mediator, host or pipeline resolves and invokes. Here the method name is a
    *contract*, uniformity is the entire point, and a generalized name is correct:
    `Handle` / `HandleAsync` (MediatR's `IRequestHandler<T>`, Wolverine, FastEndpoints),
    `ExecuteAsync` (`BackgroundService.ExecuteAsync` is the BCL's own), `Invoke` /
    `InvokeAsync` (ASP.NET Core middleware, where the name is load-bearing — convention-based
    activation looks the method up *by name*), `TryHandleAsync` (`IExceptionHandler`),
    `Consume` (MassTransit). Naming one of these `CreateOrder` either breaks the dispatch or
    makes handlers that should read alike diverge for no gain. The *type* name carries the
    operation and the method name carries the shape — that division is the point of the
    pattern, and it is why the type must not itself be a bare verb.
  - **Called directly** — a type you inject and invoke by name from hand-written code. Here
    the method name is what a reader meets at the call site, so it names the operation:
    `OrderPricer.Price`, `InvoiceRenderer.Render`, `CreateOrderService.Create`.
    `_pricer.Execute(…)` tells that reader nothing the call site had not already said.
- **The don't-repeat-the-type rule (under [Members](#members)) bites on the direct-call shape
  only.** Where the type name already carries the verb, either reading works —
  `OrderCreator.CreateOrder` and `OrderCreator.Create` both read at the call site. What it
  does not license is a generalized name on a type nothing dispatches: there, `Create` is the
  floor and `Execute` is below it. Where the type carries no verb, the method supplies it.
- **Shorten only where the receiver already says what comes back.** `JsonSerializer.Serialize`
  and `XmlSerializer.Serialize` drop the noun because nothing is missing once you have read
  the receiver. A factory *parameterized over its product* does not qualify — what it returns
  lives in a type argument the call site may not have in view — so the BCL keeps the noun:
  `IDbContextFactory<TContext>.CreateDbContext()`, `ILoggerFactory.CreateLogger(…)`. That is a
  considered choice, not an accident of age: EF6's `IDbContextFactory<TContext>` declared
  `Create()`, and EF Core renamed it `CreateDbContext()`. So `OrderFactory.Create()` is fine —
  the receiver names the product — while `IRepositoryFactory<T>.Create()` wants to be
  `CreateRepository()`.
- **A bare verb phrase is correct in exactly two places:**
  - a command/request message — `CreateOrder` as a `record`; `CreateOrderCommand` is clearer;
  - a static grouping type used as a namespace rather than instantiated:

    ```csharp
    public static class CreateOrder
    {
        public sealed record Command(Guid CustomerId, …);
        public sealed class Handler { … }
    }
    ```

- **`{Entity}Service` is the Amusement Connect service-layer shape** — `OrderService`,
  `UserService`, `IWidgetSyncService`, `PricingService`. It is the class that holds the
  business operations a controller or Functions handler calls, behind an interface. Use it.
  Keep each one focused: when an `{Entity}Service` collects operations that share nothing but
  the entity, split it by operation (`OrderService` → `OrderPlacementService`,
  `OrderRefundService`).
- **`Manager` is in use for a type that owns a lifecycle** — `SessionManager` deciding when a
  session expires. Prefer a more specific role name when one fits; don't reject an existing
  `Manager`.
- **`Helper` and `Util` are not names for new types.** Each names the *absence* of a concept —
  a bin for whatever didn't fit elsewhere. Shared-library types that already carry the name,
  such as `RepositoryHelper` in `AmusementConnect.Data.CosmosDb`, are fine to use as they are.
- **`Processor` is legitimate where "process" is the domain's own verb.** It names a real
  shape — take input, transform, produce output — and some domains genuinely process things:
  `PaymentProcessor`, `BatchProcessor`, and Service Bus subscription handlers such as
  `WidgetSyncProcessor`.
- **Otherwise, name the specific role.** Every agent-noun suffix that works says what the type
  actually does: `Builder`, `Factory`, `Converter`, `Serializer`, `Scheduler`, `Client`,
  `Parser`, `Validator`, `Repository`, `Mapper`, `Handler`, `Endpoint`, `Policy`.
- **`{X}Base` only when the unadorned name is taken.** A namespace full of `…Base` types
  usually means inheritance doing a job composition should have.
- **Throw a named exception, never `Exception`.** Use the house exceptions the ProblemDetails
  middleware maps — `NotFoundException`, `ValidationException` — or `ArgumentException` /
  `InvalidOperationException` for programming errors. Add a domain-specific
  `{Problem}Exception` when a caller or the middleware must tell it apart (see
  `dotnet-patterns` and `api-design`).

### Framework type suffixes

Load-bearing in ASP.NET Core and EF Core — tooling, convention-based discovery, and readers
all rely on them.

| Kind | Convention | Example |
|---|---|---|
| EF Core context | `{Purpose}DbContext` | `ApplicationDbContext` |
| EF Core entity and `DbSet` | entity singular, `DbSet<T>` property plural | `class Blog` → `DbSet<Blog> Blogs` |
| EF Core mapping | `{Entity}Configuration`, implementing `IEntityTypeConfiguration<T>` | `BlogConfiguration` |
| EF Core migration | a phrase describing the change, not a timestamp restated | `InitialCreate`, `AddBlogCreatedTimestamp` |
| MVC controller | `{Resource}Controller`, resource singular to match the route (`api-design`) | `UserController` for `/user` |
| Middleware | `{Feature}Middleware` | `ExceptionHandlingMiddleware` |
| Filter | `{Feature}Filter` | `RequestValidationFilter` |
| HTTP request DTO | `{Action}{Resource}Request` | `CreateOrderRequest`, `SearchOrdersRequest` |
| HTTP response DTO | named for what it carries | `OrderResponse`; `SearchOrdersResponse` when the shape is operation-specific |
| Bound configuration | `{Feature}Options`, with a `SectionName` constant | `SmtpOptions` |
| Cosmos document | `{Name}Document` (`cosmos-documents`) | `TabDocument` |
| Message contract | `{Entity}{PastTenseVerb}Message` (`service-bus`) | `WidgetCreatedMessage` |
| Extension container | `{Type}Extensions` | `ServiceCollectionExtensions` |

**The request carries the action; the response usually drops it.** One `OrderResponse` serves
`GET`, `POST`, and `PUT` — three names for one shape drift apart. Keep the action on the
response only when the shape is operation-specific: a `CreateOrderResponse` returning an id and
a `Location`, or a `SearchOrdersResponse` wrapping results in paging metadata.

Placement of `{Feature}Options` and `{Type}Extensions` — which config section binds to which
type, which namespace an extension is declared in — is in the dotnet-solution-structure skill.

## Members

- **Booleans read as assertions:** `Is…`, `Has…`, `Can…`, `Should…`, `Allow…`, `Enable…` —
  `IsEnabled`, `HasValue`, `CanRead`, `AllowTrailingCommas`. Avoid negatives (`IsNotValid`
  inverts badly at call sites).
- **Collections are plural:** `Orders`, `Items`. A singular collection name is a bug magnet.
- **Methods are verb phrases:** `CalculateTotal`, `Submit`. A method named as a noun should
  probably be a property.
- **A static factory method is `Create{X}`:** `WebApplication.CreateBuilder`,
  `Array.CreateInstance`. Prefer it to a public constructor when construction needs a name.
- **Properties are noun phrases**, never `GetX`-style. Cheap and side-effect-free → property;
  expensive or can throw → `GetX()` method. Dates and times are the deliberate exception —
  see [Date and time identifiers](#date-and-time-identifiers).
- **Don't repeat the enclosing type's name in a member:** the type already says it — at the
  call site (`order.Total`, not `order.OrderTotal`) and inside the body alike. This covers
  private fields and constants, not just public members: in `class Cart`, the bound on
  `_lines` is `MaxLines`, not `MaxCartLines`.

### The `Get` / `Find` / `Try` contract

The signature and the name together tell the caller what happens when the thing isn't there.
Under nullable reference types the return type carries most of it, and the name must not
contradict it.

| Return | Name shape | On a miss |
|---|---|---|
| `Order` (non-nullable) | `Get…`, `Single…`, `First…` | throws |
| `Order?` | `Get…`, `Find…`, `…OrDefault` | returns `null` |
| `bool` + `out` | `Try…` | returns `false` |

- **A nullable reference return is a complete signal on its own.** `Task<Order?> GetById(…)`
  is fine — the `?` is enforced by the compiler at every call site, which a naming convention
  is not. Don't stack a redundant `Find` or `…OrDefault` on top of it.
- **The shape to reject is the lie:** a non-nullable `Task<Order>` that returns null anyway.
  That is what trains callers out of null-checking. Fix the type, not just the name.
- **`…OrDefault` still earns its place where `default(T)` isn't null** — value types and
  unconstrained generics. `FirstOrDefault` over `IEnumerable<int>` returns `0`, and no `?`
  says so. Keep it for overload pairs too, where two members coexist and need distinct names:
  `Single` / `SingleOrDefault`, `GetService` / `GetRequiredService`.
- **`Single…` carries a second promise** that has nothing to do with nullability: it throws
  when there is *more than* one match, `SingleOrDefault` included. No return type expresses
  that, so the name always must. Use `Single…` to assert exactly one match exists; `First…`
  when several are legitimate.
- **`Try…` promises not to throw *on the miss*** — not that it never throws. `int.TryParse`
  still raises `ArgumentNullException` for a null argument.
- **Where nullable reference types are not enabled, the name is the only channel** — fall back
  to `Find…` / `…OrDefault` for any lookup that can miss.

## Enums

- **Singular for regular enums, plural for `[Flags]`:** `DayOfWeek`, `LogLevel` —
  but `FileAttributes`, `RegexOptions`.
- **Never suffix the type** with `Enum` or `Flags`.
- **Give each member a camelCase wire name** with `[EnumMember(Value = "firstValue")]` — see
  `csharp-code-style`.
- **Never prefix members with the type name:** `LogLevel.Warning`, not `LogLevel.LogLevelWarning`.
- **Each flag is an explicit power of two.** Declare composites by composing —
  `ReadWrite = Read | Write`, not `ReadWrite = 3` — so the combination survives a renumbering.

### The zero value

`default(TEnum)` is 0 whether or not you name a member for it. All you choose is whether it
means something.

- **`[Flags]`: if there is a zero value it must be `None`, meaning "no flags set."** Leaving
  zero undeclared is equally fine (`FileAccess` starts at `Read = 1`). **Never test it with
  `HasFlag`** — `value.HasFlag(None)` is always `true` because `x & 0 == 0`. Compare with `==`.
- **Simple enums: `None` is usually wrong.** Zero should be the value a zero-initialized
  instance legitimately has. BCL precedent: `DayOfWeek.Sunday`, `LogLevel.Trace`,
  `TaskStatus.Created`, `StringComparison.CurrentCulture`, `MidpointRounding.ToEven`. Adding
  `None` to a domain enum where every entity has a real status invents a representable invalid
  state every use site must then defend against.
- **When zero really is an absence, pick the right word:** `None` (deliberately nothing),
  `Unspecified` (the caller didn't say — as in `DateTimeKind`), `Unknown` (a data-quality
  state), `Default` (defer to the system default).
- **When no honest default exists, starting at 1 is a defensible deviation.** `default(TEnum)`
  becomes detectably invalid and `Enum.IsDefined` catches a value nobody set, at the cost of
  the guarantee that every value of the type is valid. Worth it for a persisted domain enum;
  not for an options enum.

## Async

- **Suffix with `Async` only when a synchronous version of the same method exists.** The suffix
  disambiguates a pair — `Read` / `ReadAsync` — not the return type. With no sync counterpart,
  `Task<Order> GetOrder(…)` is already unambiguous.
- **This is a deliberate deviation from
  [TAP](https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap).**
  Apply it solution-wide and document it — a half-converted codebase is worse than either
  convention.
- **In a codebase that already suffixes every `Task`-returning member, keep suffixing.**
  This is the deviation you collide with most often. Add the one method with the suffix,
  do not rename the others, and note the divergence in your closing message per
  [Existing conventions win](#existing-conventions-win). You never have to invent the
  counterfactual — it is the name you chose with `Async` removed (`LoadShipmentAsync` →
  `LoadShipment`). Suffixing feels like compliance because it is the industry default, so
  no conflict announces itself: the note is due whenever you type the suffix on a member
  that has no synchronous counterpart.
- **Keep the suffix when the name isn't yours to choose:** overrides, interface
  implementations, framework hooks — `SaveChangesAsync`, `ExecuteAsync`, `InvokeAsync`,
  `DisposeAsync`.
- The rule is about the sync/async *pair*, not the return type — `Task`, `ValueTask`, and
  `IAsyncEnumerable<T>` are named the same way.
- **`CancellationToken` is the last parameter**, named `cancellationToken`, defaulted only on
  public API surfaces where callers commonly omit it.
- **Never `.Result` or `.Wait()`.** `await`, or return the task.

Analyzers enforcing the TAP suffix — VSTHRD200 (Microsoft.VisualStudio.Threading.Analyzers),
RCS1046 (Roslynator) — get switched off in `.editorconfig`. Keep RCS1047 on: a *non*-async
method ending in `Async` is still a real mistake.

## Events and delegates

- **Tense says when the event fires.** Present participle before, past tense after: `Closing` /
  `Closed`, `Saving` / `Saved`. A cancellable or vetoable event is always the `-ing` one.
- **The event is a noun; `On{Event}` is the protected method that raises it.** `OnClosing` is
  not an event name. A settable property called `OnClosing` isn't an event either — it's a
  callback, and naming it like an event hides that only one subscriber survives.
- **Prefer `EventHandler<T>` to a custom delegate.** Declare `{Event}EventArgs` and use
  `event EventHandler<OrderPlacedEventArgs>`; write a `{Event}EventHandler` delegate only when
  the signature genuinely can't fit `(object? sender, TArgs e)`.
- **Event args derive from `EventArgs` and end in `EventArgs`.** Use `EventArgs.Empty` rather
  than declaring an empty args type.
- **Handler parameters are `sender` and `e`** — near enough the only place in the BCL where a
  single-letter parameter name is convention rather than lapse.
- **Non-event delegates take a role name:** `{Action}Callback`, or `{X}Selector` /
  `{X}Predicate` / `{X}Comparison` for LINQ-shaped roles. Use `Func<>` / `Action<>` directly
  when a named delegate adds nothing.
- **Never put `Event` in the event's own name** — `Closed`, not `ClosedEvent`.

## Generic type parameters

- Single parameter: `T`.
- Multiple, or where the role isn't obvious: `T` + descriptor — `TKey`, `TValue`, `TResult`,
  `TEntity`, `TContext`, `TState`.
- **Never a bare letter other than `T`**, and never a name without the `T` prefix.
- **`T1`, `T2` … only where parameters are positional and interchangeable** — `Action<T1, T2>`,
  `Tuple<T1, T2>`. The moment a parameter has a role, name the role: `Func<TSource, TResult>`.

## Date and time identifiers

**Two things decide the name, and neither settles it alone: the tense, and whether the type
carries its zone.** `Created` is correct on a `DateTimeOffset` and wrong on a `DateTime`, where
the same moment is `CreatedUtc`. So settle the type first, take the zone suffix from the type
table below, and only then apply the tense rules. Renaming `CreatedAt` to `Created` and leaving
the type a bare `DateTime` applies half of this section and ships the bug the other half exists
to prevent.

Name the moment with a verb; the tense carries whether it has happened.

| The moment | Tense | Example |
|---|---|---|
| Already happened | past | `Created`, `Updated`, `Shipped`, `LastLoggedIn` |
| Yet to happen, or recurring | present / future | `Expires`, `Renews`, `Starts`, `Closes` |

**No `At` or `On` suffix.** `Created`, not `CreatedAt` or `CreatedOn` — the tense already says
it is a moment, and the bare form maps 1:1 to camelCase JSON keys. Dropping `At` is only half
the change: the bare name is correct on a `DateTimeOffset`, and on a `DateTime` it has to
become `CreatedUtc`. Check the type before you stop here.

**No `Time` suffix, no gerund, no bare verb stem** — the same rule from the other side. The
conjugated verb *is* the name; anything else re-states the type or reads as a method.

| Don't | Do | Why |
|---|---|---|
| `OpenTime`, `ClosingTime` | `Opens`, `Closes` | the type already says it is a time |
| `Opening`, `Closing` | `Opens`, `Closes` | a gerund is an *event* name — `Closing` is the cancellable event |
| `Open`, `Close` | `Opens`, `Closes` | a bare stem is an imperative — it reads as `store.Close()` |
| `ShipTime`, `Shipping` | `Shipped` | past tense for a moment that has passed |

**A zone suffix is not one of these suffixes.** `At`, `On`, and `Time` go because they restate
what the type already says. `Utc` and `Local` stay because they say what the type does *not*:
which zone the value is in. So "no suffix" is never the whole answer on its own — the bare name
is correct only on a type that carries the zone, and on a `DateTime` dropping the suffix is the
error rather than the rule. See the table below before you settle either name.

**The tense rule is about the identifier, not the shape it lives in.** It binds every form a
name can take — property, field, parameter, tuple element, positional record parameter, JSON
key, column. Nesting the pair inside a collection does not exempt it:

```csharp
// Per-day hours: the shape is the domain's call, the names are not.
public required IReadOnlyDictionary<DayOfWeek, (TimeOnly Opens, TimeOnly Closes)> Hours { get; init; }
public sealed record StoreHours(DayOfWeek Day, TimeOnly Opens, TimeOnly Closes);
```

**The zone marker follows the type, and one of the two must carry the zone.** Choose the
type first, then take the name this table gives it:

| Type | Convention | Example |
|---|---|---|
| `DateTimeOffset` | no suffix — the offset is in the type | `Created`, `Expires` |
| `DateTime` holding UTC | `Utc` suffix | `CreatedUtc`, `ExpiresUtc` |
| `DateTime` with `Kind == Local` | `Local` suffix | `CreatedLocal` |
| `DateTime` with `Kind == Unspecified` | no good name — **change the type** | — |
| `DateOnly`, `TimeOnly` | no suffix | `Expires`, `Opens` |

This **inverts the BCL**, where the bare name is local and UTC takes the suffix
(`FileSystemInfo.CreationTime` / `CreationTimeUtc`). Here the bare name belongs to
`DateTimeOffset`. `Local` should stay rare — it means local to the machine running the process.

**A wall-clock time in a business time zone is not `Local`.** Naming it `Local` invites the bug
where someone calls `ToUniversalTime()` and converts against the server's zone. Name the zone
instead:

- `Starts` (`DateTimeOffset`) plus `StartsTimeZoneId` (IANA id), when the value must be
  re-rendered in its origin zone.
- `Opens` / `Closes` as `TimeOnly` alongside the entity's `TimeZoneId`, for recurring
  wall-clock times that aren't instants — one pair on the entity, or a pair per day inside a
  collection. Either shape carries the same two names and the one `TimeZoneId`; the zone
  belongs to the entity, not to each day.

**`TimeZoneId` means an IANA id** — `America/Chicago`. A property genuinely holding a Windows
id (`Central Standard Time`) is `WindowsTimeZoneId`, so the mismatch is visible at the point of
use. Resolving, converting, and storing these ids is the dotnet-date-time-handling skill; the
only naming consequence is that `TimeZoneInfo.Id` returns whichever format the host OS uses, so
check `HasIanaId` before storing under either name.

**The name says which property holds the zone; only a doc comment says which format.** Write
the id form at the declaration, with a real id in it — that is what stops the next caller
putting `Central Standard Time` in a property named for IANA:

```csharp
/// <summary>The store's IANA time zone id — for example <c>America/Chicago</c>.</summary>
public required string TimeZoneId { get; init; }
```

**Durations are nouns**, and name their unit only when the type is a number rather than a
`TimeSpan`: `Timeout`, `RetryDelay` (both `TimeSpan`) — but `TimeoutSeconds`,
`CacheDurationMinutes` when the property is an `int` from configuration.

Choosing *which* type — `DateTimeOffset` vs `DateTime` vs `DateOnly`, `TimeProvider`, IANA id
resolution, storage — is the dotnet-date-time-handling skill.

## Enforcement

**Copy the shipped file. Do not re-derive these rules.** A complete, correctly ordered
reference configuration ships in this skill's own `resources/` directory:

| Read this | Write it to | It holds |
|---|---|---|
| `resources/naming.editorconfig` | repository root, as `.editorconfig` | naming styles, all naming rules in the required order, field-prefix settings, analyzer decisions |

Three steps, and none is optional:

1. **Read `resources/naming.editorconfig`.** The ordering and severities in it are already
   correct; a rule set written from the prose below usually is not — the general
   private-field rule ends up above the static-field rule and silently eats it.
2. **Write it to disk** — copied whole into a new `.editorconfig`, or merged
   section-by-section into an existing one, preserving the relative order of the naming
   rules. A configuration quoted in chat leaves the repository unenforced; the deliverable
   is the file.
3. **Say in your answer that you copied it**, and name any section you dropped or changed.
   A reader who cannot tell the reference from a hand-rolled set has to re-audit the ordering.

The rest of this section is what that file encodes — for reviewing an `.editorconfig` you
did not write, or merging into one you cannot replace.

Rules expressible in `.editorconfig` belong there, not in review comments — casing, field
prefixes, `var` usage, file-scoped namespaces, `using` placement.

- Set a `severity` on each rule: `dotnet_naming_rule.<rule_name>.severity = warning`, one line
  per rule — `.editorconfig` has no wildcard there.
- Turn on `EnforceCodeStyleInBuild` so violations surface at build time.
- **Order naming rules most-specific first** — a static-field rule must precede the general
  private-field rule or it will never match.

Field-prefix enforcement:

```ini
dotnet_style_qualification_for_field    = false
dotnet_style_qualification_for_property = false
dotnet_style_qualification_for_method   = false
dotnet_style_qualification_for_event    = false
dotnet_diagnostic.IDE0003.severity      = warning
```

IDE0003 is what those four settings surface as (IDE0009 is the same rule inverted). Leaving it
unset means the preference is expressed and never enforced.

**Analyzer rules needing a decision:**

| Rule | Do |
|---|---|
| SA1101, SA1309, SA1311 (StyleCop) | **Off.** They contradict the `_` / `s_` / `t_` style. Don't use the inverse `SX` rules either — SX1309S conflicts with `s_`. StyleCop can't express the distinction; let `dotnet_naming_rule` own it. |
| CA1707 (no underscores) | Leave **on** here. Test method names need it off in `tests/.editorconfig` only — see [dotnet-unit-testing](../dotnet-unit-testing/SKILL.md). Never disable solution-wide. |
| IDE1006 | The diagnostic `dotnet_naming_rule` entries surface as. If set to `none` anywhere up the chain, **every naming rule below goes quiet while appearing configured.** |
| VSTHRD200, RCS1046 (TAP `Async` suffix) | **Off** — they contradict the Async rule above. |
| RCS1047 (non-async method ending in `Async`) | **On** — still catches a real mistake. |

Rules that can't be expressed — the `Async` suffix policy, noun-phrase type names, the
`Get`/`Find`/`Try` contract, event tense — go in review.

## Review checklist

Reject a change that does any of these:

- [ ] Uses `ID`, `DBSet`, `XMLReader`, or otherwise mis-cases an acronym vs abbreviation.
- [ ] Lowercases a genuine two-letter acronym — `IpAddress`, `IoStream`, `UiElement` — or
      re-cases one that was already correct while migrating a file.
- [ ] Uses `this.` to disambiguate a field instead of a `_` / `s_` / `t_` prefix.
- [ ] Puts a prefix on a `const`, or uses `SCREAMING_CASE`.
- [ ] Repeats the enclosing type's name in a member — `Cart.MaxCartLines`, `order.OrderTotal`
      — including on a private field or `const`.
- [ ] Names an injectable type with a verb phrase (`CreateOrder` with an `Execute` method).
- [ ] Adds a new `Helper` or `Util` type. (`{Entity}Service` is the house service-layer shape;
      `Manager` is acceptable for a lifecycle owner.)
- [ ] Throws `new Exception(...)` instead of a named exception type.
- [ ] Returns null from a non-nullable return type, or names a lookup `Try…` when it
      throws on a miss.
- [ ] Adds `None = 0` to a domain enum where every entity has a real status.
- [ ] Tests a `[Flags]` zero with `HasFlag`.
- [ ] Assigns a literal to a composite flag (`ReadWrite = 3`).
- [ ] Adds an `Async` suffix to a method with no synchronous counterpart — in a codebase that
      does not already suffix every `Task`-returning member — or drops it from an override or
      interface implementation.
- [ ] Puts `CancellationToken` anywhere but last, or calls `.Result` / `.Wait()`.
- [ ] Names an event `On{Event}` or `{Event}Event`, or uses `-ed` tense for a cancellable event.
- [ ] Uses a `CreatedAt` / `CreatedOn` suffix, or a noun like `CreationDate`.
- [ ] Names a moment with a `Time` suffix, a gerund, or a bare verb stem — `OpenTime`,
      `Opening`, `Open` for `Opens` — including inside a tuple or positional record.
- [ ] Names a `DateTime` field without a `Utc` / `Local` suffix, or names a business time zone
      value `Local`.
- [ ] Stores `TimeZoneInfo.Id` without a `HasIanaId` check.
- [ ] Declares a `TimeZoneId` without a doc comment naming the IANA form and a real id.
- [ ] Adds a naming rule to `.editorconfig` without a `severity`, or after a more general rule.
- [ ] Hand-writes an `.editorconfig` naming section when `resources/naming.editorconfig`
      would have been copied, or answers with the configuration instead of writing the file.
- [ ] Answers an implementation task with the name it should have used instead of making
      the edit. A naming critique is the deliverable of a review, not of a change request.
- [ ] Matches a local convention over a rule here without naming the counterfactual — the
      name this skill would have chosen and the rule behind it. "Matches the existing
      convention" alone does not discharge it — and neither does writing that note *instead
      of* making the edit.
- [ ] Spends the entry-point name on `Execute` / `Run` / `Invoke` / `Handle` on a type that
      is injected and called directly rather than dispatched generically. (On a handler,
      endpoint, consumer, middleware or `BackgroundService`, the generalized name is right.)

## Before you end the turn

**If the prompt asked for code — *add*, *write*, *rename*, *create* — the file must be edited
before you answer.** Naming the member, writing its signature in the reply, or explaining what
the right shape would be is not the change. The workspace is what the next person gets, and an
unedited workspace means the task is not done however correct the analysis above it.

Re-read the verb in the prompt. If it was *add*, something must have been written. "No changes
needed" answers a question nobody asked when the prompt named a file and told you to add to it.

The checklist above is for reviewing a diff someone else wrote — that is the one case where the
finding *is* the deliverable. It is not a substitute for work you were asked to do.

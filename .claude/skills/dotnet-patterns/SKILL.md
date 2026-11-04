---
name: dotnet-patterns
description: Idiomatic C# and .NET patterns, conventions, dependency injection, async/await, options binding, and data access as practiced at Amusement Connect.
---

# .NET Development Patterns

Idiomatic C# and .NET patterns for building robust, performant, and maintainable applications, tuned to how Amusement Connect actually builds services. For API-layer conventions (routes, versioning, validation, `ProblemDetails`) see the `api-design` skill; for testing see `csharp-testing`; for messaging see `service-bus`; for caching see `caching`. This skill covers everything underneath the API layer: DI, async, options, data access, and general code shape. See also the `csharp-code-style` and `csharp-logging` skills, which apply to every `.cs` file.

## When to Activate

- Writing new C# code
- Reviewing C# code
- Refactoring existing .NET applications
- Designing service internals (services, repositories, options, background processing)

## Core Principles

### 1. Prefer Immutability

Use records and init-only properties for data models. Mutability should be an explicit, justified choice.

```csharp
// Good: immutable value object
public sealed record Money(decimal Amount, string Currency);

// Good: immutable request DTO with required init properties
public sealed class CreateOrderRequest
{
    public required string CustomerId { get; init; }
    public required IReadOnlyList<OrderItem> Items { get; init; }
}

// Bad: mutable model with public setters
public class Order
{
    public string CustomerId { get; set; }
    public List<OrderItem> Items { get; set; }
}
```

Message and request/response contracts commonly use the `[Equatable]` source generator (`Generator.Equals`) with `required init` properties instead of hand-writing `Equals`/`GetHashCode` — this is the default for anything that needs value equality (message contracts, serialization round-trip tests):

```csharp
[Equatable]
public partial class WidgetCreatedMessage : IMessage
{
    public required Guid WidgetId { get; init; }
    public required string LocationId { get; init; }
}
```

### 2. Explicit Over Implicit

Be clear about nullability, access modifiers, and intent. Follow the `csharp-code-style` skill for naming (PascalCase members, `_camelCase` private fields, no `Async` suffix on async methods unless disambiguating from a sync overload) and formatting (file-scoped namespaces, 4-space indent, one argument per line on chopped calls).

```csharp
public class UserService
{
    private readonly IUserRepository _repository;
    private readonly ILogger<UserService> _logger;

    public UserService(IUserRepository repository, ILogger<UserService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<User?> FindById(Guid id, CancellationToken cancellationToken)
    {
        return await _repository.FindById(id, cancellationToken);
    }
}
```

### 3. Depend on Abstractions

Use interfaces for service and repository boundaries, injected through the constructor. Don't reach for the service provider directly inside a service — that's reserved for factories and similar DI-infrastructure code.

```csharp
public interface IOrderRepository
{
    Task<Order?> FindById(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyList<Order>> FindByCustomer(string customerId, CancellationToken cancellationToken);
    Task Add(Order order, CancellationToken cancellationToken);
}

builder.Services.AddScoped<IOrderRepository, SqlOrderRepository>();
```

### 4. Design for testability

Write small methods that do one thing, keep persistence separate from business logic, and depend on interfaces so dependencies are mockable. If a method's behavior depends on the current time, add a `TimeProvider` property instead of calling `DateTime.UtcNow` directly:

```csharp
public class SessionManager
{
    public TimeProvider Clock { get; init; } = TimeProvider.System;

    public bool IsExpired(Session session) =>
        Clock.GetUtcNow().UtcDateTime > session.ExpiresAtUtc;
}
```

This is what lets `csharp-testing`'s unit tests supply a fixed `TimeProvider` and assert deterministically on time-dependent branches. Only do this when the time genuinely affects the behavior under test — leave an incidental `DateTime.UtcNow` used only for a log timestamp alone.

## Async/Await Patterns

### Proper Async Usage

```csharp
// Good: async all the way, with CancellationToken
public async Task<OrderSummary> GetOrderSummary(Guid orderId, CancellationToken cancellationToken)
{
    var order = await _repository.FindById(orderId, cancellationToken)
        ?? throw new NotFoundException($"Order {orderId} not found");

    var customer = await _customerService.Get(order.CustomerId, cancellationToken);

    return new OrderSummary(order, customer);
}

// Bad: blocking on async — deadlock risk
public OrderSummary GetOrderSummary(Guid orderId)
{
    var order = _repository.FindById(orderId, CancellationToken.None).Result;
    return new OrderSummary(order);
}
```

### Parallel Async Operations

```csharp
public async Task<DashboardData> LoadDashboard(CancellationToken cancellationToken)
{
    var ordersTask = _orderService.GetRecent(cancellationToken);
    var metricsTask = _metricsService.GetCurrent(cancellationToken);
    var alertsTask = _alertService.GetActive(cancellationToken);

    await Task.WhenAll(ordersTask, metricsTask, alertsTask);

    return new DashboardData(
        Orders: await ordersTask,
        Metrics: await metricsTask,
        Alerts: await alertsTask);
}
```

## Options Pattern

Bind configuration sections to a strongly-typed options class with a `SectionName` constant, validated on startup — this is the AC-standard shape, more robust than a bare `services.Configure<T>(...)` call because a bad config fails fast at app start rather than surfacing later as a null/default value:

```csharp
public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    public required string Host { get; init; }

    [Range(1, 65535)]
    public required int Port { get; init; }

    public bool UseSsl { get; init; } = true;
}
```

```csharp
builder.Services
    .AddOptions<SmtpOptions>()
    .BindConfiguration(SmtpOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

Usage via injection — prefer `IOptionsSnapshot<T>` over `IOptions<T>` for anything that should be able to pick up a config change (e.g. from Azure App Configuration) without a redeploy, such as a tunable cache duration or feature flag:

```csharp
public class EmailService(IOptions<SmtpOptions> options)
{
    private readonly SmtpOptions _smtp = options.Value;
}
```

## Result Types

Prefer a specific, named result type per operation over a generic `Result<T>` wrapper — named fields communicate the actual outcome (which failure mode, what data came back) more clearly than a generic `IsSuccess`/`Error` pair, and it's the shape used across AC's own service layer (e.g. a `BeginGameplaySessionResult` carrying whatever fields that specific operation needs on success or failure):

```csharp
public sealed record PlaceOrderResult
{
    public required bool IsSuccess { get; init; }
    public Order? Order { get; init; }
    public string? DeclineReason { get; init; }

    public static PlaceOrderResult Success(Order order) => new() { IsSuccess = true, Order = order };
    public static PlaceOrderResult Declined(string reason) => new() { IsSuccess = false, DeclineReason = reason };
}
```

Reserve throwing for things that are genuinely exceptional (not found, invalid state, infrastructure failure) rather than expected business outcomes like a declined payment — see the `api-design` skill for how those exceptions map to `ProblemDetails` at the API boundary. A generic `Result<T>` is fine for a simple, single-failure-mode case, but don't reach for it as the default — name the result type after the operation.

## Data Access

AC data access is EF Core over SQL Server (no Dapper, no raw ADO.NET) plus the Cosmos SDK directly for Cosmos DB — see the `cosmosdb-best-practices` skill for Cosmos specifics. Repositories wrap the `DbContext`/Cosmos client behind an interface and map to the domain model inside the repository — never return an EF entity or a Cosmos document type from a repository method.

### Read-only vs. transactional `DbContext`

Services commonly register two `DbContext` types bound to different connection strings — a read-only one for queries (backed by a read replica where available) and a transactional one for writes. Inject whichever fits the operation; don't default every repository to the transactional context:

```csharp
public class SqlLocationRepository : ILocationRepository
{
    private readonly ReadOnlyAppDbContext _dbContext; // bound to the "ReadOnlySql" connection string

    public SqlLocationRepository(ReadOnlyAppDbContext dbContext) => _dbContext = dbContext;

    public async Task<Location?> GetLocation(int locationId, CancellationToken cancellationToken)
    {
        var location = await _dbContext.Locations
            .Include(x => x.CreditLevels)
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == locationId, cancellationToken);

        return location is null ? null : MapToDomain(location);
    }

    private static Location MapToDomain(LocationEntity entity) => new()
    {
        Id = entity.Id,
        Name = entity.Description,
        // ...
    };
}
```

Use `AsNoTracking()` on every read-only query — the vast majority of queries, since AC repositories map to a separate domain model rather than mutating and saving the tracked entity directly. Use `Include`/`ThenInclude` for eager loading rather than relying on lazy loading in a loop.

## Guard Clauses

```csharp
public async Task<ProcessResult> ProcessPayment(PaymentRequest request, CancellationToken cancellationToken)
{
    ArgumentNullException.ThrowIfNull(request);

    if (request.Amount <= 0)
        throw new ArgumentOutOfRangeException(nameof(request.Amount), "Amount must be positive");

    if (string.IsNullOrWhiteSpace(request.Currency))
        throw new ArgumentException("Currency is required", nameof(request.Currency));

    var gateway = _gatewayFactory.Create(request.Currency);
    return await gateway.Charge(request, cancellationToken);
}
```

Throw a specific exception type for a specific failure — never `throw new Exception("...")`. A generic `Exception` gives callers (and the `ProblemDetails` middleware from `api-design`) nothing to distinguish on; use or define a named exception (`NotFoundException`, `ValidationException`, a domain-specific one) instead.

## Endpoints, Messaging, and Caching

Controllers are the default API style at AC (FluentValidation for request validation, `ProblemDetails` error responses, `Asp.Versioning` for API versions, `[RequireScope("...")]` for authorization) — see the `api-design` skill for the full convention, including when Minimal APIs are used instead.

For publishing/subscribing to Azure Service Bus messages, see the `service-bus` skill (`IMessagePublisher`, `AddServiceBus`, `[ServiceBusTrigger]` handlers). For caching, see the `caching` skill (`HybridCache` via `AddAmusementConnectCaching`).

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| `async void` methods | Return `Task` (except event handlers) |
| `.Result` or `.Wait()` | Use `await` |
| `catch (Exception) { }` | Handle or rethrow with context |
| `throw new Exception("...")` | Throw a specific/named exception type |
| `new Service()` in constructors | Use constructor injection |
| `public` fields | Use properties with appropriate accessors |
| `dynamic` in business logic | Use generics or explicit types |
| Mutable `static` state | Use DI scoping or `ConcurrentDictionary` |
| `string.Format` in loops | Use `StringBuilder` or interpolated string handlers |
| `DateTime.UtcNow` in behavior under test | Inject a `TimeProvider Clock` property |
| Returning an EF entity/Cosmos document from a repository | Map to the domain model inside the repository |

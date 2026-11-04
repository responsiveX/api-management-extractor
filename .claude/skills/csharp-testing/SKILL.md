---
name: csharp-testing
description: |
  Amusement Connect C# and .NET testing patterns — MSTest, Moq, Shouldly, integration tests, and test organization. Use when writing new features, adding additional test coverage, reviewing test quality, setting up test infrastructure for a .NET project, or debugging flaky/slow tests.
---

# C# Testing Patterns

Testing conventions for Amusement Connect .NET services, built on **MSTest**, **Moq**, and **Shouldly**. This is the house stack — do not introduce xUnit, NUnit, FluentAssertions, or NSubstitute into an AC test project even if they're more common industry-wide. See the `dotnet-unit-tester` agent for a fuller worked-through workflow when writing tests end-to-end; this skill is the reference for the conventions themselves.

## When to Activate

- Writing new tests for C# code
- Reviewing test quality and coverage
- Setting up test infrastructure for a .NET project
- Debugging flaky or slow tests

## Test Framework Stack

| Tool | Purpose |
|---|---|
| **MSTest** | Test framework — `[TestClass]`, `[TestMethod]`, `[DataRow]` |
| **Shouldly** | Assertions — `result.ShouldBe(expected)`. Never use MSTest's `Assert.*` in new tests. |
| **Moq** | Mocking dependencies — `new Mock<IDependency>()` |
| **Testcontainers** | Real infrastructure in integration tests (e.g. `Testcontainers.MsSql`, `Testcontainers.ServiceBus`) |
| **WebApplicationFactory** | ASP.NET Core integration tests |

## Project & File Conventions

- Test projects follow the naming template `AmusementConnect.{ServiceName}.Testing.(Unit|Integration).MsTest`. Unit tests go in the `Unit` project, integration tests in the `Integration` project.
- One test class per file, named `{SubjectClass}Tests.cs`.
- Mirror the folder structure of the project under test inside the test project — a subject at `Services/Pricing/PricingService.cs` gets its tests at `Services/Pricing/PricingServiceTests.cs` in the test project.

## Unit Test Structure

### Arrange-Act-Assert with Shouldly

Every test follows Arrange-Act-Assert with the three sections marked by comments. Name tests `MethodOrPropertyName_StateOrConditionUnderTest_ExpectedOutcome`:

```csharp
[TestClass]
public class OrderServiceTests
{
    [TestMethod]
    public async Task PlaceOrder_WhenRequestIsValid_ReturnsSuccess()
    {
        // Arrange
        var mockRepository = new Mock<IOrderRepository>();
        var subject = new OrderService(mockRepository.Object, NullLogger<OrderService>.Instance);
        var request = new CreateOrderRequest
        {
            CustomerId = "cust-123",
            Items = [new OrderItem("SKU-001", 2, 29.99m)]
        };

        // Act
        var result = await subject.PlaceOrder(request, CancellationToken.None);

        // Assert
        result.CustomerId.ShouldBe("cust-123");
    }

    [TestMethod]
    public async Task PlaceOrder_WhenNoItems_ThrowsValidationException()
    {
        // Arrange
        var subject = new OrderService(Mock.Of<IOrderRepository>(), NullLogger<OrderService>.Instance);
        var request = new CreateOrderRequest { CustomerId = "cust-123", Items = [] };

        // Act
        var act = () => subject.PlaceOrder(request, CancellationToken.None);

        // Assert
        await act.ShouldThrowAsync<ValidationException>();
    }
}
```

### Parameterized tests with `[DataRow]`

MSTest's equivalent of xUnit's `[Theory]`/`[InlineData]` is `[DataTestMethod]` + `[DataRow]`:

```csharp
[DataTestMethod]
[DataRow("", false)]
[DataRow("a", false)]
[DataRow("ab@c.d", false)]
[DataRow("user@example.com", true)]
[DataRow("user+tag@example.co.uk", true)]
public void IsValidEmail_ReturnsExpected(string email, bool expected)
{
    EmailValidator.IsValid(email).ShouldBe(expected);
}
```

For cases too complex for `[DataRow]` (e.g. non-primitive arguments), use `[DynamicData]` pointing at a static property or method that yields `object[]`:

```csharp
[DataTestMethod]
[DynamicData(nameof(InvalidOrderCases))]
public async Task PlaceOrder_RejectsInvalidOrders(CreateOrderRequest request, string expectedError)
{
    var subject = new OrderService(Mock.Of<IOrderRepository>(), NullLogger<OrderService>.Instance);

    var act = () => subject.PlaceOrder(request, CancellationToken.None);

    var ex = await act.ShouldThrowAsync<ValidationException>();
    ex.Message.ShouldContain(expectedError);
}

public static IEnumerable<object[]> InvalidOrderCases()
{
    yield return [new CreateOrderRequest { CustomerId = "", Items = [ValidItem()] }, "CustomerId"];
    yield return [new CreateOrderRequest { CustomerId = "c1", Items = [] }, "at least one item"];
}
```

## Mocking with Moq

Construct the subject under test in Arrange using `new Mock<IDependency>()`, `.Setup(...)`, `.Returns(...)`, and pass `mock.Object` to the constructor. Only mock and configure the dependencies the behavior under test actually exercises:

```csharp
[TestMethod]
public async Task GetOrder_WhenNotFound_ReturnsNull()
{
    // Arrange
    var orderId = Guid.NewGuid();
    var mockRepository = new Mock<IOrderRepository>();
    mockRepository
        .Setup(r => r.FindById(orderId, It.IsAny<CancellationToken>()))
        .ReturnsAsync((Order?)null);
    var subject = new OrderService(mockRepository.Object, NullLogger<OrderService>.Instance);

    // Act
    var result = await subject.GetOrder(orderId, CancellationToken.None);

    // Assert
    result.ShouldBeNull();
}

[TestMethod]
public async Task PlaceOrder_PersistsOrder()
{
    // Arrange
    var mockRepository = new Mock<IOrderRepository>();
    var subject = new OrderService(mockRepository.Object, NullLogger<OrderService>.Instance);
    var request = ValidOrderRequest();

    // Act
    await subject.PlaceOrder(request, CancellationToken.None);

    // Assert
    mockRepository.Verify(
        r => r.Add(It.Is<Order>(o => o.CustomerId == request.CustomerId), It.IsAny<CancellationToken>()),
        Times.Once);
}
```

If a dependency is genuinely unused on the code path under test, it's fine to pass `null` even with nullable reference types enabled — suppress the warning with the null-forgiving operator rather than constructing a mock you'll never configure:

```csharp
var subject = new OrderService(null!, NullLogger<OrderService>.Instance);
```

## Logging

- Never assert on log messages or their absence.
- Always supply `NullLogger<T>.Instance` (or `NullLogger.Instance`) when constructing the subject. Don't mock `ILogger<T>`.

## Time-Dependent Behavior

If a method's behavior depends on the current time, don't call `DateTime.UtcNow` directly in a way that makes the test non-deterministic. Add a `TimeProvider` property to the subject class and use it instead:

```csharp
public class SessionManager
{
    public TimeProvider Clock { get; init; } = TimeProvider.System;

    public bool IsExpired(Session session) =>
        Clock.GetUtcNow().UtcDateTime > session.ExpiresAtUtc;
}
```

```csharp
[TestMethod]
public void IsExpired_WhenPastExpiry_ReturnsTrue()
{
    // Arrange
    var fixedTime = new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);
    var subject = new SessionManager { Clock = new FakeTimeProvider(fixedTime) };
    var session = new Session { ExpiresAtUtc = fixedTime.UtcDateTime.AddMinutes(-1) };

    // Act
    var result = subject.IsExpired(session);

    // Assert
    result.ShouldBeTrue();
}
```

Only introduce the `Clock` property when time genuinely affects the behavior under test — leave incidental `DateTime.UtcNow` calls (e.g. only used for a log timestamp) alone.

## Testing message publishers and cache usage

These come up often enough in AC services to call out directly (see the `service-bus` and `caching` skills for the full conventions):

- **`IMessagePublisher`** — mock it with Moq and verify the right message type/fields were published, or use a hand-rolled recording fake when a test needs to inspect the full published message rather than just assert a call happened:

  ```csharp
  var mockPublisher = new Mock<IMessagePublisher>();
  mockPublisher
      .Setup(p => p.Publish(It.IsAny<WidgetCreatedMessage>()))
      .Returns(Task.CompletedTask);

  await subject.CreateWidget(widget);

  mockPublisher.Verify(p => p.Publish(It.Is<WidgetCreatedMessage>(m => m.WidgetId == widget.Id)), Times.Once);
  ```

- **`HybridCache`** — it's a concrete class with many members, so mocking it with Moq is impractical. Write a small in-memory fixture that subclasses `HybridCache` and backs `GetOrCreateAsync`/`SetAsync`/`RemoveAsync`/`RemoveByTagAsync` with a `ConcurrentDictionary` (no real expiration needed for most tests) — see the `caching` skill for a full example.

## ASP.NET Core Integration Tests

### `WebApplicationFactory` with MSTest

MSTest doesn't have xUnit's `IClassFixture<T>` — share a factory/client across tests in a class with `[ClassInitialize]`/`[ClassCleanup]` (both must be `static`):

```csharp
[TestClass]
public class OrderApiTests
{
    private static WebApplicationFactory<Program> _factory = null!;
    private static HttpClient _client = null!;

    [ClassInitialize]
    public static void ClassInitialize(TestContext context)
    {
        _factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(options => options.UseInMemoryDatabase("TestDb"));
            });
        });
        _client = _factory.CreateClient();
    }

    [ClassCleanup]
    public static void ClassCleanup() => _factory.Dispose();

    [TestMethod]
    public async Task GetOrder_WhenNotFound_Returns404()
    {
        var response = await _client.GetAsync($"/order/{Guid.NewGuid()}");

        response.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [TestMethod]
    public async Task CreateOrder_WithValidRequest_Returns201()
    {
        var request = new CreateOrderRequest { CustomerId = "cust-1", Items = [new("SKU-001", 1, 19.99m)] };

        var response = await _client.PostAsJsonAsync("/order", request);

        response.StatusCode.ShouldBe(HttpStatusCode.Created);
        response.Headers.Location.ShouldNotBeNull();
    }
}
```

### Testing with Testcontainers

Use MSTest's `[TestInitialize]`/`[TestCleanup]` (instance-level, async-capable via `Task`-returning methods) rather than xUnit's `IAsyncLifetime`:

```csharp
[TestClass]
public class SqlLocationRepositoryTests
{
    private MsSqlContainer _sql = null!;
    private AppDbContext _db = null!;

    [TestInitialize]
    public async Task TestInitialize()
    {
        _sql = new MsSqlBuilder().Build();
        await _sql.StartAsync();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(_sql.GetConnectionString())
            .Options;
        _db = new AppDbContext(options);
        await _db.Database.MigrateAsync();
    }

    [TestCleanup]
    public async Task TestCleanup()
    {
        await _db.DisposeAsync();
        await _sql.DisposeAsync();
    }

    [TestMethod]
    public async Task GetLocation_ReturnsPersistedLocation()
    {
        var repository = new SqlLocationRepository(_db, Options.Create(new PayrocApiOptions()));

        var location = await repository.GetLocation(new LocationIdentity(1), CancellationToken.None);

        location.ShouldNotBeNull();
    }
}
```

The shared `AmusementConnect.Messaging.ServiceBus` library's own integration tests follow the same shape against `Testcontainers.ServiceBus` and the Service Bus emulator — that's a good reference if you're integration-testing a Service Bus publisher end-to-end rather than mocking `IMessagePublisher`.

## Test Organization

```
test/
  AmusementConnect.{Service}.Testing.Unit.MsTest/
    Services/
      OrderServiceTests.cs
      PaymentServiceTests.cs
    Validators/
      CreateOrderRequestValidatorTests.cs
  AmusementConnect.{Service}.Testing.Integration.MsTest/
    Api/
      OrderApiTests.cs
    Repositories/
      SqlOrderRepositoryTests.cs
```

## Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| `Assert.AreEqual`/`Assert.IsTrue` in new tests | Use Shouldly (`.ShouldBe(...)`, `.ShouldBeTrue()`) |
| `[Fact]`/`[Theory]`/`Substitute.For<T>()` | This is an MSTest + Moq codebase — `[TestMethod]`/`[DataTestMethod]` and `Mock<T>` |
| Testing implementation details | Test behavior and outcomes |
| Shared mutable state across tests | Fresh instance per test — construct the subject in each `[TestMethod]` (or `[TestInitialize]`) |
| `Thread.Sleep` in async tests | Use `Task.Delay` with a timeout, or a polling helper |
| Mocking `ILogger<T>` | Use `NullLogger<T>.Instance` |
| Uncontrolled `DateTime.UtcNow` in the subject | Inject a `TimeProvider Clock` property |
| Test names describing implementation | Name by behavior: `Method_Condition_ExpectedOutcome` |
| Ignoring `CancellationToken` | Always pass and, where it matters, verify cancellation |

## Running Tests

```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run a specific project
dotnet test test/AmusementConnect.WalletService.Testing.Unit.MsTest/

# Filter by test name
dotnet test --filter "FullyQualifiedName~OrderService"
```

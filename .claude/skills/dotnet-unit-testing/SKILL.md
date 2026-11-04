---
name: dotnet-unit-testing
description: 'Use whenever you write, add, rename, or review a C# test, or set up a test project — and do not skip it because the test is one method or the name looks obvious. "Write a test for X" is always a task for this skill. Targets MSTest on Microsoft.Testing.Platform (MTP) with the Amusement Connect house stack — MSTest, Moq, Shouldly: test method names (MethodOrPropertyName_StateOrConditionUnderTest_ExpectedOutcome), [TestClass]/[TestMethod] layout, Shouldly assertions and Should.Throw / ShouldThrowAsync (ExpectedException and Assert.ThrowsException were REMOVED in MSTest 4), [DataRow] and [DynamicData] rather than xUnit [Theory]/[InlineData], lifecycle attributes, MSTestAnalysisMode and the MSTEST0 analyzers, and the CA1707 override a test tree needs. Test projects are AmusementConnect.{Service}.Testing.(Unit|Integration).MsTest under test/. Names of the production types under test come from dotnet-naming-conventions. Ships a reference csproj and test/.editorconfig.'
---

# .NET Unit Testing — MSTest on Microsoft.Testing.Platform

Targets **MSTest 4 running on [Microsoft.Testing.Platform (MTP)](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-intro)**,
MTP is the runner `MSTest.Sdk` enables by default; VSTest is legacy and its bridge is removed
in MTP v2 under the .NET 10 SDK. 
with the Amusement Connect house stack: **MSTest** for structure, **Shouldly** for assertions,
**Moq** for test doubles. Do not write xUnit or NUnit here — `[Fact]`, `[Theory]`, and
`[InlineData]` are the wrong vocabulary — and do not introduce FluentAssertions or NSubstitute.

This skill governs the *test* code. The production types a test exercises are named by
[dotnet-naming-conventions](../dotnet-naming-conventions/SKILL.md), and the project a test
lives in by [dotnet-solution-structure](../dotnet-solution-structure/SKILL.md) — loading this
skill does not load those.

The reasoning behind every rule here is in `ARTICLE.md`, in this directory. This file is the
decision surface; read the article when a rule needs justifying to a human.

**Precedence:** where this skill and an Amusement Connect skill (`csharp-testing`, `csharp-code-style`, `csharp-logging`, `dotnet-patterns`, `api-design`, `caching`, `cosmos-documents`, `etags`, `service-bus`) disagree, the Amusement Connect skill wins.

**The deliverable is the edited file.** "Write a test for X" asks for the test, written into
the file — apply the name and shape this skill gives you and make the edit. A reply that
describes the test without writing it leaves the task undone. Reviewing a diff is the one case
where the finding *is* the deliverable.

## Existing conventions win

**These conventions govern new tests and new test projects.** Where a test project is already
internally consistent with a different choice — a different name shape, an assertion
library — match what is there. Do not convert it in passing, and do not rename the tests
around the one you were asked to add.

**Edit first, then say so.** Write the test with the matched shape, and *then* close the turn
with a note naming what you chose, the local convention it matches, and what this skill would
have chosen. "Matches the existing convention" on its own is not the note: it leaves the reader
unable to tell whether you knew the rule and yielded to it or never knew it.

**This covers style, not removed APIs.** `[ExpectedException]` and `Assert.ThrowsException`
were removed in MSTest 4 — surrounding code still using them either predates the upgrade or
does not compile. Matching them is not an option, so write the new test with
`Should.Throw<T>` / `ShouldThrowAsync<T>` and say why the file now holds two shapes.
Converting the rest is a separate change.

## Start here

| Doing this | Read |
|---|---|
| Naming a test method | [Test method names](#test-method-names) |
| Naming a test class or fixture | [Test classes](#test-classes) |
| Laying out a test body | [Arrange-Act-Assert](#arrange-act-assert) |
| Asserting a throw, or anything else | [Assertions](#assertions) |
| Faking a dependency | [Test doubles](#test-doubles) |
| Running the same test over several inputs | [Data-driven tests](#data-driven-tests) |
| Setup / teardown | [Lifecycle](#lifecycle) |
| Creating or configuring a test project | [Project setup](#project-setup) |
| Reviewing a test diff | [Review checklist](#review-checklist) |

## Test method names

`MethodOrPropertyName_StateOrConditionUnderTest_ExpectedOutcome` — three underscore-separated
segments.

| Segment | Holds |
|---|---|
| `MethodOrPropertyName` | the member under test, named as the code names it |
| `StateOrConditionUnderTest` | the condition that produces the outcome, usually `When…` |
| `ExpectedOutcome` | the observable outcome, in present tense |

```csharp
PlaceOrder_WhenRequestIsValid_ReturnsSuccess
PlaceOrder_WhenNoItems_ThrowsValidationException
GetOrder_WhenNotFound_ReturnsNull
IsExpired_WhenPastExpiry_ReturnsTrue
```

- **The first segment is the member's real name**, so a grep for the method finds its tests.
  Members without a name of their own get a stand-in: `Constructor`, `Indexer`.
- **Carry across the name the member actually has.** Under the `Async` rule in
  [dotnet-naming-conventions](../dotnet-naming-conventions/SKILL.md) a method with no
  synchronous counterpart carries no suffix, so there is usually none to carry: `GetOrder_`,
  never `GetOrderAsync_`. Where the code under test *does* suffix, the first segment matches
  the code, suffix and all.
- **Name by behavior, not implementation.** State the outcome a caller can see —
  `ReturnsNull`, not `HitsTheFallbackBranch`. If naming the expectation is hard, the test is
  probably asserting on internals.
- **Drop the condition segment only when the behavior is unconditional** —
  `Constructor_ThrowsArgumentNullException`.
- **No `Test` prefix or suffix**, and don't repeat the type — the class already says it.
- **Don't set `DisplayName` to the method's own name** — MSTEST0071 flags it. Leave
  `DisplayName` off unless it says something the name cannot.

## Test classes

```csharp
[TestClass]
public class OrderServiceTests
{
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

- Test classes are `{SubjectClass}Tests`, one per file, in a folder that mirrors the subject's
  path in the project under test — `Services/Pricing/PricingService.cs` is tested in
  `Services/Pricing/PricingServiceTests.cs`. Fixtures are `{Scope}Fixture`.
- **`[TestClass]` is required, and the class must be `public`, non-static, and non-generic**
  (MSTEST0002). `sealed` is fine but not required.
- **Apply `[TestClass]` directly, never by inheritance** — an inherited attribute is skipped by
  source-generated discovery (MSTEST0069).
- **The constructor must be `public` and either parameterless or take a single `TestContext`**
  (MSTEST0063). Nothing else is a valid test class constructor.
- **Only test methods are `public`** (MSTEST0029); helper classes and members are `internal` or
  `private` (MSTEST0004).
- Every `[TestMethod]` must sit in a `[TestClass]` (MSTEST0030).

## Arrange-Act-Assert

Every test marks its three sections with `// Arrange`, `// Act`, `// Assert` comments.
Construct the subject under test in Arrange, in each test — not in shared mutable state.

## Assertions

- **Use Shouldly, never MSTest's `Assert.*`, in new tests:** `result.ShouldBe(expected)`,
  `flag.ShouldBeTrue()`, `value.ShouldBeNull()`, `items.ShouldContain(x)`. Shouldly's failure
  message names the expression and both values.
- **Assert a throw with Shouldly:** `Should.Throw<T>(() => subject.Submit())` for synchronous
  code, `await act.ShouldThrowAsync<T>()` (or `await Should.ThrowAsync<T>(...)`) for async.
  Both return the exception, so assert on it directly rather than catching.
- **`[ExpectedException]` and `Assert.ThrowsException` were REMOVED in MSTest 4.** They are not
  a style choice — code using them does not compile. `[ExpectedException]` also could not say
  *which* call was supposed to throw, which is why it went.
- **Never assert on log messages or their absence.**
- One behavior per test. If a test needs several unrelated assertions, it is several tests.

## Test doubles

See `csharp-testing` for the full Moq conventions.

- **Moq** for dependencies: `new Mock<IDependency>()`, `.Setup(...)`, `.ReturnsAsync(...)`, pass
  `mock.Object`, and `Verify(..., Times.Once)` for interactions that matter. Mock and configure
  only the dependencies the behavior under test exercises; `Mock.Of<T>()` for the rest.
- **`NullLogger<T>.Instance`** for loggers. Never mock `ILogger<T>`.
- **`FakeTimeProvider`** for time-dependent behavior — see `dotnet-date-time-handling`.
- **`HybridCache`** and **`IMessagePublisher`** have house fakes — see `caching` and
  `service-bus`.

## Data-driven tests

MSTest has no `[Theory]`. A parameterized test is a `[TestMethod]` carrying a data attribute.

| Attribute | For |
|---|---|
| `[DataRow]` | inline, constant cases |
| `[DynamicData]` | computed or complex cases, from a method or property |

```csharp
[TestMethod]
[DataRow("", false)]
[DataRow("a", false)]
[DataRow("user@example.com", true)]
public void IsValid_ForEmailAddress_ReturnsExpected(string email, bool expected)
{
    EmailValidator.IsValid(email).ShouldBe(expected);
}
```

- **Name the dimension, not the cases.** The method name describes what varies; the individual
  inputs live in `[DataRow]`, with `DisplayName` where the case needs a label.
- **`[TestMethod]`, not `[DataTestMethod]`** — the latter is redundant (MSTEST0044) and is
  obsolete in MSTest 4. Some `csharp-testing` examples still show `[DataTestMethod]`; write
  `[TestMethod]` in new tests.
- `[DataRow]` argument count and types must match the signature exactly (MSTEST0014); duplicate
  rows are flagged by MSTEST0042.
- `[DynamicData]` auto-detects property vs method since MSTest 3.8 — don't specify
  `DynamicDataSourceType`. Return `IEnumerable<object[]>`, or `IEnumerable<TestDataRow<T>>`
  when cases need display names, categories, or individual ignore messages.

## Lifecycle

- **House style is `[TestInitialize]` / `[TestCleanup]`**, which can be `async` — Testcontainers
  and other async setup need that. Enable MSTEST0019 (prefer `TestInitialize`) and MSTEST0022
  (prefer `TestCleanup`); leave MSTEST0020 and MSTEST0021 off. The shipped
  `resources/tests.editorconfig` does this.
- Share an expensive fixture across a class — a `WebApplicationFactory`, say — with `static`
  `[ClassInitialize]` / `[ClassCleanup]`. MSTest has no `IClassFixture<T>` or `IAsyncLifetime`.
- Scope widens `[TestInitialize]` → `[ClassInitialize]` → `[AssemblyInitialize]`. Prefer the
  narrowest that works; shared state across tests is what makes a suite order-dependent.
- Take a `CancellationToken` for cooperative timeouts rather than relying on the timeout to kill
  the test (MSTEST0045).

## Project setup

Test projects live under `test/` and are named
`AmusementConnect.{Service}.Testing.(Unit|Integration).MsTest` — unit tests in the `Unit`
project, integration tests (Testcontainers, `WebApplicationFactory`, the Cosmos emulator) in
the `Integration` project. A data project gets its own, e.g.
`AmusementConnect.{Service}.Data.Cosmos.Testing.Unit.MsTest`.

Use `MSTest.Sdk` — it enables MTP, pulls in the framework and analyzers, and keeps the platform
and its extensions on aligned versions. Add Moq and Shouldly as package references:

```xml
<Project Sdk="MSTest.Sdk/4.1.0">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <MSTestAnalysisMode>Recommended</MSTestAnalysisMode>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="../../src/AmusementConnect.WidgetService/AmusementConnect.WidgetService.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Moq" />
    <PackageReference Include="Shouldly" />
  </ItemGroup>

</Project>
```

Pin the current `MSTest.Sdk` version rather than copying the one above. Reference form is in
`resources/MSTest.Tests.csproj`.

- **Do not add `Microsoft.NET.Test.Sdk`.** It is the VSTest host; `MSTest.Sdk` on MTP does not
  use it, and carrying both is a source of confusing runner behaviour.
- **Where `MSTest.Sdk` cannot be the SDK** — a project needing `Microsoft.NET.Sdk.Web`, for
  instance — configure MTP by hand: `<EnableMSTestRunner>true</EnableMSTestRunner>` and
  `<OutputType>Exe</OutputType>`, with MSTest 3.2 or later.
- **Set `EnableMSTestRunner` and `TestingPlatformDotnetTestSupport` in `Directory.Build.props`**,
  not per project, so a new test project cannot silently land on VSTest. A solution split across
  both runners is unsupported.
- **Code coverage on MTP is `--coverage --coverage-output-format cobertura`**, not
  `--collect "XPlat Code Coverage"` — that is a VSTest data collector. The AC
  `ac-pipeline-standards` coverage step still uses `--collect`; when a test project moves to
  MTP, point that out rather than changing the pipeline silently.
- A test *helper* library with no runnable tests sets `<IsTestApplication>false</IsTestApplication>`.
- MSTest 4 requires .NET 8 or later (.NET Framework 4.6.2 remains the floor there).

## Enforcement

Copy `resources/tests.editorconfig` into `test/` as `.editorconfig`.

| Rule | Setting |
|---|---|
| `MSTestAnalysisMode` | **`Recommended`.** Escalates the info-level MSTEST rules to warnings, and MSTEST0003 (valid test method) to an error. `All` is stricter; `Default` leaves real problems at info. |
| CA1707 (no underscores) | **Off in `test/.editorconfig` only.** Fires on every test method named per this skill. Off by default; bites once `<AnalysisLevel>` is `latest-recommended` or `<AnalysisMode>` is `All`. Never disable it solution-wide — it still catches underscores in production identifiers. |
| MSTEST0019 / MSTEST0022 | **On** — `[TestInitialize]` / `[TestCleanup]` is the house style. |
| MSTEST0020 / MSTEST0021 | **Off** — they demand the opposite style. |

## Review checklist

- [ ] Uses `[Fact]`, `[Theory]`, or `[InlineData]` — xUnit vocabulary in an MSTest project.
- [ ] Uses MSTest `Assert.*`, FluentAssertions, or NSubstitute instead of Shouldly and Moq.
- [ ] Names a test outside `MethodOrPropertyName_StateOrConditionUnderTest_ExpectedOutcome`,
      or names it for implementation rather than behavior.
- [ ] Uses a run-on name (`SubmitThrowsWhenEmpty`) or an underscore between every word
      (`Submit_When_Cart_Is_Empty_Throws`) instead of the three segments.
- [ ] First segment does not match the member under test, suffix and all.
- [ ] Carries a `Test` prefix/suffix, or repeats the type the class already names.
- [ ] Omits the `// Arrange`, `// Act`, `// Assert` markers.
- [ ] Uses `[ExpectedException]` or `Assert.ThrowsException` — removed in MSTest 4.
- [ ] Asserts a throw by catching rather than `Should.Throw<T>` / `ShouldThrowAsync<T>`.
- [ ] Mocks `ILogger<T>` or asserts on log output.
- [ ] Test class is not `public`, is static or generic, or gets `[TestClass]` by inheritance.
- [ ] A `public` non-test method on a test class, or a `public` helper type.
- [ ] Adds `Microsoft.NET.Test.Sdk` to an MTP project.
- [ ] Disables CA1707 outside the test tree.

## Before you end the turn

**If the prompt asked for code — *add*, *write*, *rename*, *create* — the file must be edited
before you answer.** Naming the member, writing its signature in the reply, or explaining what
the right shape would be is not the change. The workspace is what the next person gets, and an
unedited workspace means the task is not done however correct the analysis above it.

Re-read the verb in the prompt. If it was *add*, something must have been written. "No changes
needed" answers a question nobody asked when the prompt named a file and told you to add to it.

The checklist above is for reviewing a diff someone else wrote — that is the one case where the
finding *is* the deliverable. It is not a substitute for work you were asked to do.

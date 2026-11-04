---
name: csharp-code-style
description: |
  Amusement Connect C# style guide and coding conventions — naming, formatting, comments, enums, and designing for DI/testability. Use whenever writing, editing, or reviewing any .cs file.
  Triggers on phrases like "fix the formatting", "follow our style guide", "naming conventions", "how should this be formatted", "review this C# file for style", and similar. Also trigger automatically when opening or editing any .cs file.
---

# C# Style Guide & Conventions

The policy at Amusement Connect is to follow the official Microsoft C# coding conventions, unless otherwise specified in this document. The goal is a consistent codebase that's easy to read and understand for all developers.

## Comments

Use standard XML documentation comments to document classes, interfaces, enums, methods, properties, etc.

Overly verbose comments are discouraged. The code should be self-documenting as much as possible. Comments should explain why something is done, not what is done.

## Formatting

Ternary expressions should be formatted with the expression on the first line, then the `? <true value>` and `: <false value>` on the following lines, indented one level.

```csharp
var result = someCondition
    ? SomeMethod(arg1, arg2, arg3)
    : SomeOtherMethod(arg4, arg5);
```

When using LINQ method syntax with multiple chained methods, format each method call on a new line for better readability.

Use file scoped namespaces.

Use 4 spaces for indentation.

Chop long methods and method calls to one argument per line.

```csharp
public void ExampleMethod<T1,T2>(
    int arg1,
    string arg2,
    bool arg3,
    [ArgWithAnAttribute(AndAConstructorArugument = "value")] Dictionary<string, object?> arg4
)
    where T1 : new(), IMyInterface
    where T2 : class, IMyOtherInterface
{
    if(arg3 && !string.IsNullOrEmpty(arg2))
    {
        AnotherExampleMethod(
            arg1,
            arg2,
            arg4["playload"] is MyType payload
                ? payload
                : new MyType()
        );
    }
}
```

## Enums

Use PascalCase for enum names. Decorate enum members with the `[EnumMember(Value = "value")]` attribute to specify the string value that should be used when representing the enum as a string. The string value should be in camelCase.

```csharp
public enum MyEnum
{
    [EnumMember(Value = "firstValue")]
    FirstValue,

    [EnumMember(Value = "secondValue")]
    SecondValue
}
```

## Naming Conventions

Use PascalCase for classes, methods, interfaces, enums, and properties. Use camelCase for local variables and method parameters. Use `_camelCase` for private fields. Use descriptive names that clearly indicate the purpose of the member. Avoid abbreviations and acronyms. For boolean variables and properties, use names that imply a true/false value (e.g. `isEnabled`, `hasValue`, `canExecute`). For async methods, don't use the `Async` suffix in the method name, as it is already implied by the return type being a `Task` or `Task<T>`, unless the method is an overload of a synchronous method, in which case the async version should have the `Async` suffix to differentiate it from the synchronous version.

## Logging

Inject `Microsoft.Extensions.Logging.ILogger<T>` into classes and use it for logging. See the `csharp-logging` skill for structured logging conventions.

## Design with dependency injection in mind

Inject dependencies through the constructor and avoid using the service provider directly in services (some types of classes can't avoid it, such as factories, but in general avoid it).

The goal is to make dependencies explicit and to allow for easier testing. In general if something is being injected, it should be through an interface, not the concrete type. This allows for easier mocking and testing, and also helps to decouple the code.

## Design with testing in mind

Write code that is easy to test. Write small methods that do one thing, and avoid side effects. Use mockable interfaces for dependencies. Keep persistence and business logic separate to make it easier to test business logic without needing to set up a database or other external dependencies.

If a method is doing datetime logic consider adding a property like `public TimeProvider Clock { get; } = TimeProvider.System;` to the class and using that instead of `DateTime.UtcNow` directly in the method. This allows for easier testing of datetime logic by allowing the test to inject a custom `TimeProvider` that returns fixed values picked to trigger specific code paths.

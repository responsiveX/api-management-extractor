---
name: csharp-logging
description: |
  Amusement Connect C# structured logging conventions — message templates, property naming, log scopes, and serializing complex objects. Use whenever adding or reviewing ILogger calls in a .cs file.
  Triggers on phrases like "add logging", "log this", "how should I log", "structured logging", "review the logging in this file", and similar. Also trigger automatically when opening or editing a .cs file that calls ILogger.
---

# C# Logging Conventions

Inject the `Microsoft.Extensions.Logging.ILogger<T>` interface into classes and use it for logging.

## Use Structured Logging

Log messages should use structured properties with consistent naming conventions. Avoid concatenating strings or using string interpolation for log messages. If a property would apply to multiple log messages, create a log scope to avoid having to repeat the property in every log message.

## Log event messages should be fragments, not sentences

Noncompliant Code Examples:

```csharp
_logger.LogError("Disk quota {Quota} MB exceeded by {User}.", quota, user);
```

Compliant Solution:

```csharp
_logger.LogError("Disk quota {Quota} MB exceeded by {User}", quota, user);
```

## Log event messages should read naturally when the structured properties are filled in

Log message templates should be able to be read as a short statement. Messages that try to cram too many properties into the message template can be hard to read and understand. If there are a lot of properties that should be added to the log event, consider using a log scope.

Good:

```csharp
using var scope = _logger.BeginScope<Dictionary<string, object>>(new Dictionary<string, object>
{
    ["GameMachineId"] = gameMachineId,
    ["LocationId"] = locationId
});
_logger.LogInformation("Starting gameplay session {GameplaySessionId} for player {PlayerId}", gameplaySessionId, playerId);
```

Bad:

```csharp
_logger.LogInformation("Starting gameplay session GameplaySessionId={GameplaySessionId} PlayerId={PlayerId} GameMachineId={GameMachineId} LocationId={LocationId}", gameplaySessionId, playerId, gameMachineId, locationId);
```

## Structured log property names

Property names should be PascalCase and should be consistent across log messages (and services!).

## Adding complex objects to log messages

In order for complex objects to be logged properly, they must be serialized to JSON first.

Example:

```csharp
_logger.LogInformation("Processing complex object: {ComplexObject}", JsonSerializer.Serialize(complexObject));
```

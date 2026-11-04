---
name: service-bus
description: |
  Amusement Connect conventions for publishing and subscribing to Azure Service Bus messages using the shared AmusementConnect.Messaging and AmusementConnect.Messaging.ServiceBus libraries. Use this skill when defining a message contract, calling IMessagePublisher, wiring up AddMessagePublisher/AddServiceBus/MapMessageToTopic in Program.cs, writing or reviewing an Azure Functions [ServiceBusTrigger] handler, choosing a topic or subscription name, adding Service Bus topics/subscriptions in Bicep, or writing tests for message publishing or handling.
  Triggers on phrases like "publish a message", "publish to service bus", "subscribe to a topic", "add a service bus message", "create a message contract", "add a ServiceBusTrigger function", "how do we name this topic", "add a subscription", and similar. Also trigger automatically when opening a .cs file under a Messaging/ or Messages/ folder, or a Functions project file containing [ServiceBusTrigger].
---

# Service Bus Messaging

Conventions for asynchronous, message-based communication between Amusement Connect services over Azure Service Bus. Covers the shared `AmusementConnect.Messaging` (transport-agnostic abstractions) and `AmusementConnect.Messaging.ServiceBus` (Service Bus transport) NuGet packages, plus the Azure Functions patterns every service uses to consume messages.

**Scope note:** these libraries and this skill cover Azure Service Bus only. `AmusementConnect.Messaging.EventHubs` is a separate, unrelated package used for raw IoT device telemetry ingestion (device-to-cloud), not app-to-app pub/sub — don't conflate the two. Some repos also keep a top-level `messages/<name>/<date>/schemas` folder of JSON Schema files documenting device-facing (IoT) message shapes; that folder is unrelated to the C# `IMessage` contracts described below.

## The library only covers publishing

`IMessagePublisher` and `AddServiceBus(...)` are the entire surface of the shared library — there is no shared subscriber/handler interface, no `ServiceBusProcessor` wrapper, and no built-in retry/dead-letter/poison-message handling. **Subscribing is done entirely through the native Azure Functions `[ServiceBusTrigger]` binding** in each service's Functions app, with manual JSON deserialization of the message body. Keep this split in mind: "publish" is a shared-library concern, "subscribe" is a per-service Azure Functions concern.

## Message contracts

Message contracts live in a project-level `Messaging/` or `Messages/` folder (naming varies slightly by repo — `Messaging/` in device-service and asset-service, `Messages/` in wallet-service and notification-service), namespaced as `<Project>.Messaging` / `<Project>.Messages`.

Only implement `IMessage` on a contract if **this service publishes it**. A type this service only receives and manually deserializes from a `ServiceBusReceivedMessage` doesn't need to implement `IMessage`.

Preferred style for new contracts — a `[Equatable]` partial class with `required init` properties (from the `Generator.Equals` source generator, which gives you value-equality for free — useful for serialization round-trip tests):

```csharp
using AmusementConnect.Messaging;
using Generator.Equals;

namespace AmusementConnect.WidgetService.Messages;

[Equatable]
public partial class WidgetCreatedMessage : IMessage
{
    public required Guid WidgetId { get; init; }
    public required string LocationId { get; init; }
    public DateTime? ClientRequestedAtUtc { get; init; }
}
```

A `record` with explicit `[JsonPropertyName]` is also acceptable, especially for simpler messages:

```csharp
public record WidgetRetiredMessage(
    [property: JsonPropertyName("widgetId")] Guid WidgetId,
    [property: JsonPropertyName("reason")] string Reason
) : IMessage;
```

Avoid the older `[DataMember(Name = ..., EmitDefaultValue = false)]` / `[Required]` attribute style seen on legacy device/meter messages — it's a holdover from a previous serialization stack, not the current convention.

### Polymorphic sub-messages

When a message field can take one of several shapes (e.g. a transaction type), use `System.Text.Json` polymorphism with an explicit `"Unknown"` fallback so an unrecognized discriminator deserializes safely instead of throwing:

```csharp
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]
[JsonDerivedType(typeof(CreditPurchaseMessage), "CreditPurchase")]
[JsonDerivedType(typeof(TabPurchaseMessage), "TabPurchase")]
[JsonDerivedType(typeof(UnknownTransactionMessage), "Unknown")]
public abstract partial class TransactionMessage
{
    [JsonIgnore] public abstract string Type { get; }
}
```

## Publishing

### DI setup

Chain `AddMessagePublisher()` → `AddServiceBus(...)` → one `MapMessageToTopic<T>(...)` call per message type this app publishes. Do this in every app (Web API and Functions) that calls `IMessagePublisher.Publish` — each app only needs to map the message types it actually publishes.

```csharp
builder.Services
    .AddMessagePublisher()
    .AddServiceBus(o => o.BindConfiguration("ServiceBus"))
    .MapMessageToTopic<WidgetCreatedMessage>(
        builder.Configuration.GetRequiredValue<string>("ServiceBus:WidgetCreated:TopicName"))
    .MapMessageToTopic<WidgetRetiredMessage>(
        builder.Configuration.GetRequiredValue<string>("ServiceBus:WidgetRetired:TopicName"));
```

Publishing a message type that was never mapped with `MapMessageToTopic<T>` throws at runtime ("No publishers registered for message ..."). If you add a new `Publish(new SomeMessage {...})` call site, add the matching `MapMessageToTopic<SomeMessage>(...)` registration in the same change.

`AddServiceBus` also registers a health check per topic by default (tagged `servicebus`, `messaging`) — no extra wiring needed. Pass `registerHealthChecks: false` only if you have a specific reason to opt out.

### Publish call sites

Inject `IMessagePublisher` and call `Publish` with the constructed message. Prefer persisting the underlying state change before publishing, so a failed publish doesn't leave a message describing something that never actually happened:

```csharp
public async Task CreateWidget(Widget widget)
{
    await _widgetRepository.Save(widget);
    await _messagePublisher.Publish(new WidgetCreatedMessage
    {
        WidgetId = widget.Id,
        LocationId = widget.LocationId
    });
}
```

### Custom serialization

The default `IServiceBusMessageFactory` serializes with `JsonSerializerOptions.Default`. If your service's JSON conventions differ (e.g. camelCase, custom converters), register your own factory **before** calling `AddServiceBus`/`MapMessageToTopic` — the library uses `TryAddTransient`, so the first registration wins:

```csharp
builder.Services.AddTransient<IServiceBusMessageFactory>(
    _ => new DefaultJsonServiceBusMessageFactory(myJsonSerializerOptions));

builder.Services
    .AddMessagePublisher()
    .AddServiceBus(o => o.BindConfiguration("ServiceBus"))
    .MapMessageToTopic<WidgetCreatedMessage>(topicName);
```

## Subscribing

Every subscriber is an Azure Functions method bound with `[ServiceBusTrigger(topicSetting, subscriptionSetting, Connection = "ServiceBus")]`, taking a `ServiceBusReceivedMessage` and manually deserializing the body. Topic and subscription names are resolved from configuration via the `%Section:Key%` placeholder syntax, matching the same config keys used on the publishing side.

```csharp
public class WidgetCreatedHandler(ILogger<WidgetCreatedHandler> logger, IWidgetSyncService syncService)
{
    [Function(nameof(WidgetCreatedHandler))]
    public async Task RunAsync(
        [ServiceBusTrigger(
            "%ServiceBus:WidgetCreated:TopicName%",
            "%ServiceBus:WidgetCreated:SubscriptionName%",
            Connection = "ServiceBus")]
        ServiceBusReceivedMessage message,
        CancellationToken cancellationToken)
    {
        var jsonOpts = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        jsonOpts.UseWidgetServiceConfiguration();

        var widgetCreated = message.Body.ToObjectFromJson<WidgetCreatedMessage>(jsonOpts);
        if (widgetCreated is null)
        {
            logger.LogError(
                "Failed to deserialize WidgetCreatedMessage. MessageId: {MessageId}, Body: {Body}",
                message.MessageId, message.Body.ToString());
            return;
        }

        await syncService.SyncWidget(widgetCreated.WidgetId, cancellationToken);
    }
}
```

Guard clauses that log and `return` on a null/invalid deserialization are the standard way to drop an unprocessable message without throwing.

### Manual complete/abandon control

Default to letting the Functions runtime auto-complete on success and auto-retry/dead-letter on an unhandled exception — that's correct for most handlers. Only take on `ServiceBusMessageActions` when you need to distinguish "retry this" from "fail this," e.g. abandoning (forcing immediate redelivery) instead of throwing:

```csharp
[Function(nameof(StartDeviceForGameplayFunction))]
public async Task RunAsync(
    [ServiceBusTrigger("%ServiceBus:StartDeviceForGameplay:TopicName%",
        "%ServiceBus:StartDeviceForGameplay:SubscriptionName%", Connection = "ServiceBus")]
    ServiceBusReceivedMessage message,
    ServiceBusMessageActions messageActions,
    CancellationToken cancellationToken)
{
    var started = await TryStartDevice(message, cancellationToken);
    if (!started)
    {
        await messageActions.AbandonMessageAsync(message, cancellationToken: cancellationToken);
        return;
    }
    await messageActions.CompleteMessageAsync(message, cancellationToken);
}
```

### Dead-letter handlers

For a subscription where exhausted retries should trigger some kind of rollback operation (rather than the message just sitting in the DLQ waiting to be manually reprocessed or purged later), add a second function bound to the same subscription's dead-letter path and have it handle the failed message processing, sometimes by publishing another compensating event, explicit failure event, executing rollback operations, or being recorded as a permanent failure in the database.:

Example setup:

```csharp
[Function("StartDeviceForGameplayDeadLetterHandler")]
public async Task HandleDeadLetteredMessageAsync(
    [ServiceBusTrigger(
        "%ServiceBus:StartDeviceForGameplay:TopicName%",
        "%ServiceBus:StartDeviceForGameplay:SubscriptionName%/$deadletterqueue",
        Connection = "ServiceBus")]
    ServiceBusReceivedMessage message,
    CancellationToken cancellationToken)
{
    //...
}
```

### Idempotency

Service Bus delivers at-least-once. None of the current handlers implement explicit deduplication (no idempotency key, no reliance on Service Bus's `MessageId`-based duplicate detection on the consume side), so handlers should be written to tolerate reprocessing — prefer upserts over inserts, and design side effects so running them twice for the same message is harmless. Don't assume a handler runs exactly once.

## Naming conventions

- **Topics:** `Domain.PastTenseVerb`, PascalCase — e.g. `Widget.Created`, `GameplaySession.Started`, `Device.FailedToStart`, `HappyHour.Started`.
- **Breaking contract changes:** bump the topic name itself with a `-V2` suffix (e.g. `Collection.Created-V2`) rather than adding an in-payload schema version field. This means a breaking change requires provisioning a new topic/subscription and pointing publishers/consumers at the new name.
- **Subscriptions:** `<ConsumingServiceName>.<PurposeOrFunctionName>` — one subscription per consuming Function, e.g. `WidgetService.WidgetSyncProcessor`, `AssetService.CollectionProcessor`. Always prefix with the name of the service that owns the subscription, even though the topic is owned by whichever service publishes it.
- **Config keys:** nest topic/subscription names under `ServiceBus:<MessageOrFeatureName>:{TopicName,SubscriptionName}` in `appsettings*.json` / `local.settings.json`, e.g. `ServiceBus:WidgetCreated:TopicName`. Use the same key names on both the publisher's `MapMessageToTopic` call and the subscriber's `[ServiceBusTrigger]` placeholders so the mapping is easy to trace. In deployed App Service/Functions settings this becomes `ServiceBus__WidgetCreated__TopicName` (double-underscore delimiter).
- **Auth:** production and higher environments authenticate via managed identity (`ServiceBus__Credential=managedidentity`), not a connection string. A connection string / SAS key in `local.settings.json` is a local-dev-only convenience (e.g. against the Service Bus emulator).

### Infrastructure (Bicep)

All services share a single Service Bus namespace (`sb-ac-shared-<env>-<region>.servicebus.windows.net`) provisioned in a shared resource group. Declare topics and subscriptions through the shared `modules/servicebus/servicebus.bicep` module (which fans out to per-topic and per-subscription child modules), passing senders/receivers as service principals so RBAC (`Azure Service Bus Data Sender` / `Data Receiver`) is granted per principal, not via shared keys:

```bicep
param widgetCreatedTopicName string = 'Widget.Created'
param widgetCreatedSubscriptionName string = 'WidgetService.WidgetSyncProcessor'

module serviceBus 'modules/servicebus/servicebus.bicep' = {
  name: 'widget-servicebus'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    serviceBusName: serviceBusName
    topics: [
      {
        name: widgetCreatedTopicName
        senders: [ apiServicePrincipal ]
        subscriptions: [
          { name: widgetCreatedSubscriptionName, receivers: [ functionAppServicePrincipal ] }
        ]
      }
    ]
  }
}
```

If your service only subscribes to a topic another service owns, set `existing: true` on that topic entry instead of redeclaring it, and list only your own subscription underneath it.

## Testing

Mock or fake `IMessagePublisher` at the service layer — don't stand up a real Service Bus connection in unit tests. Both approaches are used and both are fine:

```csharp
var mockPublisher = new Mock<IMessagePublisher>();
mockPublisher
    .Setup(p => p.Publish(It.IsAny<WidgetCreatedMessage>()))
    .Returns(Task.CompletedTask)
    .Verifiable(Times.Once);

await subject.CreateWidget(widget);

mockPublisher.Verify();
```

A hand-rolled fake that records every published message is useful when a test needs to inspect the message's contents rather than just assert it was called:

```csharp
public class TestPublisher : IMessagePublisher
{
    public List<object> PublishedMessages { get; } = [];
    public Task Publish<T>(T message) where T : IMessage
    {
        PublishedMessages.Add(message);
        return Task.CompletedTask;
    }
    // implement the remaining IMessagePublisher overloads the same way
}
```

For message contracts — especially ones with polymorphic sub-types — add a serialization round-trip test that serializes, asserts on key JSON properties (e.g. the type discriminator), then deserializes and asserts equality (the `[Equatable]` source generator makes this a plain `Assert.AreEqual`). This guards against accidentally breaking the wire format when a contract changes.

There is generally no test that invokes a `[ServiceBusTrigger]` function's `RunAsync` directly — handler tests stop at the service-layer method the function delegates to. Follow that boundary: keep Functions handlers thin (deserialize, validate, delegate) so the service-layer tests give real coverage.

## Known library limitations

- `IMessagePublisher.Publish(IEnumerable<T>)` does **not** batch messages into a single Service Bus batch send despite what its doc comment implies — it sends them one at a time in a loop. Don't rely on it for batch-send performance or atomicity.
- There is no correlation ID field on `MessageOptions`, even though the underlying `ServiceBusMessage.CorrelationId` exists. If you need one, register a custom `IServiceBusMessageFactory` rather than expecting the library to thread one through.
- Topic names are always explicit strings passed to `MapMessageToTopic<T>(name)` — there's no reflection/convention-based topic derivation to rely on or fight against.

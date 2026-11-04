# Repository patterns

This file covers the repository, the mapper, the registration, and the mapper test. For the document class, read `document-anatomy.md`.

## Contents

- The two styles
- Style A: RepositoryHelper
- Style B: direct container
- Rules that apply to both
- Mappers
- Registration
- The mapper test

## The two styles

Two repository styles are in use. Neither one is deprecated.

| | Style A: `RepositoryHelper` | Style B: direct container |
| --- | --- | --- |
| Used by | asset-service, reporting-api, device-service, notification-service | wallet-service, organization-service |
| You write | A mapper pair and thin pass-through methods | The Cosmos calls yourself |
| Type filter | Added for you from the type you pass | You add it to every query |
| Good for | Ordinary read, list, and upsert work | Exact status-code behavior, complex LINQ, request-unit logging |

Match the service you are working in. If the service uses both, pick style A for ordinary work. If you need a specific Cosmos response, pick style B. Examples are a 409 Conflict for deduplication, or a query the helper does not express.

## Style A: RepositoryHelper

Construct a `RepositoryHelper<TModel, TDocument>` in the repository constructor. Pass the mapper functions, the database, the collection, the client, the document type, and the partition key property name. The helper then applies the type filter to its queries.

```csharp
public class GameMachineHistoryRepository : IGameMachineHistoryRepository
{
    public const string DocumentType = "gameMachineHistory";

    private const int DocumentVersion = 1;

    private readonly RepositoryHelper<GameMachineHistory, Documents.GameMachineHistory> _repositoryHelper;

    public GameMachineHistoryRepository(CosmosClient cosmosClient, IOptions<DeviceCosmosDbOptions> config)
    {
        _repositoryHelper = new RepositoryHelper<GameMachineHistory, Documents.GameMachineHistory>(
            MapToModel,
            MapToDocument,
            config.Value.DatabaseName,
            config.Value.CollectionName,
            cosmosClient,
            DocumentType,
            true,
            "cosmosDoc_partitionKey"
        );
    }

    public async Task<GameMachineHistory?> GetByIdAsync(string id, CancellationToken ct) =>
        await _repositoryHelper.GetAsync(id, ct);
}
```

Always pass the `CosmosClient` from dependency injection. The helper has constructor overloads that build their own client from an endpoint and a key. That client is configured with `JsonSerializerOptions.Default`, which serializes property names in PascalCase. A document written through it does not match a document written through the service client.

## Style B: direct container

Take the `CosmosClient` and the options, and resolve the container once in the constructor.

```csharp
public class CosmosTabRepository : ITabRepository
{
    private readonly Container _container;
    private readonly ILogger<CosmosTabRepository> _logger;

    public CosmosTabRepository(
        CosmosClient cosmosClient,
        IOptionsSnapshot<WalletCosmosDbOptions> cosmosDbOptions,
        ILogger<CosmosTabRepository> logger)
    {
        _container = cosmosClient.GetContainer(
            cosmosDbOptions.Value.DatabaseName,
            cosmosDbOptions.Value.CollectionName);
        _logger = logger;
    }
}
```

A point read needs the id and the partition key. Catch the not-found case and return null, because a missing document is a normal result and not an error.

```csharp
try
{
    var response = await _container.ReadItemAsync<TabDocument>(
        id,
        new PartitionKey(partitionKey),
        cancellationToken: ct);

    return MapToModel(response.Resource);
}
catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
{
    return null;
}
```

A LINQ query needs the type filter and, where possible, the partition key.

```csharp
var queryable = _container.GetItemLinqQueryable<TabDocument>(
        requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(locationId.ToString()) })
    .Where(t => t.CosmosDocType == TabDocument.DocumentType)
    .Where(t => t.Payment.CustomerId == customerId);
```

A SQL query needs the same filter as a parameter. Never build a query string by concatenation.

```csharp
var queryDef = new QueryDefinition(
        "SELECT * FROM c WHERE c.status = @status AND c.cosmosDoc_type = @documentType")
    .WithParameter("@status", JsonNamingPolicy.CamelCase.ConvertName(nameof(TabStatus.Open)))
    .WithParameter("@documentType", TabDocument.DocumentType);
```

Note the enum parameter. The stored value is the camelCase name, so the query converts the name rather than hard-coding a literal. A rename of the enum member then breaks the build instead of the query.

Log the request charge on a query that can grow. Cost is the thing that goes wrong quietly.

```csharp
_logger.LogInformation("Stale tab query page: {Count} items, {RU} RU", page.Count, page.RequestCharge);
```

## Rules that apply to both

Take a `CancellationToken` on every public method and pass it through to the SDK call.

Return domain models, never documents. The document type and the mapper stay inside the data project. The interface lives with the other repository interfaces in the service's `Data/Repositories` namespace.

Use `UpsertItemAsync` for a document that a caller can write more than once. If a second write must fail, use `CreateItemAsync`. That is the deduplication case in `document-anatomy.md`.

If the repository departs from the service's usual style, add an XML comment on the class. State the reason. The Toast marker repository does this, because the whole point of it is the exact behavior of a conflicting insert.

## Mappers

Two mapper layouts are in use.

Asset-service and reporting-api put a static class in `Mapping/<Name>Mapper.cs` with `ToDocument` and `ToModel` extension methods. Nested types get their own overloaded pair in the same file. Each method returns null for a null input and carries `[return: NotNullIfNotNull(nameof(source))]`.

```csharp
[return: NotNullIfNotNull(nameof(source))]
public static Documents.DeviceMetersGame? ToDocument(this DeviceMetersGame? source) =>
    source == null ? null : new Documents.DeviceMetersGame { Id = source.Id };
```

Wallet-service, organization-service, and device-service put private static `MapToDocument` and `MapToModel` methods on the repository itself. Use this layout for a small document with few nested types.

Whichever layout you use, the `ToDocument` direction sets `Id`, `CosmosDocPartitionKey`, and `CosmosDocVersion`. The `ToModel` direction does not map them back, because they are storage concerns and the domain model does not carry them.

## Registration

Register the repository in the service's `ServiceCollectionExtensions`, beside the existing ones.

```csharp
services.AddTransient<IToastProcessedOrderRepository, ToastProcessedOrderRepository>();
```

The `CosmosClient` is a singleton, and it is registered once per service with the serializer and the application name. Do not register a second one.

```csharp
services.AddSingleton<CosmosClient>(sp => new CosmosClient(
    sp.GetRequiredService<IOptions<PartnerCollectionCosmosDbOptions>>().Value.EndpointUrl,
    sp.GetRequiredService<TokenCredential>(),
    new CosmosClientOptions
    {
        Serializer = new SystemTextJsonCosmosSerializer(jsonOptions),
        ApplicationName = "Organization Service"
    }));
```

Authentication uses `TokenCredential`, not an account key.

## The mapper test

Write one MSTest class per mapper, in the `...Data.Cosmos[Db].Testing.Unit.MsTest/Mapping/` project. Build a fully populated model, map it, and assert the mapped document.

Three assertions matter more than the rest, because they pin the things that a later edit can break in silence:

```csharp
Assert.AreEqual(model.Id, document.Id);
Assert.AreEqual($"{model.Location.Id}|{model.Game.Id}", document.CosmosDocPartitionKey);
Assert.AreEqual(Documents.DeviceMeterReport.DocumentVersion, document.CosmosDocVersion);
```

Then assert every mapped property. The point of the test is coverage, not elegance. A long list of `Assert.AreEqual` calls is the correct shape here, because a dropped property is the failure this test exists to catch.

Add a round-trip test for a document with type conversions in the mapper. Examples are a `Guid` stored as a string, an enum stored as its name, and a time zone stored as an id. Map model to document to model. Assert that the result equals the original.

# Document anatomy

This file covers the document class itself. For the repository and the mapper, read `repository-patterns.md`.

## Contents

- The base class
- Constants on the document
- Naming
- Property conventions
- Building the id
- Choosing the partition key
- Related entities
- Nested models
- Forward compatibility

## The base class

Every document derives from `AmusementConnect.Data.CosmosDb.Document`, which lives in `lib-amusementconnect`. The base class carries the properties that Cosmos and the platform own.

| Property | Stored as | Who sets it |
| --- | --- | --- |
| `Id` | `id` | Your mapper or repository |
| `CosmosDocType` | `cosmosDoc_type` | The base constructor only. The property is get-only |
| `CosmosDocPartitionKey` | `cosmosDoc_partitionKey` | Your mapper or repository |
| `CosmosDocVersion` | `cosmosDoc_version` | Your constructor or mapper |
| `CosmosDocTimestamp` | `_ts` | Cosmos |
| `CosmosDocETag` | `_etag` | Cosmos |

The base constructor takes the document type. A derived document therefore has a parameterless constructor that passes the type up.

```csharp
public class TabDocument : Document
{
    public static readonly string DocumentType = "gameplayTab";

    public TabDocument() : base(DocumentType)
    {
    }
}
```

The primary-constructor form is also in use, and it is fine for a document with no version constant.

```csharp
public class AssetDocument() : Document(cosmosDocType: "asset")
{
}
```

## Constants on the document

Put `DocumentType` on the document class. Older code puts it on the repository, and `Documents/Device.cs` in device-service still reads `base(DeviceRepository.DocumentType)`. New code puts the constant on the document, because the document is what the string describes. Anything that needs the string then has one place to read it.

If the stored shape is likely to change, add a `DocumentVersion` constant. Set `CosmosDocVersion` from it in the constructor.

```csharp
public class CardTransactionDocument : Document
{
    public static readonly string DocumentType = "cardTransaction";
    public static readonly string DocumentVersion = "1.0";

    public CardTransactionDocument() : base(DocumentType)
    {
        CosmosDocVersion = DocumentVersion;
    }
}
```

Both `const string` and `static readonly string` appear in the codebase. Either is acceptable. Match the service you are in.

## Naming

Name a new document class with a `Document` suffix, as in `TabDocument`, `AutoReportDeliveryDocument`, and `GoTabLocationMappingDocument`. The suffix separates the stored shape from the domain model, and both often need the same noun.

Older documents carry bare nouns, such as `Device`, `Partner`, and `Location`. Those files use a `Documents.` namespace prefix at every call site to disambiguate. Leave them alone. Do not rename them as a side effect of other work.

## Property conventions

Annotate every property with `[JsonPropertyName]` in camelCase. The reason is in SKILL.md: the naming policy depends on the wiring, so an explicit name is the only reliable one.

```csharp
[JsonPropertyName("reportType")]
public required string ReportType { get; set; }
```

Nullability carries meaning. If the document cannot exist without a property, mark that property `required`. If a property is genuinely optional, mark it nullable. Add an XML comment that names the case where it is absent.

```csharp
/// <summary>
/// Nullable. Only populated for partner-originated card transactions.
/// </summary>
public CardTransactionPartnerModel? Partner { get; set; }
```

Give a collection property an empty default, so that a caller never has to null-check it.

```csharp
public List<CardTransactionCardModel> Cards { get; set; } = [];
```

Use `AmusementConnect.AuditStamp` for created and modified information, rather than loose `CreatedBy` and `CreatedAt` properties.

Store an enum as a string, not as its numeric value. A number in stored data becomes wrong as soon as somebody reorders the enum.

Name a date property for its zone, as in `CreatedDateUtc`, `OpenedDateUtc`, and `ProcessedAtUtc`. The suffix removes the most common source of date bugs in this codebase.

Use `init` rather than `set` for a property the mapper fills once and nothing later changes. The stored snapshot is then immutable in code, and a reader knows at a glance which few properties a repository updates in place.

A computed property is fine if it derives from stored properties. Keep it out of the mapper.

### Expiry

Cosmos reads per-document time to live from a property named `ttl`, in seconds. Declare it on the document, and put the duration beside it as a named constant with a comment that says what the number is sized against.

```csharp
/// <summary>
/// How long a marker is kept, in seconds. Long enough to outlive any plausible webhook retry
/// window, short enough that markers do not accumulate forever.
/// </summary>
public const int TimeToLiveSeconds = 30 * 24 * 60 * 60;

[JsonPropertyName("ttl")]
public int? Ttl { get; set; }
```

Per-document expiry only takes effect if the container has TTL enabled. Say so in the comment, and say what happens without it, so a reader knows whether the feature depends on expiry or merely benefits from it.

```csharp
public decimal TotalCardValueAdded => Cards.Sum(x => x.CreditValueAdded);
```

## Building the id

Prefer a deterministic id over a random one. A deterministic id gives you a point read, which costs about one request unit, instead of a query. It also turns a duplicate write into a 409 Conflict, which is a useful signal.

The house format joins parts with a pipe character.

```
<documentType>|<key>
<documentType>|<keyA>|<keyB>
<keyA>|<keyB>
```

If more than one call site builds the id, put a static `BuildId` method on the document. Both sides then compute the same string by construction.

```csharp
public static string BuildId(Guid partnerOrganizationId, Guid toastOrderId) =>
    $"{DocumentType}|{partnerOrganizationId}|{toastOrderId}";
```

Use a random `Guid` id only for a document with no natural key, such as an append-only event.

### Deduplication through a conflict

A deterministic id plus `CreateItemAsync` gives you deduplication without a lock. Two callers that race compute the same id, so exactly one insert succeeds and the other gets a 409.

```csharp
try
{
    await _container.CreateItemAsync(marker, new PartitionKey(partitionKey), cancellationToken: ct);
    return true;
}
catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
{
    return false;
}
```

## Choosing the partition key

The partition key decides which reads are cheap. A read that supplies the partition key touches one partition. A read without it fans out across all of them.

Start from the question the service asks most often, and partition by the value that question always carries.

Patterns in use across the services:

- A single domain id. Wallet documents partition by `PlayerId`, by a location `ApiIntegrationKey`, or by a game machine id.
- A composite of two ids, joined with a pipe. Asset-service device meter reports use `$"{Location.Id}|{Game.Id}"`.
- The id itself. A configuration document keyed by one organization uses the same string for both.
- A fixed constant. A true singleton document, such as global credit levels, uses a literal like `"player-connect-surcharge-rates"`. Use this only for a document with exactly one instance, because everything under one key shares one partition and its throughput limit.

Set the value in the mapper or the repository.

```csharp
return new Documents.DeviceMeterReport
{
    Id = source.Id,
    CosmosDocPartitionKey = $"{source.Location?.Id}|{source.Game?.Id}",
    CosmosDocVersion = Documents.DeviceMeterReport.DocumentVersion,
    // ...
};
```

On a write, pass the same value to the SDK.

```csharp
await _container.UpsertItemAsync(document, new PartitionKey(document.CosmosDocPartitionKey), cancellationToken: ct);
```

A mismatch between the two produces a document that a later point read cannot find. The mapper test guards against it.

## Related entities

A document that relates to one of the core business entities carries that entity as a nested object under a fixed property name. The names are the same in every service and every document type.

| Entity | Property | Stored as | Id path |
| --- | --- | --- | --- |
| Location | `Location` | `location` | `location.id` |
| Organization | `Organization` | `organization` | `organization.id` |
| Partner | `Partner` | `partner` | `partner.id` |
| Player | `Player` | `player` | `player.id` |
| Device | `Device` | `device` | `device.id` |
| Game machine | `GameMachine` | `gameMachine` | `gameMachine.id` |

The entity object always leads with `id`. Beyond that, carry whatever fields this document's readers need.

```csharp
public class LocationIdModel
{
    public required string Id { get; set; }

    public required int SequentialId { get; set; }

    public int? LocationGroupId { get; set; }
}

public class LocationModel : LocationIdModel
{
    public string? Name { get; set; }

    public decimal CreditPerDollar { get; set; }

    public CurrencyCode CurrencyCode { get; set; }

    public string? TimeZoneId { get; set; }
}
```

The pattern of an id-only base with a richer subclass is worth copying. A document that only needs the id uses the base. A document that needs the denormalized fields uses the subclass. Both serialize an `id` in the same place.

### Why the shape is fixed

One query then reaches every document type that touches one entity, without knowing which types exist.

```sql
SELECT * FROM c WHERE c.location.id = @locationId
```

A service almost never runs that query, because a service knows which document type it wants. The value is downstream. The data warehouse ingests all of these documents from the change feed, and the fixed shape is what lets it join them to a location, an organization, or a player without a rule per document type. Every document that flattens the relationship into a `LocationId` string becomes a special case in that pipeline.

So treat the entity property name and its `id` as a contract with people outside the service, and add a new entity name only when no existing one fits.

The rule holds even for a document whose whole body is the key. `ToastProcessedOrder` in organization-service stores a bare `partnerOrganizationId` Guid instead of an `organization` object. That one is a known outlier that got through review. Do not copy it.

## Nested models

A document with sub-objects needs a type per sub-object. Two layouts are in use.

Wallet-service puts them in `Documents/Models/` with a `Model` suffix, such as `LocationModel` and `CardTransactionPartnerModel`. Shared shapes derive from a small id-only base, such as `LocationIdModel`. Use this layout for a service with many documents that share sub-objects.

Asset-service and reporting-api put them in `Documents/` beside the document, named after the document, such as `DeviceMetersGame` and `DeviceMetersLocation`. Use this layout for a service where each document owns its own sub-objects.

A nested model is a plain class. It does not derive from `Document` and it carries no `cosmosDoc_` properties. Annotate its properties the same way.

```csharp
public class DeviceMetersGame
{
    /// <summary>
    /// Unique identifier for the game.
    /// </summary>
    [JsonPropertyName("id")]
    public string? Id { get; set; }
}
```

Keep a nested model narrow. Copy in the fields a reader of this document needs, and no more. A nested model is a snapshot at write time, not a foreign key that stays fresh.

## A document that mirrors another service

Some documents are a local copy of data another service owns, kept so a hot path does not have to call across the network. A copy needs more than the copied fields, because a reader cannot otherwise tell a fresh copy from a stale one.

Carry three things beyond the payload:

- When the copy was last refreshed, so a reader can judge staleness and an operator can spot a stalled sync.
- The current state of the relationship, as an enum rather than a bare boolean. The source can remove a mapping as well as add one, and a deleted row upstream has to become a state here rather than a missing document.
- An `AuditStamp` for the transitions that matter, such as when the relationship was established and when it ended.

Without these, the only way to answer "is this mapping still real?" is to call the service the copy exists to avoid calling.

## Forward compatibility

A document that receives data from an external system can carry an extension-data property. Unknown properties then survive a read and write cycle instead of being dropped.

```csharp
[JsonExtensionData]
public Dictionary<string, JsonElement>? AdditionalProperties { get; set; }
```

Add it for a document fed by a third-party webhook or an external transaction feed. Leave it off a document whose shape the service fully owns.

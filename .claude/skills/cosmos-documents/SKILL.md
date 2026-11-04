---
name: cosmos-documents
description: |
  Amusement Connect conventions for a new Cosmos DB document in a microservice.
  The skill covers the document class and its nested models.
  It also covers the type constant, the version constant, the id, and the partition key.
  It also covers the repository, the mapper, and the mapper test.
  Use this skill for work in any *.Data.Cosmos or *.Data.CosmosDb project.
  Trigger phrases include "add a cosmos document" and "new document type".
  Other trigger phrases are "store this in cosmos" and "persist this to cosmos db".
  Other trigger phrases are "add a repository for" and "what partition key does this use".
  A request like "save this webhook payload somewhere" also triggers the skill.
  The user does not always say the word cosmos, so trigger on the intent.
  Also trigger on any .cs file under a Documents/ folder.
  Also trigger on a Cosmos*Repository.cs file or a *RepositoryHelper.cs file.
  Also trigger on a Mapping/*Mapper.cs file in a Cosmos data project.
---

# Cosmos Documents

Every Amusement Connect service stores its Cosmos documents in one shared container. Documents of many shapes sit side by side in that container. A discriminator property named `cosmosDoc_type` tells them apart. Almost every convention below exists because of that one fact. Keep it in mind and the rest follows.

Use this skill with `csharp-code-style` for naming and formatting. Use it with `csharp-testing` for the MSTest and Shouldly stack.

## What a new document costs

A document rarely arrives alone. Plan on four or five files.

| File | Where | Always? |
| --- | --- | --- |
| The document class | `src/AmusementConnect.<Service>.Data.Cosmos[Db]/Documents/<Name>Document.cs` | Yes |
| Nested value types | `Documents/Models/<Name>Model.cs`, or beside the document in `Documents/` | Only for a document with sub-objects |
| The repository | `<Name>Repository.cs` or `Cosmos<Name>Repository.cs` in the data project root | Yes |
| The repository interface | The service's `Data/Repositories` namespace, beside the other interfaces | Yes |
| The mapper | `Mapping/<Name>Mapper.cs`, or private static methods on the repository | Yes, in one of those two forms |
| The mapper unit test | `...Data.Cosmos[Db].Testing.Unit.MsTest/Mapping/<Name>MapperTests.cs` | Yes |

Find the existing documents in the target service and follow the shape that service already uses. Consistency inside one service beats consistency across seven services. The person who maintains the code reads one repository, not all of them.

## Workflow

### 1. Read a neighbour first

Open two or three existing documents in the same service. Open their repositories too. The service already picked a repository style, a mapper style, and a partition key strategy. Match it. Do not import a pattern from a different service.

### 2. Choose the partition key before you write code

This decision is expensive to reverse. A change to the partition key means a rewrite of stored data. Ask what the service reads by. If every read knows the location, partition by location. If every read knows the player, partition by player. A read that spans partitions is slower and costs more request units. For the composite form and the single-partition case, read `references/document-anatomy.md`.

### 3. Choose the document type string

Use a short camelCase noun that is unique within the container. Examples are `"cardTransaction"`, `"toastProcessedOrder"`, and `"gameMachineHistory"`. The string is stored in every document forever. Treat it as permanent.

### 4. Write the document class

Read `references/document-anatomy.md` first. It covers the base class, the constants, property naming, nullability, and id construction.

### 5. Write the repository

Read `references/repository-patterns.md` first. It covers the two repository styles and the fit of each one. It also covers how the type filter and the partition key reach the query.

### 6. Write the mapper and its test

The test is short and it earns its place. It is the only thing that catches a mapper that drops a property in silence. It also pins the id format and the partition key format. A later edit then cannot change where documents land without a test failure.

### 7. Register the repository

Add the registration to the service's `ServiceCollectionExtensions`, beside the existing repositories.

## The rules that matter most

Filter every query on the document type. The container is shared. A query without `c.cosmosDoc_type = @documentType` returns other teams' documents. Those documents deserialize into your type with every property null. The failure then appears far away from its cause. If you pass the type to `RepositoryHelper`, it adds the filter for you. A hand-written query must add the filter itself.

Give every related entity its house property name and shape. If a document relates to a location, the property is `Location`, it serializes to `location`, and the entity id sits at `location.id`. The same holds for `Organization`, `Partner`, `Player`, `Device`, and `GameMachine`. The shape stays the same in every document type, so one query reaches every document that touches one location:

```sql
SELECT * FROM c WHERE c.location.id = @locationId
```

A service rarely runs that query. The data warehouse runs it constantly, because it ingests all of these document types from the change feed. A document that flattens the relationship to a `LocationId` string drops out of that whole class of query, and someone downstream pays for it.

Annotate every property with `[JsonPropertyName]` in camelCase. The JSON naming policy is not uniform across the wiring. A service that registers its own `CosmosClient` configures `JsonNamingPolicy.CamelCase`. The fallback client inside `RepositoryHelper` uses `JsonSerializerOptions.Default`, which is PascalCase. An unannotated property therefore has a stored name that depends on how the repository was wired. An explicit name makes the stored shape a property of the document, which is where it belongs.

Set the id and the partition key in the mapper or the repository. Never set them inside the document. The document is a serialization shape. The rule for where a document lives belongs with the code that writes it. A reader of the repository then sees the whole story.

Do not redeclare `Id`. The base class already has it. A `public new string? Id` gives you a class with two properties. The value you set and the value that serializes are then different.

Keep the stored contract on the document. The type string, the version constant, the `BuildId` method, and the expiry constant all belong on the document class. The repository still decides what to assign, but a reader of one file sees the whole shape.

Do not try to assign `CosmosDocType`. It is get-only and set through the base constructor. A document therefore cannot exist with the wrong type.

## What to avoid

- A partition key chosen because it was easy to reach in the mapper. Choose it because reads use it.
- A `Guid.NewGuid()` id on a document that has a natural key. A deterministic id lets an insert conflict do deduplication work. It also lets a reader fetch a document without a query first.
- A document type string that already exists in the container.
- A name that describes the storage role rather than the thing recorded. `ToastProcessedOrder` names the fact. `ToastProcessedOrderMarker` names the mechanism, and reads as noise once the reader knows what the document is for.
- A flattened `LocationId`, `OrganizationId`, or `PartnerId` property in place of the nested entity object. Keep the entity shape.
- A repository that returns documents. A repository returns domain models. The document type stays inside the data project.
- A copied mapper with a property still mapped to the wrong source field. The mapper test exists for this case.
- A new non-nullable property on a document with stored data behind it. Older stored documents do not carry the property. A non-nullable value type without a default then deserializes as zero, which reads as real data.

## Reference files

- `references/document-anatomy.md` covers the base class, the constants, property conventions, id construction, partition key strategies, and nested models. Read it before you write the document class.
- `references/repository-patterns.md` covers the two repository styles, how to choose, mapper conventions, registration, and the mapper test. Read it before you write the repository.

# Cosmos DB _etag as the ETag

This file covers resources stored as Cosmos DB documents through `AmusementConnect.Data.CosmosDb`. Read `SKILL.md` first for the HTTP side. Read the `cosmos-documents` skill for the document, repository, and mapper conventions.

Every Cosmos item has a system `_etag` that changes on every write. The `Document` base class already exposes it as `CosmosDocETag` (`string?`). Don't add a second property for it.

## The _etag is already in header form

Cosmos stores `_etag` with the surrounding double quotes, for example `"\"0b00a8f6-0000-0700-0000-6512a5c30000\""`. That makes it a valid strong entity tag as-is. So:

- Document → model: **parse** it with `ETag.TryParse`. Don't use `new ETag(document.CosmosDocETag)`, which would throw on the quote characters.
- Model → Cosmos request options: **format** it with `ETag.ToString()`. That puts the quotes back. `ETag.Value` has no quotes, and Cosmos would never match it.

## Mapper

Map `CosmosDocETag` onto the domain model's `ETag` when you read. Don't map it back onto the document when you write: Cosmos ignores `_etag` in the request body, and concurrency is controlled by request options instead.

```csharp
public static KioskSession ToModel(KioskSessionDocument document) => new()
{
    Id = document.Id,
    // ...
    ETag = ETag.TryParse(document.CosmosDocETag, out var etag)
        ? etag
        : default,
};
```

`default` covers a document that hasn't been written yet and so has no `_etag`.

## The write

Cosmos supports one tag in `IfMatchEtag`, not a list or `*`. So keep the HTTP check in code, and use Cosmos for the race check:

1. Read the document. Return 404 if it's missing.
2. Check `ifMatch.IsSatisfiedByIfMatch(current.ETag)`. Return 412 if it fails.
3. Write with `IfMatchEtag` set to the tag **you read** (`current.ETag.ToString()`), not the client's tag. This catches a write that happens between steps 1 and 3, whatever the client sent.
4. Catch `CosmosException` with `StatusCode == HttpStatusCode.PreconditionFailed` and return 412.
5. Return the new tag from the write response (`response.Resource.CosmosDocETag`, mapped as above) in the `ETag` header.

With `IRepositoryHelper`, use the `UpsertAsync(model, etag, cancellationToken)` overload. It sends `IfMatchEtag` when the tag isn't null or blank:

```csharp
var current = await _repository.GetAsync(id, partitionKey, cancellationToken);
if (current is null)
{
    return NotFound();
}

if (!ifMatch.IsSatisfiedByIfMatch(current.ETag))
{
    return StatusCode(StatusCodes.Status412PreconditionFailed);
}

var updated = current with { Status = KioskSessionStatus.Closed };

try
{
    var saved = await _repositoryHelper.UpsertAsync(
        updated,
        current.ETag.IsEmpty ? null : current.ETag.ToString(),
        CancellationToken.None
    );

    Response.Headers.ETag = saved.ETag.ToString();
    return Ok(KioskSessionResponse.From(saved));
}
catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
{
    return StatusCode(StatusCodes.Status412PreconditionFailed);
}
```

Adapt the read call to the repository's actual API. Read the repository and the helper first, rather than assuming method names.

When the repository uses the Cosmos SDK directly, use `ReplaceItemAsync` with `new ItemRequestOptions { IfMatchEtag = current.ETag.ToString() }` for updates to an existing item. Replace fails with 404 if the item was deleted in the meantime, which is the answer the client needs. Use `DeleteItemAsync` with the same request options for deletes.

If the repository layer catches `CosmosException` and rethrows its own exception type, keep the 412 status distinct from other failures, so the API can map it to 412 and not to 500.

## Things that bump _etag

`_etag` changes on **every** write to the item. That includes writes the user didn't make, such as a Functions trigger that updates a counter, a TTL refresh, or a migration that rewrites the document. Clients holding the old tag then get 412 even though nothing they care about changed. When a document gets frequent background writes, raise this with the user before adding `If-Match` support. Two options are to move the frequently written fields to a separate document, or to accept the extra 412s.

## Testing

Concurrency behavior needs a real Cosmos endpoint: the emulator or a test account, as in `AmusementConnect.Data.CosmosDb.IntegrationTests.MsTest`. Write the document, read it twice, update through the first copy, then update with the second copy's tag and assert a `CosmosException` with `PreconditionFailed`. Unit tests of the controller or service logic can use hand-built `ETag` values with mocked repositories.

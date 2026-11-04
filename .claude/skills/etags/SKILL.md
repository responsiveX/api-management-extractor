---
name: etags
description: |
  Amusement Connect conventions for ETags and optimistic concurrency, using the shared `ETag` / `ETagCondition` types from lib-amusementconnect (`AmusementConnect.Http`). Use this skill whenever an endpoint needs to detect or prevent lost updates. Examples: adding `If-Match` / `If-None-Match` support, returning an `ETag` response header, returning 412 Precondition Failed or 304 Not Modified, exposing a SQL `rowversion` or a Cosmos `_etag` to API clients, or handling `DbUpdateConcurrencyException` or a Cosmos 412.
  Triggers on phrases like "add etags", "optimistic concurrency", "concurrency token", "prevent lost updates", "stale write", "two users editing the same record", "if-match", "412", "304 not modified", "rowversion", "_etag", and similar, even when the user doesn't say "ETag". Also trigger automatically when opening a .cs file that references `ETag`, `ETagCondition`, `RowVersionETagConverter`, `IsRowVersion`, `IfMatchEtag`, or `DbUpdateConcurrencyException`.
---

# ETags and optimistic concurrency

Amusement Connect services use HTTP entity tags for optimistic concurrency. The client reads a resource and receives its ETag. When the client writes, it sends that ETag back in `If-Match`. If the resource changed in the meantime, the write fails with 412 and the client must re-read. No locks are held, and a lost update becomes a visible error.

The shared library provides the types. A service only wires them together. Don't write your own ETag parsing, header comparison, or hashing. The library already implements the RFC 9110 rules, and hand-written versions usually get weak/strong comparison or comma-separated lists wrong.

## The pieces

| Type | Package | Use |
| --- | --- | --- |
| `ETag` | AmusementConnect | One tag. Put it on entities, documents, domain models, and response models. `default(ETag)` means "no tag" (`IsEmpty`). |
| `ETagCondition` | AmusementConnect | The parsed `If-Match` / `If-None-Match` header: `*` or a list of tags. `default(ETagCondition)` means the header was absent. |
| `ETagJsonConverter` | AmusementConnect | Already applied to `ETag` with an attribute. No registration is needed. Serializes as the header form (`"\"0000000000000FA1\""`), or `null` when empty. |
| `ETagModelBinderProvider` | AmusementConnect.Hosting.Web | Lets MVC controllers bind both types from headers. `AddAmusementConnectWebDefaults` registers it. Otherwise, call `builder.AddAmusementConnectModelBinding()`. |
| `RowVersionETagConverter` | AmusementConnect.Data.Sql | EF Core converter from a SQL `rowversion` column to a strong `ETag`. |

The types are in the `AmusementConnect.Http` namespace, so add `using AmusementConnect.Http;`. They are deliberately not in the root `AmusementConnect` namespace. Azure SDK packages define `Azure.ETag`, and a root-level type would be ambiguous in any file that also has `using Azure;`. If a file has both usings, alias one of them:

```csharp
using ETag = AmusementConnect.Http.ETag;
```

If `AmusementConnect.Http` doesn't resolve, the service's packages predate these types. Update every `AmusementConnect*` package to the same newer version together, because the packages share one version line.

## Where the ETag comes from

The tag must change whenever the stored resource changes. The safest way is to let the database generate it, so no code path can forget to bump it:

- **SQL Server with EF Core:** a `rowversion` column mapped with `RowVersionETagConverter`. Read `references/sql-rowversion.md`.
- **Cosmos DB:** the `_etag` system property that every `Document` already has (`CosmosDocETag`). Read `references/cosmos-etag.md`.

Read only the reference for the store the resource lives in. Other ETag sources, such as a hash of the response body or a manually incremented version, are a last resort for resources with no backing store. Discuss them with the user before you build one.

## Flow of the tag through the layers

1. **Storage → domain model.** The entity or document carries the tag. Map it onto the domain model as an `ETag` property, usually called `ETag`. It must survive mapping, or the API layer has nothing to compare against.
2. **Domain model → response.** Put the tag on the response model (`public ETag ETag { get; init; }`), so items in a list response carry their own tag. On single-resource responses, also set the `ETag` response header.
3. **Request → check.** Bind `If-Match` as an `ETagCondition`. Compare it against the current tag before you change anything.
4. **Write → store-level check.** Save in a way that makes the store reject the write if the row changed after you read it. This covers the window between your check and your write. See the reference file for your store.
5. **Conflict → 412.** Turn both a failed precondition and a store-level conflict into 412 Precondition Failed.

Steps 3 and 4 are both needed. Step 3 rejects stale clients. Step 4 handles two requests that both pass step 3 at the same moment.

## Controller patterns

### Updates (PUT, or POST on a sub-resource) and deletes

`If-Match` is **optional** by default. If the header is present, the request must satisfy it. If it is absent, the write goes ahead, still protected by the store-level check in step 4. Existing clients keep working, and clients that care about lost updates opt in. Return 428 Precondition Required for a missing header only when the user explicitly asks for it. That breaks existing clients and needs a new API version (see the `api-design` skill).

```csharp
[HttpPut("{id}")]
public async Task<IActionResult> Update(
    [FromRoute] int id,
    [FromBody] KioskOfferingUpdateRequest body,
    [FromHeader(Name = "If-Match")] ETagCondition ifMatch,
    CancellationToken cancellationToken
)
{
    var offering = await _db.KioskOffering.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);
    if (offering is null)
    {
        return NotFound();
    }

    if (!ifMatch.IsSatisfiedByIfMatch(offering.ETag))
    {
        return StatusCode(StatusCodes.Status412PreconditionFailed);
    }

    offering.Name = body.Name;

    try
    {
        await _db.SaveChangesAsync(CancellationToken.None);
    }
    catch (DbUpdateConcurrencyException)
    {
        return StatusCode(StatusCodes.Status412PreconditionFailed);
    }

    Response.Headers.ETag = offering.ETag.ToString();
    return NoContent();
}
```

Notes on this pattern:

- **Compare with `IsSatisfiedByIfMatch`, not `==`.** `If-Match` needs the RFC strong comparison, accepts a list of tags, and has special `*` semantics. The method handles all three. `ifMatch.Tags.Contains(...)` and `etag == other` are both subtly wrong.
- **Check after the 404.** If the resource doesn't exist, return 404, not 412. The exception is `If-Match: *`, which means "only if it exists". `IsSatisfiedByIfMatch(default)` already returns false for that case. This matters only when you check before loading.
- **Return the new tag.** After a successful write, set `Response.Headers.ETag` from the entity after `SaveChanges`. EF refreshes a `rowversion` column on save, and Cosmos returns the new `_etag`. When the endpoint returns the updated resource in the body, the body carries the new tag too.
- **Return 412 as a status code result.** The ProblemDetails middleware from `AddAmusementConnectProblemDetails` turns it into a problem details response. There is no need to build one by hand.
- **Don't pass the request's cancellation token to the save.** Data-modifying endpoints don't support cancellation (see `api-design`).
- **Deletes use the same shape:** load, return 404 if missing, check `IsSatisfiedByIfMatch`, delete, and catch the concurrency exception as 412. Return 204 with no `ETag` header, because the resource no longer exists.

When the work happens in a service class instead of the controller, pass the `ETagCondition` (or the single expected `ETag`) into the service method. Both types are in the core package, so a domain project can reference them without depending on ASP.NET Core. Report "precondition failed" back the same way the service already reports outcomes such as not found (a result type, a status enum, or a specific exception). The controller then maps that outcome to 412. Don't let `DbUpdateConcurrencyException` or `CosmosException` escape into the controller as a 500.

### GET

Return the tag in both places:

```csharp
Response.Headers.ETag = offering.ETag.ToString();
return Ok(KioskOfferingResponse.From(offering)); // the response model has an ETag property
```

List endpoints don't set the header, because no single tag describes a list. Each item's `ETag` property is enough. A client that edits an item from a list sends that item's tag in `If-Match`.

Add conditional GET (`If-None-Match` → 304 Not Modified) **only when the user asks for it**, for example to let a client cache a single resource. It adds a code path to test and document, and most endpoints don't need it. When asked, bind `[FromHeader(Name = "If-None-Match")] ETagCondition ifNoneMatch`. After loading the resource, return 304 with the `ETag` header and no body when `!ifNoneMatch.IsSatisfiedByIfNoneMatch(current.ETag)`. Use the method rather than comparing yourself, because `If-None-Match` uses the weak comparison.

### Minimal APIs

Minimal APIs bind both types through `IParsable` and don't need the model binder. But a non-nullable value-type parameter is treated as required, so a missing header returns 400. Declare the parameter as nullable to keep `If-Match` optional:

```csharp
group.MapPut("/{id}", async (int id, KioskOfferingUpdateRequest body,
    [FromHeader(Name = "If-Match")] ETagCondition? ifMatch, ...) =>
{
    ...
    if (!(ifMatch ?? default).IsSatisfiedByIfMatch(offering.ETag))
    {
        return Results.StatusCode(StatusCodes.Status412PreconditionFailed);
    }
    ...
});
```

## OpenAPI

Keep the spec in sync with the endpoint (see `api-design`). For each endpoint that uses ETags, document the following:

- **GET single resource:** an `ETag` response header on 200, plus an `eTag` property on the response schema (`type: string`, `readOnly: true`, with a description that says to send it back in `If-Match`). The property name is camelCase because of the JSON naming policy.
- **Update and delete:** an optional `If-Match` header parameter (`in: header`, `required: false`, `schema: {type: string}`), a `412` response, and an `ETag` response header on success responses that have one.
- **Conditional GET (only if added):** an optional `If-None-Match` header parameter and a `304` response.

Define the headers and the 412 response once under `components` (`parameters`, `headers`, `responses`) and `$ref` them, so every endpoint describes them the same way. If the spec already defines them, reuse those definitions.

## Testing

- Test the decision logic (404 vs 412 vs success) with the If-Match header present and matching, present and stale, absent, and `*`. Build `ETag` values directly (`new ETag("0000000000000FA1")`) instead of reading them from a database.
- The store-level conflict path is the part that most often breaks silently. Cover it with an integration test against a real store: Testcontainers MsSql for SQL, or the Cosmos emulator or a test account. Read the row twice, update through the first copy, then update through the second copy and assert 412. The EF in-memory provider does not enforce `rowversion`, so a test that uses it proves nothing about concurrency.
- See the `csharp-testing` skill for the test stack and naming.

## Common mistakes

| Mistake | Why it's wrong |
| --- | --- |
| Comparing the header string to `etag.Value` | `Value` has no quotes and no `W/`. The header form is `ToString()`. Comparing strings also skips the weak/strong rules. Parse and use `IsSatisfiedByIfMatch`. |
| Writing `"\"" + etag + "\""` | `ETag.ToString()` already produces the quoted header form. |
| A weak tag (`W/"..."`) from a `rowversion` or `_etag` | Both identify the exact bytes stored, so they are strong. A weak tag never satisfies `If-Match`, and the client could never write. |
| Checking `If-Match` but catching nothing on save | Two concurrent requests both pass the check, and the second silently overwrites the first. |
| Catching the conflict on save but ignoring `If-Match` | It only catches races inside your own request. A client with a day-old copy overwrites newer data. |
| A non-nullable `ETagCondition` in a minimal API | A missing header becomes a 400, so `If-Match` is accidentally required. |
| `using AmusementConnect.Http;` together with `using Azure;` | `ETag` is ambiguous. Add a using alias. |

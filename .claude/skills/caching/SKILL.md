---
name: caching
description: |
  Amusement Connect conventions for caching using the shared AmusementConnect.Caching library (HybridCache backed by a shared Azure Managed Redis instance). Use this skill when wiring up AddAmusementConnectCaching/WithRedis in Program.cs, injecting HybridCache, caching a lookup or computed result, implementing idempotency-key request replay, invalidating a cache entry or tag, choosing a cache key or TTL, or writing tests around cached behavior.
  Triggers on phrases like "cache this", "add caching", "cache the result", "idempotency key", "invalidate the cache", "HybridCache", "how do we name this cache key", "cache TTL/expiration", and similar. Also trigger automatically when opening a .cs file that references HybridCache or AmusementConnect.Caching.
---

# Caching

Conventions for caching at Amusement Connect using the shared `AmusementConnect.Caching` library. The library is a thin DI bootstrapper — it doesn't ship its own cache interface. It registers and configures Microsoft's `HybridCache` (in-process L1 + Redis L2 via `IDistributedCache`), and consuming code injects `HybridCache` directly. There is no `ICache`/`ICacheService` wrapper to look for.

## DI setup

Bind `AmusementConnectCacheOptions` from a `"Caching"` config section, call `AddAmusementConnectCaching(...)`, then `WithRedis(connectionString)`. Require the Redis connection string outside Development — allow Development to fall back to an in-memory-only `HybridCache` when it's absent, which is convenient for local runs and tests that don't need a real Redis:

```csharp
var cacheOptions = services.AddOptions<AmusementConnectCacheOptions>()
    .BindConfiguration(AmusementConnectCacheOptions.SectionName); // "Caching"

var caching = services.AddAmusementConnectCaching(cacheOptions);

var redisConnectionString = builder.Configuration.GetConnectionString("Redis");
if (redisConnectionString is not null)
{
    caching.WithRedis(redisConnectionString);
}
else if (!builder.Environment.IsDevelopment())
{
    throw new MissingAppSettingException("ConnectionStrings:Redis");
}
```

Register this identically in both the Web API and the Functions host — both processes need their own `HybridCache` registration. Factor it into a shared `AddXServiceCaching(...)` extension in the domain project (as wallet-service does) rather than duplicating the block inline in each `Program.cs`.

`WithRedis` auto-detects Azure Managed Redis by hostname (`*.redis.azure.net`) and switches to token-credential/managed-identity auth automatically — you don't need to branch on environment for that. AC services share one Azure Managed Redis instance per stamp, provisioned centrally in `azure-shared-infrastructure`: `amr-ac-shared-<env>-<region><stamp>` in the stamp's shared resource group, `rg-shared-<env>-<region><stamp>`. A stamp with the full AC deploy gets it from `azuredeploy_shared.bicep` (az1a). A stamp without it yet gets only the Redis, from `azuredeploy_redis.bicep` (az2a). Both use `modules/redis/redis.bicep`. Always use the instance in the same stamp as the application that uses it. A cache exists to be fast, and a cross-region call adds tens of milliseconds to every operation, more than the read it saves. If no shared Redis exists yet in the application's stamp, deploy one there with `azuredeploy_redis.bicep`; don't point the service at another region's instance. A service's Bicep only references it as an `existing` resource, deriving the name and resource group from the service's own region and stamp, and grants its own managed identity access via an `accessPolicyAssignment`; it never provisions Redis itself.

Only register the caching DI wiring if something actually needs `HybridCache` in the container — but that "something" isn't always your own code's direct `Publish`/`GetOrCreateAsync` call. Some shared libraries register services with a hard, unenforced dependency on `HybridCache` being present. For example, `AmusementConnect.Azure.Devices`'s `AddIotHubServices(...)` registers `DeviceConnectionService` and a `DeviceConnectionCircuitHealthCheck` that both take `HybridCache` as a required constructor parameter — it never registers `HybridCache` itself, so any service that calls `AddIotHubServices` (e.g. asset-service and device-service, for IoT Hub device connections) must also call `AddAmusementConnectCaching(...).WithRedis(...)`, even if that service's own code never touches the cache directly. Before assuming a caching registration with no local call site is unused, check whether another registered library depends on `HybridCache` being available.

### Options

`AmusementConnectCacheOptions` (section `"Caching"`) controls library-wide defaults — leave these at their defaults unless you have a specific reason to change them for the whole service:

| Setting | Default | Meaning |
|---|---|---|
| `InstanceName` | `null` | Redis key prefix; set this if you deliberately want to isolate or share a namespace across services on the shared Redis instance. |
| `DefaultExpiration` | 10 minutes | L2 (Redis) TTL applied when a call site doesn't override it. |
| `DefaultLocalCacheExpiration` | 1 minute | L1 (in-process) TTL. |
| `MaximumPayloadBytes` | 1 MiB | Cap on serialized entry size. |
| `MaximumKeyLength` | 1024 | Cap on key length. |

Per-feature TTLs belong in your own `Options` class bound from your own config section (e.g. `CacheOptions`/`"Cache"`, or a feature-specific `ReaderThemeCacheOptions`/`"ReaderThemeCache"`) — don't repurpose the library's `"Caching"` section for feature-specific tuning. Bind it as `IOptionsSnapshot<T>` so a TTL change via App Configuration takes effect without a redeploy, and pass the resolved `TimeSpan` into `HybridCacheEntryOptions.Expiration` explicitly at each call site — don't hardcode a TTL number inline unless the value is tied to a business rule rather than a perf/tuning knob (see the idempotency pattern below, which does hardcode intentionally).

## Cache key conventions

The library provides no key-builder helper. The convention in practice is a URI-like scheme:

```
<service-name>://<entity-type>/<entity-id>[/<sub-resource>[/<sub-id>]]
```

```csharp
private static string GetCacheKey(LocationIdentity locationId) => $"wallet-service://location/{locationId}";
```

For per-user idempotency keys, scope the client-supplied idempotency key with the user ID so it can't collide across users:

```
wallet-service://gameplay/{userId}/{idempotencyKey}
```

**Always build the key in exactly one place per resource type** (a private method or const), and reuse it for every read, write, and invalidation call site for that resource. Don't re-type the interpolated string at each call site — a key built one way at write time and a slightly different way at invalidation time (e.g. one includes the `<service>://` scheme prefix and the other doesn't) silently breaks invalidation with no error, since `RemoveAsync` on a nonexistent key is a no-op.

Global/shared (non-per-entity) caches can use a plain constant instead of an interpolated method:

```csharp
public const string ReaderThemeCacheKey = "device://reader-themes";
```

## Usage patterns

Inject `HybridCache` directly — there's no AC-specific wrapper.

### Lookup / entity caching, with tag-based invalidation

Tag every entry of a given entity type so it can be bulk-invalidated later, and explicitly remove (don't just let it expire) when you know the underlying data changed:

```csharp
private static readonly string CacheTag = "location";
private HybridCacheEntryOptions CacheOptions => new() { Expiration = _cacheOptions.Value.LocationCacheDuration };

public async Task<Location?> GetLocation(LocationIdentity locationId, CancellationToken cancellationToken)
{
    var location = await _cache.GetOrCreateAsync(
        GetCacheKey(locationId),
        locationId,
        async (id, ct) => await _locationRepository.GetLocation(id, ct),
        CacheOptions,
        [CacheTag],
        cancellationToken
    );

    if (location is null)
    {
        // Don't let a not-found result linger — explicitly evict rather than caching the miss.
        await _cache.RemoveAsync(GetCacheKey(locationId), cancellationToken);
    }
    return location;
}

public Task InvalidateLocation(LocationIdentity locationId, CancellationToken ct) =>
    _cache.RemoveAsync(GetCacheKey(locationId), ct).AsTask();

public Task InvalidateAllLocations(CancellationToken ct) =>
    _cache.RemoveByTagAsync(CacheTag, ct).AsTask();
```

### Computed result with write-through invalidation

When the cache fronts data your own service also writes, invalidate the tag immediately after a successful write rather than trying to update the cached value in place — this is the cleanest pattern for a cache backed by mutable data:

```csharp
private const string CacheKey = "wallet-service://player-connect/surcharge-rates";
private const string CacheTag = "surcharge-rates";

public Task<Rates?> GetAsync(CancellationToken ct) =>
    _cache.GetOrCreateAsync(
        CacheKey,
        ct => new ValueTask<Rates?>(_repository.GetAsync(ct)),
        new HybridCacheEntryOptions { Expiration = _cacheOptions.Value.RatesCacheDuration },
        [CacheTag],
        ct
    ).AsTask();

public async Task<Rates> UpsertAsync(Rates rates, CancellationToken ct)
{
    var result = await _repository.UpsertAsync(rates, ct);
    await _cache.RemoveByTagAsync(CacheTag, ct);
    return result;
}
```

### Idempotency-key request replay

For POST endpoints that accept a client-supplied idempotency key, cache a small envelope tracking whether the request is in-flight or completed, so a retried request with the same key replays the original result instead of re-executing:

```csharp
private static readonly HybridCacheEntryOptions IdempotencyCacheOptions = new()
{
    Expiration = TimeSpan.FromMinutes(10)
};

public class CachedRequest<TResponse>
{
    public TResponse? Response { get; set; }
    public DateTime? StartedAt { get; set; }
}

var cacheKey = $"wallet-service://widget/{User.GetUserId()}/{request.IdempotencyKey}";
var cached = request.IdempotencyKey is not null
    ? await _cache.GetOrCreateAsync(cacheKey, _ => ValueTask.FromResult(new CachedRequest<WidgetResponse>()), cancellationToken: ct)
    : null;

if (cached is { Response: { } response })
{
    return response; // already completed once with this key — replay it
}
if (cached is { StartedAt: not null, Response: null })
{
    Response.Headers.RetryAfter = "3";
    return Accepted(); // same key is in flight — ask the client to retry
}

if (cached is not null)
{
    cached.StartedAt = DateTime.UtcNow;
    await _cache.SetAsync(cacheKey, cached, IdempotencyCacheOptions, cancellationToken: ct);
}

try
{
    var result = await DoTheActualWork();
    if (cached is not null)
    {
        cached.Response = result;
        await _cache.SetAsync(cacheKey, cached, IdempotencyCacheOptions, ["WidgetRequest"], CancellationToken.None);
    }
    return result;
}
catch
{
    if (cached is not null)
    {
        // Don't poison the idempotency key on failure — clear it so a legitimate retry can proceed.
        await _cache.RemoveAsync(cacheKey, CancellationToken.None);
    }
    throw;
}
```

The 10-minute window is hardcoded per call site rather than config-driven, since it's tied to the request's business meaning ("how long is a retry still the same logical request"), not a perf-tuning knob. This pattern is currently duplicated across several controllers rather than factored into a shared helper — follow the pattern as shown above for consistency, but a shared helper is a reasonable improvement if you're touching several of these at once.

### Third-party token caching with proactive refresh

Cache an externally-issued token with its own TTL, but check the token's actual expiry before use and refresh if it's stale rather than relying solely on the cache TTL. Invalidate immediately if the downstream call comes back unauthorized:

```csharp
var cached = await _cache.GetOrCreateAsync(cacheKey,
    async ct => await _authClient.RequestToken(ct),
    new HybridCacheEntryOptions { Expiration = TimeSpan.FromHours(12) },
    ["GoTab"], cancellationToken);

if (TokenExpiry(cached) <= DateTime.UtcNow)
{
    await _cache.RemoveAsync(cacheKey);
    cached = await _authClient.RefreshToken(cached.RefreshToken, cancellationToken);
    await _cache.SetAsync(cacheKey, cached, cacheOptions, ["GoTab"], cancellationToken);
}
```

```csharp
// on a 401 from the downstream API
await _goTabTokenProvider.InvalidateTokenCache(locationId, cancellationToken);
```

### Cache as a short-lived lock / cooldown gate

`HybridCache` entries are also used as a lightweight distributed marker — not caching a lookup at all, just recording "this happened recently" to gate a rate-limited action:

```csharp
private string CacheKey => $"wallet-service://game-machine/{_gameMachine.Id}/no-cost-gameplay-lock";
private HybridCacheEntryOptions CacheOptions => new()
{
    Expiration = _gameplayOptions.Value.NoCostGameplayCooldown * 1.5 // buffer so the lock outlives the cooldown window
};

var lastPlayed = await _cache.GetOrCreateAsync(CacheKey, GetDefaultLock, CacheOptions, cancellationToken: ct);
```

## Kill switch for troubleshooting

Wiring a feature-specific TTL as `TimeSpan? CacheDuration` and treating a zero/negative value as "bypass the cache entirely" gives ops a config-only way to disable a specific cache without a deploy:

```csharp
if (_cacheOptions.Value.CacheDuration <= TimeSpan.Zero)
{
    return await _repository.GetDirectly(cancellationToken);
}
```

## Error handling

The library adds no resiliency policy of its own — no retry, no circuit breaker, no fail-open behavior. A Redis outage propagates as an exception out of `HybridCache` calls (effectively fail-closed) unless the calling code handles it. Decide deliberately per call site whether a cache failure should fail the request or fall back to the source of truth; don't assume either behavior is automatic.

## Testing

There's no cache fake shipped by the shared library, so hand-roll a minimal `HybridCache` subclass in your test project (backed by an in-memory dictionary, honoring tags) and inject it directly — `HybridCache` is a concrete class with several members to override, so a from-scratch mock is impractical. A partial implementation that only backs `GetOrCreateAsync`/`SetAsync`/`RemoveAsync`/`RemoveByTagAsync` with a `ConcurrentDictionary` (skipping real L1/L2 separation and real expiration) is sufficient for verifying call patterns:

```csharp
public sealed class HybridCacheFixture : HybridCache
{
    private readonly ConcurrentDictionary<string, object?> _values = new();
    private readonly ConcurrentDictionary<string, HashSet<string>> _taggedKeys = new();

    public override async ValueTask<T> GetOrCreateAsync<TState, T>(string key, TState state,
        Func<TState, CancellationToken, ValueTask<T>> factory,
        HybridCacheEntryOptions? options = null, IEnumerable<string>? tags = null,
        CancellationToken cancellationToken = default)
    {
        if (_values.TryGetValue(key, out var val) && val is T typed) return typed;
        var created = await factory(state, cancellationToken);
        _values[key] = created;
        return created;
    }
    // Override SetAsync/RemoveAsync/RemoveByTagAsync similarly.
}
```

Use it to test:
- That a second call within the TTL doesn't re-hit the repository (verify the mocked repository was called `Times.Once`).
- Cooldown/lock behavior across two calls with a controlled `TimeProvider`.
- That a write-through invalidation (`UpsertAsync` → `RemoveByTagAsync`) actually clears the tag so the next read repopulates.

Controller-level idempotency-replay logic (the pattern above) is easy to leave untested since it lives inline in the controller action — if you're adding a new one, add a test for at least the replay and in-flight-retry branches, not just the happy path.

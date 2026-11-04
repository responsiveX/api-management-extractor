---
name: dotnet-date-time-handling
description: 'Use BEFORE writing or editing any C# that touches a date, time, timestamp, duration or time zone, and do not skip it because the change is a single field. Adding or typing such a property, field, parameter or column; reading the current time; scheduling future or recurring work; converting between zones; writing or reading a test whose outcome depends on the clock; reviewing anything that calls DateTime.Now, ToUniversalTime or FindSystemTimeZoneById. Covers choosing among DateTimeOffset, DateTime, DateOnly, TimeOnly, TimeSpan and TimeZoneInfo; TimeProvider and FakeTimeProvider instead of static clocks; IANA vs Windows time zone ids across Windows/Linux/containers (ICU, InvariantGlobalization, tzdata); storing instants vs future wall-clock times; EF Core and database column mapping; JSON serialization; DST-safe arithmetic. What to name these members: dotnet-naming-conventions.'
---

# Dates, Times, and Time Zones in .NET

Most date bugs are one of three mistakes: storing a `DateTime` whose kind nobody tracked,
reading the clock from a static, or treating "the same wall-clock time" and "the same instant"
as interchangeable. The rules below make each one unrepresentable.

**Precedence:** where this skill and an Amusement Connect skill (`csharp-code-style`, `csharp-testing`, `dotnet-patterns`, `caching`, `cosmos-documents`, `service-bus`, `api-design`, `etags`) disagree, the Amusement Connect skill wins.

## Existing conventions win

**These conventions govern new code and new solutions.** Where a codebase is already
internally consistent with a different choice, match what is there — do not convert it in
passing. Several rules below deliberately depart from a common default; applying one to
half a codebase is worse than either convention applied consistently, and a diff that
retypes timestamps nobody asked about is a diff nobody can review. Propose a migration as
its own change and let the owner decide.

**Edit first, then say so.** Matching a local convention is still an implementation task.
Write the member into the file with the matched type on it, and *then* close the turn with
the note below. The note never substitutes for the edit.

**The note goes in the message that ends the turn** — not an earlier turn, and not a code
comment — and fills in this shape:

> Typed it `<the type you chose>` to match `<the local convention>`: `<the surrounding
> declarations that evidence it>`. This skill would have used `<the counterfactual type>` —
> `<the rule, in a clause>` — but one codebase holding both conventions is worse than
> either. Converting `<the codebase>` is a separate change.

Filled in, for a solution that stores every instant as a UTC `DateTime` behind a value
converter:

> Typed it `DateTime?` to match the local UTC-`DateTime` convention: `RaisedUtc`, `PaidUtc`,
> `CapturedUtc` and `SettledUtc` all carry it, and `UtcDateTimeConverter` is applied to every
> `DateTime` in `ConfigureConventions`. This skill would have used `DateTimeOffset` — an
> instant carries its own offset, where a `DateTime` needs a converter to be unambiguous —
> but one codebase holding both conventions is worse than either. Converting `Acme.Payments`
> is a separate change.

**Name the counterfactual — it is the clause that gets dropped.** "Matches the existing
convention" on its own is *not* the note: it leaves the reader unable to tell whether you
knew the rule and yielded to it or never knew it, which is the whole thing the note exists
to settle. Use the types and names in front of you, not the example's.

## Say what the rule prevents

Several rules here cost a step whose purpose is invisible in the diff — the `HasIanaId` check
before a zone id is stored, the zone id kept beside a future wall-clock time,
`TryFindSystemTimeZoneById` over `FindSystemTimeZoneById`. A reader who cannot see what breaks
without that step reads it as ceremony and deletes it later.

**When you apply one, name the failure it avoids in the message that ends the turn** — the
concrete broken outcome, not the rule's name:

> Normalized to IANA with `HasIanaId` / `TryConvertWindowsIdToIanaId` before storing:
> `TimeZoneInfo.Id` returns the host's native format, so this column would otherwise collect
> `Central Standard Time` from a Windows dev box and `America/Chicago` from a Linux container.

"Follows the skill", "uses the recommended API", and "stores an IANA id" are not that
sentence. The failure itself has to appear in it.

For what to *name* these members — tense, the `Utc` / `Local` suffixes, `TimeZoneId` — see the
dotnet-naming-conventions skill.

## Start here

| Doing this | Read |
|---|---|
| Adding a timestamp or date field | [Pick the type](#pick-the-type) |
| Reading the current time | [The clock is a dependency](#the-clock-is-a-dependency) |
| Writing a test that depends on time | [Testing with FakeTimeProvider](#testing-with-faketimeprovider) |
| Handling a time zone id | [Time zone ids](#time-zone-ids) |
| Debugging `TimeZoneNotFoundException` | [Container and platform failures](#container-and-platform-failures) |
| Choosing a database column | [Storing](#storing) |
| Serializing to JSON or a wire format | [Serializing](#serializing) |
| Adding days/months, or crossing a DST boundary | [DST-safe arithmetic](#dst-safe-arithmetic) |
| Scheduling future work | [Storing](#storing), [DST-safe arithmetic](#dst-safe-arithmetic) |
| Reviewing a diff | [Review checklist](#review-checklist) |
| Working in an existing codebase | [Existing conventions win](#existing-conventions-win) |
| Closing the turn on any of these | [Say what the rule prevents](#say-what-the-rule-prevents) |

## Pick the type

| Use | Type | Why |
|---|---|---|
| A point in time | `DateTimeOffset` | Carries its offset, so it identifies one instant unambiguously |
| A calendar date with no time | `DateOnly` | Birthdays, invoice dates — a date is not midnight |
| A wall-clock time with no date | `TimeOnly` | Opening hours, alarms, schedules |
| An elapsed amount | `TimeSpan` | Timeouts, delays, durations |
| A zone and its rules | `TimeZoneInfo` | Conversions and DST rules |
| Interop with an API that demands it | `DateTime` | Only where something else forces it |

- **`DateTimeOffset` is the default for an instant.** `DateTime` carries a `Kind` — `Utc`,
  `Local`, `Unspecified` — that is **not preserved** through JSON, most database round-trips,
  or `default(DateTime)`. Kind is the bug surface; an offset in the value itself isn't.
- **A `DateTimeOffset` is not a time zone.** It stores an offset (`-05:00`), which tells you
  what the clock read but not which zone produced it, and not what the offset will be six
  months from now. When the zone matters, carry the IANA id alongside the value.
- **`DateOnly` is not `DateTime` at midnight.** A birthday stored as midnight local time shifts
  by a day the first time someone converts it to UTC.

## The clock is a dependency

**Never call `DateTime.Now`, `DateTime.UtcNow`, or `DateTimeOffset.UtcNow`** in code you intend
to test. Inject [`TimeProvider`](https://learn.microsoft.com/dotnet/standard/datetime/timeprovider-overview)
and call `GetUtcNow()`.

```csharp
public sealed class TokenIssuer(TimeProvider timeProvider)
{
    public Token Issue() => new(expires: timeProvider.GetUtcNow().AddMinutes(20));
}
```

- Register `TimeProvider.System` as a singleton in production wiring.
- `TimeProvider` is in the framework from **.NET 8**; `Microsoft.Bcl.TimeProvider` backports it
  to .NET Standard 2.0 and .NET Framework 4.6.2+.
- It also supplies `GetTimestamp()` / `GetElapsedTime()` for measurement, `CreateTimer()`, and
  a settable `LocalTimeZone` — which is how you test zone-dependent logic without touching the
  machine's zone.
- `Task.Delay` and `CancellationTokenSource` take a `TimeProvider` overload, so a test can
  advance past a timeout instantly instead of sleeping through it.

### Testing with `FakeTimeProvider`

From `Microsoft.Extensions.TimeProvider.Testing`:

```csharp
var time = new FakeTimeProvider(new DateTimeOffset(2026, 3, 8, 1, 30, 0, TimeSpan.Zero));
var issuer = new TokenIssuer(time);

var token = issuer.Issue();
time.Advance(TimeSpan.FromMinutes(21));

Assert.True(token.HasExpired(time.GetUtcNow()));
```

- `Advance` moves time deterministically — this is what makes DST transitions, month
  boundaries, and leap days testable at all.
- **Seed the clock at a transition moment deliberately** when testing zone logic. The value
  above is inside the US spring-forward window.
- **Never mix `FakeTimeProvider` and `TimeProvider.System` in one test.**

## Run servers in UTC

Set the container and host time zone to UTC. **Never call `DateTime.Now`, `DateTimeOffset.Now`,
`TimeZoneInfo.Local`, or `ToLocalTime()` in server code.** "Local" on a server means local to
whichever machine happens to be running the process.

Convert to a *user's* zone at the presentation edge, using a zone id you stored deliberately.

## Time zone ids

There are exactly two formats. Linux is not a third one.

| Platform | Format | Example |
|---|---|---|
| Linux, macOS, iOS, Android, browsers, Postgres, Java | IANA (tzdata / zoneinfo) | `America/Chicago` |
| Windows | Windows registry ids | `Central Standard Time` |

IANA is the shared standard; Linux ships it under `/usr/share/zoneinfo/`. Windows maintains its
own coarser list — a few hundred canonical IANA zones collapse onto roughly 140 Windows zones.
The mapping between them lives in Unicode CLDR's `windowsZones.xml`, which ICU consumes, which
.NET consumes.

**Standardize on IANA.** It's what every client platform sends, what Postgres stores, and the
finer-grained of the two, so it loses nothing.

| Task | API | Notes |
|---|---|---|
| Resolve an id | `FindSystemTimeZoneById` | .NET 6+: accepts *either* format on *any* platform |
| Resolve untrusted input | `TryFindSystemTimeZoneById` | .NET 8+ — use this for anything from a client, config, or database |
| Check which format an instance carries | `TimeZoneInfo.HasIanaId` | |
| Convert at a boundary | `TryConvertIanaIdToWindowsId`, `TryConvertWindowsIdToIanaId` | .NET 6+, ICU required |

- **Treat an incoming zone id as user input.** Map a miss to a 400, not to an unhandled
  `TimeZoneNotFoundException` in a request pipeline:

  ```csharp
  if (!TimeZoneInfo.TryFindSystemTimeZoneById(request.TimeZoneId, out var zone))
      return TypedResults.ValidationProblem(/* … */);
  ```

- **`TimeZoneInfo.Id` returns the host's native format.** Persisting it directly writes
  `Central Standard Time` from a Windows dev box and `America/Chicago` from a Linux container
  into the same column. Normalize before storing.
- **Convert once, at the edge — never round-trip through Windows ids for storage.** The mapping
  is lossy both directions: many IANA zones share one Windows zone, and coming back yields a
  representative zone for a region (hence the ISO 3166 region-code overload on
  `TryConvertWindowsIdToIanaId`).

### Container and platform failures

Both of these **pass locally and fail in production**, because what's missing is present by
default on a desktop OS and absent from a slim image.

| Symptom | Cause | Fix |
|---|---|---|
| `TimeZoneNotFoundException` for non-UTC zones only | Alpine/distroless base has no `/usr/share/zoneinfo` | `apk add --no-cache tzdata` |
| Cross-format conversion fails; non-UTC lookups fail outright | `<InvariantGlobalization>true</InvariantGlobalization>`, or NLS mode on Windows — ICU unavailable | Remove the property, or don't rely on zone lookup |

Check the csproj before relying on any cross-format behavior.

### If the OS dependency is unacceptable

[NodaTime](https://nodatime.org) bundles the tz database: `DateTimeZoneProviders.Tzdb` behaves
identically on every platform, and tzdata updates arrive as a NuGet bump rather than a
base-image rebuild. It also makes the instant/wall-clock distinction explicit in the type
system (`Instant`, `LocalDateTime`, `ZonedDateTime`).

Worth it for scheduling-heavy domains; overkill for an app that only stamps rows with "when did
this happen."

## Storing

| What | Store | Why |
|---|---|---|
| Past and present instants | The UTC instant — `datetimeoffset` (SQL Server), `timestamptz` (Postgres), or a normalized UTC value | The event happened; its instant will never change |
| Future wall-clock times | `(LocalDateTime, TimeZoneId)` — **not** a precomputed instant | Governments change DST rules; tzdata ships several updates a year. A meeting booked for next March can drift by an hour before it arrives |

Resolve a future wall-clock value to an instant when you read, schedule, or notify — the
instant is derived, and deriving it early is the bug.

**Database specifics:**

- **Postgres `timestamptz` does not store a zone** — it normalizes to UTC on write. Npgsql 6+
  requires a `DateTime` with `Kind == Utc` (or a `DateTimeOffset` with zero offset), and throws
  rather than guessing.
- **SQL Server `datetime2` has no offset**; `datetimeoffset` does. Mapping a `DateTimeOffset` to
  `datetime2` **silently** discards the offset.
- **In EF Core, a `DateTime` from a provider that doesn't carry kind comes back `Unspecified`.**
  If you must store `DateTime`, add a value converter that stamps `Utc` on materialization
  rather than trusting the round-trip.

## Serializing

- **Use ISO 8601 and let the framework do it.** `System.Text.Json` handles `DateTime` and
  `DateTimeOffset` natively in the round-trippable format, and `DateOnly` / `TimeOnly` since
  **.NET 7**. On .NET 6 those two need a hand-written `JsonConverter`.
- **When formatting by hand, use `"O"` (round-trip)** — the only specifier that preserves offset
  and sub-second precision. `ToString()` without a specifier is culture-dependent and lossy.
- **Never send a bare `DateTime` across a wire and expect the kind to survive.** It won't.

## DST-safe arithmetic

**Adding to an instant is not the same as adding to a wall clock.** `instant.AddDays(1)` adds
exactly 24 hours; across a DST boundary that is a different wall-clock time than "same time
tomorrow."

**First decide whether you owe an instant at all.** Two rules meet here, and what the caller
does with the result picks the one that applies:

| The result is | Do this |
|---|---|
| Dispatched now, or soon enough that tzdata cannot ship an update first | Rebuild the instant here, with the pattern below |
| Stored and fired later — an appointment, a booking, a recurrence months out | Store `(LocalDateTime, TimeZoneId)` and derive the instant at read time — see [Storing](#storing) |

"The next run tomorrow" is the first: no tzdata update lands inside that window, and the
caller needs an instant to schedule against. "An appointment next March" is the second.
Returning a wall-clock pair where the caller asked for the next firing time answers a
different question.

For calendar arithmetic, convert into the zone, do the arithmetic on the local value, convert
back:

```csharp
var local = TimeZoneInfo.ConvertTime(instant, zone);
var nextLocal = local.DateTime.AddDays(1);              // wall-clock arithmetic
var next = new DateTimeOffset(nextLocal, zone.GetUtcOffset(nextLocal));
```

**Handle both transition cases explicitly** — spring forward deletes an hour, fall back repeats
one, so a local time can be invalid or ambiguous:

| Case | Check | Policy |
|---|---|---|
| The wall-clock time never happened | `TimeZoneInfo.IsInvalidTime` | Decide one (shift forward, reject) rather than letting a conversion throw |
| It happened twice | `TimeZoneInfo.IsAmbiguousTime` | `GetAmbiguousTimeOffsets` gives both; convention is the earlier, still-daylight one |

- **Compare instants, not `DateTime` values of mixed kind.** `DateTime` comparison ignores
  `Kind` entirely, so a `Utc` value and a `Local` value comparing equal means nothing.
  `DateTimeOffset` comparison uses the underlying instant.
- **A day is not always 24 hours, a year is not always 365 days**, and a minute is occasionally
  61 seconds (leap seconds are smeared by most clock sources, not represented). Express business
  rules in calendar terms and let the zone resolve them.

## Review checklist

Reject a change that does any of these:

- [ ] Calls `DateTime.Now`, `DateTime.UtcNow`, `DateTimeOffset.UtcNow`, or `TimeZoneInfo.Local`
      anywhere but production wiring.
- [ ] Calls `ToLocalTime()` in server code.
- [ ] Uses `DateTime` where the value is an instant — should be `DateTimeOffset`.
- [ ] Uses `DateTime` at midnight standing in for a date — should be `DateOnly`.
- [ ] Stores a zone id taken from `TimeZoneInfo.Id` without a `HasIanaId` check.
- [ ] Stores a future-dated event as a computed UTC instant with no zone id.
- [ ] Round-trips through Windows time zone ids for storage.
- [ ] Resolves an incoming zone id with `FindSystemTimeZoneById` instead of
      `TryFindSystemTimeZoneById`.
- [ ] Calls `.AddDays` / `.AddMonths` on an instant where wall-clock semantics were meant.
- [ ] Converts a local time without checking `IsInvalidTime` / `IsAmbiguousTime`.
- [ ] Compares `DateTime` values of mixed `Kind`.
- [ ] Mixes `FakeTimeProvider` and `TimeProvider.System` in one test.
- [ ] Sets `<InvariantGlobalization>true</InvariantGlobalization>` in a project that resolves
      zones.
- [ ] Ships an Alpine or distroless image with no `tzdata`.
- [ ] Maps a `DateTimeOffset` to a SQL Server `datetime2` column.

## Before you end the turn

**If the prompt asked for code — *add*, *write*, *rename*, *create* — the file must be edited
before you answer.** Naming the member, writing its signature in the reply, or explaining what
the right shape would be is not the change. The workspace is what the next person gets, and an
unedited workspace means the task is not done however correct the analysis above it.

Re-read the verb in the prompt. If it was *add*, something must have been written. "No changes
needed" answers a question nobody asked when the prompt named a file and told you to add to it.

The checklist above is for reviewing a diff someone else wrote — that is the one case where the
finding *is* the deliverable. It is not a substitute for work you were asked to do.

# SQL Server rowversion as the ETag

This file covers resources stored in SQL Server through EF Core. Read `SKILL.md` first for the HTTP side.

A `rowversion` column is an 8-byte value that SQL Server changes on every update of the row. `RowVersionETagConverter` exposes it as a strong `ETag` whose value is the hex encoding (`"0000000000000FA1"`).

## Entity

Type the property as `ETag`, not `byte[]`:

```csharp
using AmusementConnect.Http;

[Table("KioskOffering")]
public class KioskOffering
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public ETag ETag { get; set; }
}
```

Don't assign `ETag` in application code. The database owns it. EF leaves it out of inserts and updates, and reads the new value back after `SaveChanges`.

## DbContext

Register the converter once for every `ETag` property, then mark each `ETag` property as the row version:

```csharp
protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
{
    configurationBuilder.Properties<ETag>()
        .HaveConversion<RowVersionETagConverter>()
        .HaveColumnType("rowversion");
}

protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<KioskOffering>()
        .Property(e => e.ETag)
        .IsRowVersion();
}
```

Both parts are needed. The convention only sets the conversion and the column type. `.IsRowVersion()` makes the column a store-generated concurrency token. Without it, EF neither puts the value in the `WHERE` clause of updates nor reads it back. Concurrency then silently stops working, and the tag in the response goes stale.

If the context uses `IEntityTypeConfiguration<T>` classes, put `.IsRowVersion()` in the entity's configuration class, as for any other property.

## Existing column or new column

- **The table already has a `rowversion` column**, for example `RowVersion` or `Version`, possibly scaffolded as `byte[]`. Change the property to `ETag`. Keep the database column name with `HasColumnName("RowVersion")`, or rename the property to match the column. No migration is needed, because the column type doesn't change.
- **The table has no `rowversion` column.** Add the property and create a migration. Adding a `rowversion` column to an existing table is safe: SQL Server fills it for existing rows. If the service's schema is owned by a database project or by scripts rather than EF migrations, add the column there instead (`[RowVersion] rowversion NOT NULL`). Ask the user which approach the service uses, if it isn't obvious from the repository.

A table can have only one `rowversion` column.

## The write

The pattern in `SKILL.md` is enough: load the entity, check `IsSatisfiedByIfMatch`, modify the entity, call `SaveChanges`, and catch `DbUpdateConcurrencyException` as 412. EF's `UPDATE ... WHERE [RowVersion] = @original` uses the value it loaded. So the catch covers a write that happens between your load and your save.

Shortcut: when `If-Match` holds exactly one tag, you can let SQL do the comparison by setting the original value to the client's tag. Then a stale client fails at `SaveChanges` without an explicit check:

```csharp
if (ifMatch.Tags.Count == 1)
{
    _db.Entry(offering).Property(x => x.ETag).OriginalValue = ifMatch.Tags[0];
}
```

Use this only together with the explicit `IsSatisfiedByIfMatch` check, which still handles `*`, lists, and weak tags. Most endpoints don't need the shortcut.

## Updates without loading the entity

`ExecuteUpdateAsync` and `ExecuteDeleteAsync` skip change tracking, so EF does not check concurrency for them. Add the tag to the filter yourself, and treat zero affected rows as a 404 or a 412. Read the row again to tell which one it is:

```csharp
var affected = await _db.KioskOffering
    .Where(x => x.Id == id && x.ETag == expected)
    .ExecuteUpdateAsync(s => s.SetProperty(x => x.Name, name), CancellationToken.None);
```

The `x.ETag == expected` comparison goes through the converter and becomes a `rowversion` comparison in SQL.

## Projections

`ETag` works in `Select` projections, so read models and list queries can include it without loading the full entity:

```csharp
.Select(x => new KioskOfferingSummary(x.Id, x.Name, x.ETag))
```

## Testing

The EF Core in-memory provider and SQLite don't behave like SQL Server `rowversion`, so they can't show that concurrency works. Use the `Testcontainers.MsSql` integration setup from the `csharp-testing` skill:

1. Create a row.
2. Load it in two separate `DbContext` instances.
3. Save a change through the first context.
4. Save through the second context, and assert `DbUpdateConcurrencyException` (or 412 at the API level).

Also assert that the `ETag` after the first save differs from the original. This catches a missing `.IsRowVersion()`.

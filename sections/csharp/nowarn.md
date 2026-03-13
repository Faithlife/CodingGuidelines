# NoWarn usage

`<NoWarn>` can be used in `Directory.Build.props` and `*.csproj` files to disable compiler and analyzer warnings, which, if you build with `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` as you should, generate build errors.

A `<NoWarn>` entry should always start with any existing settings, like so:

```xml
<NoWarn>$(NoWarn);CS1591;CS1998;CA1861;CA2007;CA5394;NU1507;NU5105</NoWarn>
```

If the need to disable a warning is particular to one or few projects but is still reasonable for others, add it to the `*.csproj` projects; otherwise add it to `Directory.Build.props`.

## Commonly disabled warnings

### [CS1591: Missing XML comment for publicly visible type or member](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/cs1591)

Missing XML comments is not considered an issue worth fixing for most projects. Better to generate partial XML documentation than none at all.

### [CS1998: This async method lacks 'await' operators](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/async-await-errors)

It is common for `Task`-returning methods to not actually do any asynchronous work, particularly when overriding methods. Removing the `async` keyword and returning `Task.FromResult` just makes the code harder to read for little benefit.

### [CA1861: Avoid constant arrays as arguments](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1861)

Moving constant arrays to static readonly fields makes the code less readable for insufficient benefit in most cases.

### [CA2007: Do not directly await a Task](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2007)

Using `ConfigureAwait` is no longer necessary to avoid deadlocks on many application platforms.

### [CA5394: Do not use insecure randomness](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5394)

Insecure randomness via `System.Random` is often perfectly reasonable, and we don't want to have to suppress the issue every time.

### [NU1507: Use package source mapping](https://learn.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1507)

Package source mapping is too hard to maintain.

### [NU5105: Package version not supported on legacy clients](https://learn.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu5105)

We are fine requiring modern NuGet clients.

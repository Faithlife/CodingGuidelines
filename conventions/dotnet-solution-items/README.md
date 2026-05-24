# dotnet-solution-items

Updates .NET solution item entries with `dotnet-solution-items`.

## Settings

- `items`: Optional sequence of repository-relative item paths to add to solutions. When present, the convention runs `dnx -y dotnet-solution-items add --force` with these paths instead of updating existing solution items. Defaults to not configured.

## Behavior

The convention requires the `dnx` command to be available. By default, it runs `dnx -y dotnet-solution-items update` so existing solution item entries are refreshed from the repository state.

When `items` is configured, the convention switches to forced add mode and passes the configured paths to `dnx -y dotnet-solution-items add --force`. This is useful when a repository should include specific files before later update-only runs keep them current.

## Examples

Update existing solution items:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-solution-items
```

Add specific items:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-solution-items
    settings:
      items:
        - README.md
        - .github/workflows/ci.yml
```

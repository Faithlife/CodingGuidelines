# dotnet-solution-items

Updates .NET solution item entries with `dotnet-solution-items`.

## Settings

- `items`: Optional sequence of repository-relative item paths to add to the solution.

## Behavior

The convention requires the `dnx` command to be available. By default, it runs `dnx -y dotnet-solution-items update` so existing solution item entries are refreshed from the repository state.

When `items` is specified, the convention runs `dnx -y dotnet-solution-items add --force` with the specified paths.

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
        - "*"
        - .github/*
        - .github/workflows/*
```

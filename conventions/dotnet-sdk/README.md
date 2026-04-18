# dotnet-sdk

This convention ensures that the repository has a `global.json` that uses the specified .NET SDK major version or later.

## Settings

- `version` (required): The .NET SDK major version. This must be either an integer or a string that parses to an integer.

Only major versions are supported.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/dotnet-sdk
  settings:
    version: 10
```

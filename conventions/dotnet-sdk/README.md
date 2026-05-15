# dotnet-sdk

Ensures the repository has a `global.json` that uses the specified .NET SDK major version or later.

## Settings

- `version`: Required .NET SDK major version.

## Behavior

The convention creates or updates `global.json` so the configured .NET SDK major version is available to the repository. Existing compatible SDK versions are preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-sdk
    settings:
      version: 10
```

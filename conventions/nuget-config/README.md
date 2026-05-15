# nuget-config

Creates or replaces the repository-root `nuget.config` from [files/nuget.config](./files/nuget.config).

## Behavior

The published `nuget.config` matches the RepoConventions version except that it omits the `protocolVersion` attribute.

If the repository already has a root `nuget.config` and it does not match exactly, the convention replaces it with the published file.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/nuget-config
```

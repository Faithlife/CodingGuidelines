# nuget-config

This [convention](https://github.com/Faithlife/RepoConventions) creates a missing root `nuget.config` from [files/nuget.config](files/nuget.config).

The published `nuget.config` matches the RepoConventions version except that it omits the `protocolVersion` attribute.

If the repository already has a root `nuget.config` and it does not match exactly, the convention writes a warning and leaves the file unchanged.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/nuget-config
```

# faithlife-dotnet-library-props

Manages shared package repository properties in `Directory.Build.props`.

## Behavior

This convention writes one managed XML property group before the closing `Project` element. Repository-specific `VersionPrefix`, `PackageValidationBaselineVersion`, `NoWarn`, `GitHubOrganization`, and `RepositoryName` properties remain outside the managed section. Nullable is enabled in the managed section, and individual projects can override it when necessary.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library-props
```

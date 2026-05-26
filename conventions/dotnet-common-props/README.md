# dotnet-common-props

Manages shared package repository properties in `Directory.Build.props` and central package management settings in `Directory.Packages.props`.

## Behavior

This convention writes one managed XML property group before the closing `Project` element in `Directory.Build.props`. Repository-specific `VersionPrefix`, `PackageValidationBaselineVersion`, `NoWarn`, `GitHubOrganization`, and `RepositoryName` properties remain outside the managed section. Nullable is enabled in the managed section, and individual projects can override it when necessary.

It also writes managed XML sections in `Directory.Packages.props` for central package management properties and shared analyzer `GlobalPackageReference` items. Repository-specific `PackageVersion` items remain outside the managed sections so libraries can own their dependency versions.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-common-props
```

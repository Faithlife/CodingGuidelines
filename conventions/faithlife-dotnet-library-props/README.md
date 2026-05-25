# faithlife-dotnet-library-props

Manages shared package repository properties in `Directory.Build.props`.

## Settings

- `version-prefix` is the package version prefix. It defaults to the existing `VersionPrefix` value when present and is required for new files.
- `package-validation-baseline-version` is the baseline used by package validation. It defaults to the existing `PackageValidationBaselineVersion` value, then to `version-prefix`.
- `nullable` is the repository nullable setting. It defaults to the existing `Nullable` value, then to `enable`. Valid values are `enable`, `disable`, `annotations`, and `warnings`.
- `package-validation` controls whether package validation properties are included. It defaults to `true`.
- `no-warn` is an optional semicolon-separated warning suppression string. It defaults to the existing `NoWarn` value when present.

## Behavior

This convention writes one managed XML property group before the closing `Project` element. Repository-specific `GitHubOrganization` and `RepositoryName` properties remain outside the managed section and are referenced by the managed package metadata properties.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library-props
    settings:
      version-prefix: 1.2.3
      package-validation-baseline-version: 1.2.0
      nullable: enable
      no-warn: $(NoWarn);1591;1998;NU1507;NU5105
```

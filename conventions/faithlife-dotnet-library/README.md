# faithlife-dotnet-library

Applies the standard conventions for Faithlife .NET library repositories.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

The convention prepares a .NET repository for Faithlife library development by enabling automatic convention application, applying shared .NET repository defaults, installing standard NuGet infrastructure, installing the Faithlife build project and workflows, applying the Faithlife MIT license, and adding common solution items.

## Settings

- `version-prefix` is forwarded to the managed `Directory.Build.props` package metadata section.
- `package-validation-baseline-version` is forwarded to the managed `Directory.Build.props` package validation section.
- `nullable` is forwarded to the managed `Directory.Build.props` nullable setting.
- `package-validation` controls whether managed package validation properties are included.
- `no-warn` is forwarded to the managed `Directory.Build.props` warning suppression setting.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library
```

# update-nuget-packages

Updates git-tracked NuGet package references, MSBuild SDK references, and local .NET tool manifest versions by replacing only version text spans in supported project and manifest files.

## Settings

- `rules`: Optional array of rule objects. Rules match package IDs and adjust update policy.

Rule properties:

- `packages`: Required string or string array of package ID patterns. Patterns support case-insensitive `*` and `?` wildcards.
- `version`: Optional string, default `update-major`. Valid policy values are `update-major`, `update-minor`, `update-patch`, and `no-update`. A specific version such as `7.0.0` updates only to that exact version. A NuGet version range such as `[7.0.0, 8.0.0)` updates only to versions inside that range.
- `include-prerelease`: Optional boolean, default `false`. When true, prerelease candidates are eligible.
- `prerelease-channel`: Optional string. When set, prerelease candidates must use the specified prerelease label.

## Behavior

The convention requires the target directory to be inside a git worktree and only edits files reported by `git ls-files`. It scans git-tracked `*.csproj`, `*.props`, `*.targets`, and any `dotnet-tools.json` file.

Package metadata is resolved from enabled NuGet package sources configured for the repository, including sources inherited from `nuget.config`. Non-HTTP package sources such as local folders are supported; because those sources use local file timestamps rather than package publish timestamps, their versions are treated as old enough for the publish-date cutoff.

Only versions published on or before the Tuesday before the last Tuesday are eligible. This gives newly published packages at least one full week before the convention can select them.

The convention leaves package reference wildcard versions, package reference version ranges, computed MSBuild expressions, and unsupported XML shapes unchanged. Same-file property expressions such as `Version="$(PackageVersion)"` are updated when the property has a single literal definition in the same file.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/update-nuget-packages
    settings:
      rules:
        - packages:
            - CommonServiceLocator
            - structuremap
            - structuremap.web
            - NEST
          version: update-minor
        - packages: FluentAssertions
          version: 7.0.0
        - packages: Microsoft.Extensions.*
          version: '[8.0.0, 9.0.0)'
        - packages: StackExchange.Redis
          include-prerelease: true
          prerelease-channel: faithlife
```

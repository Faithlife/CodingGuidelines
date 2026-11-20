# update-nuget-packages

Updates git-tracked NuGet package references, MSBuild SDK references, and local .NET tool manifest versions by replacing only version text spans in supported project and manifest files.

## Settings

- `rules`: Optional array of rule objects. Rules match package IDs and adjust update policy.

Rule properties:

- `packages`: Required string or string array of package ID patterns. Patterns support case-insensitive `*` and `?` wildcards.
- `version`: Optional string, default `update-major`. Valid policy values are `update-major`, `update-minor`, `update-patch`, and `no-update`. A specific version such as `7.0.0` updates only to that exact version. A NuGet version range such as `[7.0.0, 8.0.0)` updates only to versions inside that range.
- `include-prerelease`: Optional boolean, default `false`. When true, prerelease candidates are eligible.
- `prerelease-channel`: Optional string. When set, candidates must be prerelease versions that use the specified prerelease label. This setting takes precedence over `include-prerelease`.
- `publish-cooldown`: Optional string, default `weekly`. `weekly` only permits versions published on or before the Tuesday before the last Tuesday. `none` permits the newest eligible version regardless of publish date. Use this for package ID patterns owned and validated by your organization.

## Behavior

The convention requires the target directory to be inside a git worktree and only edits files reported by `git ls-files`. It scans git-tracked `*.csproj`, `*.props`, `*.targets`, and any `dotnet-tools.json` file.

Package metadata is resolved from enabled NuGet package sources configured for the repository, including sources inherited from `nuget.config`. Non-HTTP package sources such as local folders are supported; because those sources use local file timestamps rather than package publish timestamps, their versions are treated as old enough for the publish-date cutoff.

By default, only versions published on or before the Tuesday before the last Tuesday are eligible. This gives newly published packages at least one full week before the convention can select them. A matching rule can set `publish-cooldown: none` for some packages while leaving the default cooldown in place for others, such as third-party packages.

Package references are only updated to versions that support the target frameworks of the projects that use them, based on the target frameworks of the package's dependency groups. A reference in a project file uses that project's frameworks, a `PackageVersion` in `Directory.Packages.props` uses the frameworks of every project that references the package, and a reference in another `.props` or `.targets` file uses the frameworks of every project below it. Project frameworks are read from literal `TargetFramework` and `TargetFrameworks` values in the project file or in a `Directory.Build.props` file above it, resolving simple property references; otherwise SDK-style projects are evaluated with `dotnet msbuild -getProperty`. When some project frameworks can't be determined, the convention does not update to a version that drops a framework supported by the current version. Packages without dependency groups are treated as compatible, and MSBuild SDK and .NET tool versions are not checked. When a newer version is skipped because of target frameworks, the convention prints a line such as `Example.Package held at 1.1.0: 2.0.0 does not support net472`.

The convention leaves package reference wildcard versions, package reference version ranges, computed MSBuild expressions, and unsupported XML shapes unchanged. Same-file property expressions such as `Version="$(PackageVersion)"` are updated when the property has a single literal definition in the same file. When several packages share a version property, it is updated to the newest version that is eligible for all of them.

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
          prerelease-channel: faithlife
        - packages:
            - Faithlife.*
            - Logos.*
          publish-cooldown: none
```

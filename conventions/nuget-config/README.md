# nuget-config

Creates or updates the repository-root `nuget.config` to ensure it uses the standard package sources.

## Behavior

When no `nuget.config` exists, the convention creates one from [files/nuget.config](./files/nuget.config), which configures `nuget.org` and the Faithlife Azure Artifacts feed as the standard package sources.

When a `nuget.config` already exists, the convention replaces only the `<packageSources>` element to match the published template. All other sections — including `<packageSourceMapping>` and `<activePackageSource>` — are preserved. This allows each repository to maintain its own package source mappings, which vary by the private packages each project consumes.

If the file exists but is not valid XML, or does not contain a `<packageSources>` element, the convention throws an error.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/nuget-config
```

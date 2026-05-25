# faithlife-dotnet-library-targets

Manages shared central package management settings in `Directory.Packages.props`.

## Behavior

This convention writes managed XML sections for central package management properties and global analyzer references. Repository-specific `PackageVersion` items remain outside the managed sections so libraries can own their dependency versions.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library-targets
```

# faithlife-dotnet-library-build

Creates or refreshes Faithlife .NET library build project files under `tools/Build`.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

The convention rewrites `tools/Build/Build.cs` and `tools/Build/Build.csproj` to the published templates whenever they differ. If the repository root contains a parseable `global.json` with `sdk.version`, the generated `Build.csproj` target framework is retargeted to `netX.Y` from that SDK major and minor version using a text transformation.

If the convention creates `Build.csproj`, it ensures the repository root has a solution file. When no root `.sln` or `.slnx` exists, it runs `dotnet new sln`, then runs `dotnet sln add ./tools/Build --in-root`.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library-build
```

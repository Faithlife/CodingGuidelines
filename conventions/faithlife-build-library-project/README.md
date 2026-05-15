# faithlife-build-library-project

Creates missing Faithlife build project files under `tools/Build`.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

If the convention copies `Build.csproj`, it ensures the repository root has a solution file. When no root `.sln` or `.slnx` exists, it runs `dotnet new sln`, then runs `dotnet sln add ./tools/Build --in-root`.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-build-library-project
```

# faithlife-build-library-project

Creates missing Faithlife build project files under `tools/Build`.

## Behavior

If the convention copies `Build.csproj`, it ensures the repository root has a solution file. When no root `.sln` or `.slnx` exists, it runs `dotnet new sln`, then runs `dotnet sln add ./tools/Build --in-root`.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-build-library-project
```

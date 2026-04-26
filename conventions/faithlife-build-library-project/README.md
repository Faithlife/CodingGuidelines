# faithlife-build-library-project

This [convention](https://github.com/Faithlife/RepoConventions) copies [files/Build.cs](files/Build.cs) and [files/Build.csproj.xml](files/Build.csproj.xml) into `tools/Build` as `Build.csproj` when those files are missing.

If the convention copies `Build.csproj`, it ensures the repository root has a solution file. When no root `.sln` or `.slnx` exists, it runs `dotnet new sln`, then runs `dotnet sln add ./tools/Build --in-root`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-build-library-project
```

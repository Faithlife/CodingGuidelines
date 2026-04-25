# faithlife-build-library-project

This [convention](https://github.com/Faithlife/RepoConventions) copies `Build.cs` and `Build.csproj` into `tools/Build` when those files are missing.

If the convention copies `Build.csproj` and the repository root contains a solution file, it runs `dotnet sln add ./tools/Build --in-root`.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/faithlife-build-library-project
```

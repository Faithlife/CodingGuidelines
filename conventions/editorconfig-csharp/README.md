# editorconfig-csharp

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the standard C# section from [conventions/editorconfig-csharp/.editorconfig](.editorconfig).

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `csharp-editorconfig` managed section and reads the section text from a generated file that lives next to the convention. In this repository, [the local updater convention](../../.github/conventions/update-editorconfig-csharp/README.md) regenerates that file from [sections/csharp/editorconfig.md](../../sections/csharp/editorconfig.md).

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-csharp
```

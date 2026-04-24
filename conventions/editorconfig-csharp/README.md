# editorconfig-csharp

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the standard C# section from [sections/csharp/files/.editorconfig](../../sections/csharp/files/.editorconfig).

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `csharp-editorconfig` managed section and reads the section text from the repository source file so the published convention stays aligned with the documented C# settings.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/editorconfig-csharp
```

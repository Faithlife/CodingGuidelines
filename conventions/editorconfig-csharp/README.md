# editorconfig-csharp

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the standard C# section from [files/.editorconfig](files/.editorconfig).

This convention does not support any settings.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `csharp-editorconfig` managed section and reads the section text from the generated [files/.editorconfig](files/.editorconfig) asset. In this repository, [the local updater convention](../../.github/conventions/update-editorconfig-csharp/README.md) regenerates that file from [sections/csharp/editorconfig.md](../../sections/csharp/editorconfig.md). When it changes `.editorconfig`, it runs the packaged Copilot instructions and commits the result with the message `Update C# editorconfig settings.`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-csharp
```

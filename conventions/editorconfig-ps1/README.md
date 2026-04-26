# editorconfig-ps1

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed PowerShell section from [files/.editorconfig](files/.editorconfig).

This convention does not support any settings.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `ps1` managed section and reads the section text from the convention-local [files/.editorconfig](files/.editorconfig) file. When it changes `.editorconfig`, it runs packaged Copilot follow-up instructions and commits the result with the message `Update PowerShell editorconfig settings`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-ps1
```
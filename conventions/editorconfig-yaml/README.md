# editorconfig-yaml

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed YAML section from [files/.editorconfig](files/.editorconfig).

This convention does not support any settings.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `yaml` managed section and reads the section text from the convention-local [files/.editorconfig](files/.editorconfig) file. When it changes `.editorconfig`, it runs packaged Copilot follow-up instructions and commits the result with the message `Update YAML editorconfig settings`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-yaml
```
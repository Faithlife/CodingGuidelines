# editorconfig-yaml

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed YAML section from [.editorconfig](.editorconfig).

This convention does not support any settings.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `yaml` managed section and reads the section text from the convention-local [.editorconfig](.editorconfig) file. When it changes `.editorconfig`, it commits the result with the message `Update YAML editorconfig settings.`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-yaml
```
# editorconfig-json

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed JSON section from [.editorconfig](.editorconfig).

This convention does not support any settings.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `json` managed section and reads the section text from the convention-local [.editorconfig](.editorconfig) file. When it changes `.editorconfig`, it commits the result with the message `Update JSON editorconfig settings.`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-json
```
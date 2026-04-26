# editorconfig-root

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the standard `[*]` section described in [sections/editorconfig.md](../../sections/editorconfig.md).

This convention does not support any settings.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `general-editorconfig` managed section and the documented default text for all files. When it changes `.editorconfig`, it runs packaged Copilot follow-up instructions and commits the result with the message `Update root editorconfig settings`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-root
```

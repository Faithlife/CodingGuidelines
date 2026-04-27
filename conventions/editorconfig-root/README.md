# editorconfig-root

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the standard `[*]` section described in [sections/editorconfig.md](../../sections/editorconfig.md).

This convention does not support any settings.

The convention composes [editorconfig-section](../editorconfig-section/README.md) with the fixed `root` managed section and the documented root settings for all files. The managed section starts with `root = true`, followed by a blank line and the standard `[*]` section. When it changes `.editorconfig`, it runs packaged Copilot follow-up instructions and commits the result with the message `Update root editorconfig settings`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-root
```

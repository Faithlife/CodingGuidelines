# editorconfig-root

Ensures the repository-root `.editorconfig` contains the standard `[*]` section described in [sections/editorconfig.md](../../sections/editorconfig.md).

## Behavior

The convention manages the fixed `root` section and the documented root settings for all files. The managed section starts with `root = true`, followed by a blank line and the standard `[*]` section. Existing `.editorconfig` content outside the managed section is preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-root
```

# editorconfig-root

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the standard `[*]` section described in [sections/editorconfig.md](../../sections/editorconfig.md).

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `general-editorconfig` managed section and the documented default text for all files.

```yaml
conventions:
	- path: Faithlife/CodingGuidelines/conventions/editorconfig-root
```

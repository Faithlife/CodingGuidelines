# editorconfig-json

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed JSON section from [.editorconfig](.editorconfig).

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `json` managed section and reads the section text from the convention-local [.editorconfig](.editorconfig) file.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-json
```
# editorconfig-yaml

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed YAML section from [.editorconfig](.editorconfig).

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.
- `commit`: Optional `editorconfig` commit settings to pass through, for example when callers want `.editorconfig` changes committed before the convention exits.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `yaml` managed section and reads the section text from the convention-local [.editorconfig](.editorconfig) file.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-yaml
```
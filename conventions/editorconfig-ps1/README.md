# editorconfig-ps1

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains the managed PowerShell section from [.editorconfig](.editorconfig).

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.
- `commit`: Optional `editorconfig` commit settings to pass through, for example when callers want `.editorconfig` changes committed before the convention exits.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `ps1` managed section and reads the section text from the convention-local [.editorconfig](.editorconfig) file.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-ps1
```
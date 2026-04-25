# editorconfig-ps1

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains a managed PowerShell section with two-space indentation.

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `ps1` managed section and a `[*.ps1]` rule that sets `indent_style = space` and `indent_size = 2`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-ps1
```
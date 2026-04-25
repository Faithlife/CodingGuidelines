# editorconfig-md

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains a managed Markdown section with two-space indentation.

Settings:

- `agent`: Optional `editorconfig` agent settings to pass through, for example when callers want Copilot follow-up instructions after `.editorconfig` changes.

The convention composes [editorconfig](../editorconfig/README.md) with the fixed `md` managed section and a `[*.md]` rule that sets `indent_style = space` and `indent_size = 2`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-md
```
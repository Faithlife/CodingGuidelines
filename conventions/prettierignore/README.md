# prettierignore

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to the repository's `.prettierignore` when they are missing.

Settings:

- `lines`: Array of lines to append to `.prettierignore` when missing.
- `commit`: Optional `config-text` commit settings to pass through, for example when callers want `.prettierignore` changes committed before the convention exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/prettierignore
    settings:
      lines:
        - coverage/
        - dist/
      commit:
        message: Update .prettierignore.
```

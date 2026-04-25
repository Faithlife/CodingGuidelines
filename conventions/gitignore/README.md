# gitignore

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to the repository's `.gitignore` when they are missing.

Settings:

- `lines`: Array of lines to append to `.gitignore` when missing.
- `commit`: Optional `config-text` commit settings to pass through, for example when callers want `.gitignore` changes committed before the convention exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitignore
    settings:
      lines:
        - bin/
        - obj/
      commit:
        message: Update .gitignore.
```

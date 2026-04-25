# gitattributes

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to the repository's `.gitattributes` when they are missing.

Settings:

- `lines`: Array of lines to append to `.gitattributes` when missing.
- `commit`: Optional `config-text` commit settings to pass through, for example when callers want `.gitattributes` changes committed before the convention exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitattributes
    settings:
      lines:
        - *.g.* linguist-generated=true
      commit:
        message: Update .gitattributes.
```

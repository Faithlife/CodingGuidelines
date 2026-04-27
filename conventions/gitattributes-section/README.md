# gitattributes-section

This [convention](https://github.com/Faithlife/RepoConventions) manages a named section within the repository-root `.gitattributes` file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.gitattributes` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.gitattributes` changes.
- `commit`: Optional `config-text-section` commit settings to pass through, for example when callers want `.gitattributes` changes committed before the convention exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitattributes-section
    settings:
      name: generated-files
      text: |
        *.g.* linguist-generated=true
      commit:
        message: Update .gitattributes.
```

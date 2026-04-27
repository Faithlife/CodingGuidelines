# gitignore-section

This [convention](https://github.com/Faithlife/RepoConventions) manages a named section within the repository-root `.gitignore` file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.gitignore` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.gitignore` changes.
- `commit`: Optional `config-text-section` commit settings to pass through, for example when callers want `.gitignore` changes committed before the convention exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitignore-section
    settings:
      name: build-output
      text: |
        bin/
        obj/
      commit:
        message: Update .gitignore.
```

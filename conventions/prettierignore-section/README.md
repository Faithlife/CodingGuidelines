# prettierignore-section

This [convention](https://github.com/Faithlife/RepoConventions) manages a named section within the repository-root `.prettierignore` file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.prettierignore` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.prettierignore` changes.
- `commit`: Optional `config-text-section` commit settings to pass through, for example when callers want `.prettierignore` changes committed before the convention exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/prettierignore-section
    settings:
      name: build-output
      text: |
        coverage/
        dist/
      commit:
        message: Update .prettierignore.
```

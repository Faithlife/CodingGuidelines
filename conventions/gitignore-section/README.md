# gitignore-section

Manages a named section within the repository-root `.gitignore` file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.gitignore` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.gitignore` changes.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitignore-section
    commit:
      message: Update .gitignore.
    settings:
      name: build-output
      text: |
        bin/
        obj/
```

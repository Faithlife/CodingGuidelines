# gitattributes-section

Manages a named section within the repository-root `.gitattributes` file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.gitattributes` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.gitattributes` changes.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitattributes-section
    commit:
      message: Update .gitattributes.
    settings:
      name: generated-files
      text: |
        *.g.* linguist-generated=true
```

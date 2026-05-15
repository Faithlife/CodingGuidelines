# gitattributes-section

Manages a named section within the repository-root `.gitattributes` file.

## Settings

- `name`: Required non-empty section name used in the managed marker.
- `text`: Required exact `.gitattributes` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.gitattributes` changes.

## Behavior

If `.gitattributes` does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other `.gitattributes` content is preserved.

## Example

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

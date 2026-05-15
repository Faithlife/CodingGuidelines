# gitignore-section

Manages a named section within the repository-root `.gitignore` file.

## Settings

- `name`: Required non-empty section name used in the managed marker.
- `text`: Required exact `.gitignore` text to place inside the managed section.

## Behavior

If `.gitignore` does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other `.gitignore` content is preserved.

## Example

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

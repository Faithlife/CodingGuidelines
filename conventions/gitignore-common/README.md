# gitignore-common

Manages common operating-system and log-file ignore patterns in `.gitignore`.

## Behavior

This convention writes a named managed section so repositories can share baseline ignore entries while preserving repository-specific patterns outside the managed section.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitignore-common
```

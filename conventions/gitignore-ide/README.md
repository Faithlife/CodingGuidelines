# gitignore-ide

Manages editor and IDE state ignore patterns in `.gitignore`.

## Behavior

This convention writes a named managed section so repositories consistently ignore local editor state while preserving repository-specific patterns outside the managed section.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitignore-ide
```

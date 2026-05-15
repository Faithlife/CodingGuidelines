# editorconfig-section

Manages a named section within the repository-root `.editorconfig` file.

## Settings

- `name`: Required non-empty section name used in the managed marker.
- `text`: Required exact `.editorconfig` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want build-validation instructions after `.editorconfig` changes.

## Behavior

If `.editorconfig` does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other `.editorconfig` content is preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-section
    commit:
      message: Update .editorconfig.
    settings:
      name: general-editorconfig
      text: |
        [*]
        charset = utf-8
        end_of_line = lf
        indent_size = 2
        indent_style = space
        insert_final_newline = true
        trim_trailing_whitespace = true
```

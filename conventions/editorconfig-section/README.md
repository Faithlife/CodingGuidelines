# editorconfig-section

Manages a named section within the repository-root `.editorconfig` file.

## Settings

- `name`: Required non-empty section name used in the managed marker.
- `text`: Required exact `.editorconfig` text to place inside the managed section.
- `remove-root-rules`: Optional array of property names to remove from unmanaged `[*]` sections when `text` contains a top-level `root = true` declaration. Defaults to an empty array.

## Behavior

If `.editorconfig` does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other non-redundant `.editorconfig` content is preserved.

When the configured `text` contains a top-level `root = true` declaration, the convention treats the managed section as the root section and keeps it before other `.editorconfig` sections. It also removes unmanaged `root = true` declarations and removes configured `remove-root-rules` entries from unmanaged `[*]` sections.

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

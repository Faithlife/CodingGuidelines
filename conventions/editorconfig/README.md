# editorconfig

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository-root `.editorconfig` contains `root = true` and manages a named section within the file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.editorconfig` section text to place inside the managed section.

If `.editorconfig` does not exist, the convention seeds it with `root = true`, then adds a blank line and the managed section. If the named section already exists, the convention replaces only that section. Other `.editorconfig` content is preserved.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/editorconfig
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

# editorconfig

This [convention](https://github.com/Faithlife/RepoConventions) manages a named block in the repository-root `.editorconfig` file.

Settings:

- `name`: Non-empty block name used in the managed marker.
- `text`: Exact `.editorconfig` section text to place inside the managed block.

If `.editorconfig` does not exist, the convention creates it with `root = true`, a blank line, and the managed block. If the named block already exists, the convention replaces only that block. Other `.editorconfig` content is preserved.

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

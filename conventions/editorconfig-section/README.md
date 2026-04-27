# editorconfig-section

This [convention](https://github.com/Faithlife/RepoConventions) manages a named section within the repository-root `.editorconfig` file.

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.editorconfig` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want build-validation instructions after `.editorconfig` changes.
- `commit`: Optional `config-text-section` commit settings to pass through, for example when callers want `.editorconfig` changes committed before the convention exits.

If `.editorconfig` does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other `.editorconfig` content is preserved.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-section
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
      commit:
        message: Update .editorconfig.
```

# config-text-section

Manages one named text section in a repository file.

## Settings

- `path`: Required target file path, relative to the root of the target repository.
- `name`: Required non-empty section name used in the managed markers.
- `text`: Required exact text to place inside the managed section.
- `comment-prefix`: Required comment prefix to use for the managed markers.
- `comment-suffix`: Optional comment suffix to use for the managed markers. Defaults to no suffix.

## Behavior

If the target file does not exist, the convention creates it with the managed section. If the target file contains a closing XML element, new sections are inserted before the closing root element and indented two spaces. If the named section already exists, the convention replaces only that section. Other file content is preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/config-text-section
    commit:
      message: Update .editorconfig
    settings:
      path: .editorconfig
      name: general-editorconfig
      text: |
        [*]
        charset = utf-8
      comment-prefix: '#'
```

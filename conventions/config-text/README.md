# config-text

This [convention](https://github.com/Faithlife/RepoConventions) manages text content in a repository-root-relative file by appending missing lines and optionally maintaining a named managed section.

Settings:

- `path`: Target file path, relative to the root of the target repository.
- `lines`: Array of lines to append when missing.
- `section`: Optional managed section to insert or update.
- `section.name`: Non-empty section name used in the managed markers.
- `section.text`: Exact text to place inside the managed section.
- `section.comment-prefix`: Comment prefix to use for the managed markers.
- `section.comment-suffix`: Optional comment suffix to use for the managed markers.

If the target file does not exist, the convention creates it. If every configured line and managed section already matches, the convention leaves the file unchanged.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/config-text
  settings:
    path: .editorconfig
    lines:
    - root = true
    section:
      name: general-editorconfig
      text: |
        [*]
        charset = utf-8
      comment-prefix: '#'
```

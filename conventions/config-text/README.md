# config-text

This [convention](https://github.com/Faithlife/RepoConventions) manages text content in a repository-root-relative file by appending missing lines and optionally maintaining a named managed section.

Settings:

- `path`: Target file path, relative to the root of the target repository.
- `new-file-text`: Optional text to seed the target file with when it does not already exist.
- `lines`: Array of lines to append when missing.
- `section`: Optional managed section to insert or update.
- `section.name`: Non-empty section name used in the managed markers.
- `section.text`: Exact text to place inside the managed section.
- `section.comment-prefix`: Comment prefix to use for the managed markers.
- `section.comment-suffix`: Optional comment suffix to use for the managed markers. When non-empty, the convention writes it with a leading space automatically.
- `agent`: Optional Copilot agent settings to run after the convention changes the target file.
- `agent.instructions`: Optional instructions string to pass to Copilot after the file changes. Missing, `null`, empty, or whitespace instructions do not run Copilot.

If the target file does not exist, the convention creates it. If every configured line and managed section already matches, the convention leaves the file unchanged.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/config-text
    settings:
      path: .editorconfig
      new-file-text: root = true
      section:
        name: general-editorconfig
        text: |
          [*]
          charset = utf-8
        comment-prefix: '#'
      agent:
        instructions: Build the code if changes were made.
```

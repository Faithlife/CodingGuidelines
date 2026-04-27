# config-text-section

This [convention](https://github.com/Faithlife/RepoConventions) manages one named text section in a repository-root-relative file.

Settings:

- `path`: Target file path, relative to the root of the target repository.
- `name`: Non-empty section name used in the managed markers.
- `text`: Exact text to place inside the managed section.
- `comment-prefix`: Comment prefix to use for the managed markers.
- `comment-suffix`: Optional comment suffix to use for the managed markers. When non-empty, the convention writes it with a leading space automatically.
- `agent`: Optional Copilot agent settings to run after the convention changes the target file.
- `agent.instructions`: Optional instructions string to pass to Copilot after the file changes. Missing, `null`, empty, or whitespace instructions do not run Copilot.
- `commit`: Optional git commit settings to run after the convention changes the target file.
- `commit.message`: Optional commit message to use after the convention and any configured agent finish making changes. Missing, `null`, empty, or whitespace messages do not create a commit.

If the target file does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other file content is preserved. When `commit.message` is configured and the convention or its configured agent changes the repository, the script stages those changes and creates a commit before it exits.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/config-text-section
    settings:
      path: .editorconfig
      name: general-editorconfig
      text: |
        [*]
        charset = utf-8
      comment-prefix: '#'
      commit:
        message: Update .editorconfig.
      agent:
        instructions: Build the code if changes were made.
```

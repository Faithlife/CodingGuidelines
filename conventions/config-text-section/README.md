# config-text-section

This [convention](https://github.com/Faithlife/RepoConventions) manages one named text section.

Settings:

- `path`: Target file path, relative to the root of the target repository.
- `name`: Section name used in the managed markers.
- `text`: Exact text to place inside the managed section.
- `comment-prefix`: Comment prefix to use for the managed markers.
- `comment-suffix`: Optional comment suffix to use for the managed markers.
- `agent`: Optional Copilot agent settings to run after the convention changes the target file.
- `agent.instructions`: Optional instructions string to pass to Copilot after the file changes. Missing, `null`, empty, or whitespace instructions do not run Copilot.

If the target file does not exist, the convention creates it with the managed section. If the named section already exists, the convention replaces only that section. Other file content is preserved. Use native convention `commit.message` settings to configure automatic commit messages.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/config-text-section
    commit:
      message: Update .editorconfig.
    settings:
      path: .editorconfig
      name: general-editorconfig
      text: |
        [*]
        charset = utf-8
      comment-prefix: '#'
      agent:
        instructions: Build the code and fix it if necessary.
```

The reusable implementation lives in [conventions/scripts/ConfigTextSection.ps1](../scripts/ConfigTextSection.ps1). Executable conventions that need repository-specific inspection before managing a section can dot-source that script and call `Invoke-ConfigTextSection` with their effective settings.

# prettierignore

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to the repository's `.prettierignore` when they are missing.

Settings:

- `entries`: Array of lines to append to `.prettierignore` when missing.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/prettierignore
  settings:
    entries:
    - coverage/
    - dist/
```

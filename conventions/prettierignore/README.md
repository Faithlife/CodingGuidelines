# prettierignore

This [convention](https://github.com/Faithlife/RepoConventions) appends configured lines to the repository's `.prettierignore` by applying [`line-based-config`](../line-based-config/).

Settings:

- `entries`: Array of lines to append to `.prettierignore`. Each entry must be a single line and must not contain newline characters.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/prettierignore
  settings:
    entries:
    - coverage/
    - dist/
```

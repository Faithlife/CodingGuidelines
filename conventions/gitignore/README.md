# gitignore

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to the repository's `.gitignore` when they are missing.

Settings:

- `lines`: Array of lines to append to `.gitignore` when missing.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/gitignore
  settings:
    lines:
    - bin/
    - obj/
```

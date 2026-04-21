# gitattributes

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to the repository's `.gitattributes` when they are missing.

Settings:

- `entries`: Array of lines to append to `.gitattributes` when missing.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/gitattributes
  settings:
    entries:
    - *.g.* linguist-generated=true
```

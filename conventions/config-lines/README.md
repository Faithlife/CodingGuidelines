# config-lines

This [convention](https://github.com/Faithlife/RepoConventions) appends lines to a text file without duplicating lines that are already present.

Settings:

- `path`: Target file path, relative to the root of the target repository.
- `entries`: Array of lines to append when missing.

If the target file does not exist, the convention creates it. If every configured entry is already present, the convention leaves the file unchanged.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/config-lines
  settings:
    path: .gitignore
    entries:
    - bin/
    - obj/
```

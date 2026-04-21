# line-based-config

This [convention](https://github.com/Faithlife/RepoConventions) appends configured lines to a text file without duplicating lines that are already present.

Settings:

- `path`: Target file path, relative to the root of the target repository. A leading slash is optional.
- `entries`: Array of lines to append. Each entry must be a single line and must not contain newline characters.

If the target file does not exist, the convention creates it. If every configured entry is already present as an exact line match, the convention leaves the file unchanged.

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/line-based-config
  settings:
    path: .gitignore
    entries:
    - bin/
    - obj/
```

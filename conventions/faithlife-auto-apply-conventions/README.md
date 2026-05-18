# faithlife-auto-apply-conventions

Ensures that `.github/conventions.yml` starts with the marker used by RepoConventionsApplier.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

The convention keeps repositories compatible with RepoConventionsApplier by preserving the required first-line marker:

```text
# applied automatically by https://github.com/Faithlife/RepoConventionsApplier (DO NOT REMOVE THIS LINE)
```

If the first line already contains `DO NOT REMOVE`, the convention treats it as an older auto-apply marker and replaces it. Otherwise, it inserts the marker as the first line and preserves the file's existing line endings.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-auto-apply-conventions
```

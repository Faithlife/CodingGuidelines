# update-readme-conventions

Regenerates the managed conventions table in the repository-root README from published convention READMEs.

## Behavior

The convention scans `conventions/*/README.md` for directories that contain `convention.yml` or `convention.ps1`, uses the first paragraph after each README title as the table description, and rewrites relative links in those descriptions so they resolve from the root README.

The table is managed between `DO NOT EDIT` and `END DO NOT EDIT` comments. Existing README text before or after that managed block is preserved, and repositories without a managed block get the table appended without adding a heading.

## Example

```yaml
conventions:
  - path: .github/conventions/update-readme-conventions
```

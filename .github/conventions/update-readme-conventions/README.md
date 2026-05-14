# update-readme-conventions

Regenerates the repository-root README `## Conventions` table from published convention READMEs.

This convention does not support any settings.

The convention scans `conventions/*/README.md` for directories that contain `convention.yml` or `convention.ps1`, uses the first paragraph after each README title as the table description, and rewrites relative links in those descriptions so they resolve from the root README.

```yaml
conventions:
  - path: .github/conventions/update-readme-conventions
```

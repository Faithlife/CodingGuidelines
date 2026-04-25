# license-mit

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository root `LICENSE` file contains the published MIT license from this convention directory.

The published license template uses `<YEAR>` in place of the copyright year. When the convention runs, it replaces that placeholder with the current UTC year and writes the rendered result to `LICENSE`.

If the repository already has a `LICENSE` file, the convention replaces it when it does not match the rendered MIT license.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/license-mit
```

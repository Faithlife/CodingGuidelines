# license-mit

This [convention](https://github.com/Faithlife/RepoConventions) ensures the repository root `LICENSE` file contains the published MIT license from [files/LICENSE](files/LICENSE).

## Settings

- `copyright-holder`: The copyright holder name to render in the MIT license.

The published license template uses `<YEAR>` and `<COPYRIGHT-HOLDER>` placeholders. When the convention runs, it replaces those placeholders and writes the rendered result to `LICENSE`.

If the repository already has a `LICENSE` file, the convention replaces it when it does not match the rendered MIT license.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/license-mit
    settings:
      copyright-holder: Contoso
```

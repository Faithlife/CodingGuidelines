# faithlife-build-library-workflow

Installs the published `build.yaml` workflow at `.github/workflows/build.yaml`.

## Behavior

The convention copies the workflow from [files/build.yaml](./files/build.yaml) and overwrites the target file when it differs.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-build-library-workflow
```

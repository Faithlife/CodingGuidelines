# faithlife-build-library-workflow

This [convention](https://github.com/Faithlife/RepoConventions) saves the published `build.yaml` workflow to `.github/workflows/build.yaml`.

It copies the workflow from [files/build.yaml](files/build.yaml) and overwrites the target file when it differs.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-build-library-workflow
```

# faithlife-dotnet-library-workflow

Installs the published Faithlife .NET library `ci.yml` workflow at `.github/workflows/ci.yml`.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

The convention copies the workflow from [files/ci.yml](./files/ci.yml) and overwrites the target file when it differs.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library-workflow
```

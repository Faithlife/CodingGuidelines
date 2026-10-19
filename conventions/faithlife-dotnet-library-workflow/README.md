# faithlife-dotnet-library-workflow

Installs the published Faithlife .NET library workflows at `.github/workflows/ci.yml` and `.github/workflows/copilot-setup-steps.yml`.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

The convention copies the workflows from [files/ci.yml](./files/ci.yml) and [files/copilot-setup-steps.yml](./files/copilot-setup-steps.yml), and overwrites the target files when they differ.

NuGet publishing uses Trusted Publishing with the shared `LogosPackages` account rather than a personal account. Before adopting the workflow, ensure that `LogosPackages` has permission to publish the repository's packages and a matching NuGet Trusted Publishing policy for the repository and workflow.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library-workflow
```

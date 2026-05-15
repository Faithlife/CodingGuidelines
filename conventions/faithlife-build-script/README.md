# faithlife-build-script

Installs the published `build.ps1` script at the repository root.

## Behavior

The convention copies the script from [files/build.ps1](./files/build.ps1) and marks `build.ps1` as executable in Git.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-build-script
```

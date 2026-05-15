# editorconfig-ps1

Ensures the repository-root `.editorconfig` contains the managed PowerShell section from [files/.editorconfig](./files/.editorconfig).

## Behavior

The convention manages the fixed `ps1` section and reads the section text from the convention-local [files/.editorconfig](./files/.editorconfig) file. Existing `.editorconfig` content outside the managed section is preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-ps1
```

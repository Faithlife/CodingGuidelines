# editorconfig-csharp

Ensures the repository-root `.editorconfig` contains the standard C# section from [files/.editorconfig](./files/.editorconfig).

## Behavior

The convention manages the fixed `csharp-editorconfig` section and reads the section text from the generated [files/.editorconfig](./files/.editorconfig) asset. Existing `.editorconfig` content outside the managed section is preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/editorconfig-csharp
```

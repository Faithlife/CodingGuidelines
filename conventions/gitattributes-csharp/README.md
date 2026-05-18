# gitattributes-csharp

Ensures the repository-root `.gitattributes` contains the standard C# section from [files/.gitattributes](./files/.gitattributes).

## Behavior

The convention manages the fixed `csharp` section and reads the section text from the packaged [files/.gitattributes](./files/.gitattributes) asset. Existing `.gitattributes` content outside the managed section is preserved.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitattributes-csharp
```

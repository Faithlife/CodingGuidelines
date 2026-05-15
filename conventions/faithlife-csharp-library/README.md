# faithlife-csharp-library

Applies conventions common to Faithlife C# libraries.

> [!WARNING]
> This convention only works with repositories in the [Faithlife](https://github.com/Faithlife) organization.

## Behavior

The convention normalizes line endings, requires .NET SDK 10 or later, migrates root solutions to `.slnx`, installs standard EditorConfig sections, installs the Faithlife build script and build project, and installs the standard library build workflow.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-csharp-library
```

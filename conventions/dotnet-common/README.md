# dotnet-common

Applies conventions common to repositories that build a .NET solution.

## Behavior

The convention normalizes line endings, requires .NET SDK 10 or later, migrates root solutions to `.slnx`, installs standard EditorConfig sections, and installs the build script.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-common
```

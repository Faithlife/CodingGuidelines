# faithlife-csharp-library

Applies conventions common to Faithlife C# libraries.

This convention does not support any settings.

It composes these conventions in order:

- [gitattributes-lf](../gitattributes-lf/README.md)
- [dotnet-sdk10](../dotnet-sdk10/README.md)
- [dotnet-slnx](../dotnet-slnx/README.md)
- [editorconfig-root](../editorconfig-root/README.md)
- [editorconfig-json](../editorconfig-json/README.md)
- [editorconfig-md](../editorconfig-md/README.md)
- [editorconfig-ps1](../editorconfig-ps1/README.md)
- [editorconfig-yaml](../editorconfig-yaml/README.md)
- [editorconfig-csharp](../editorconfig-csharp/README.md)
- [faithlife-build-script](../faithlife-build-script/README.md)
- [faithlife-build-library-project](../faithlife-build-library-project/README.md)
- [faithlife-build-library-workflow](../faithlife-build-library-workflow/README.md)

The combined effect is to normalize line endings, require .NET SDK 10 or later, migrate root solutions to `.slnx`, install standard EditorConfig sections, install the Faithlife build script and build project, and install the standard library build workflow.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-csharp-library
```

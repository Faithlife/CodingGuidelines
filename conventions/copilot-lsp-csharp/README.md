# copilot-lsp-csharp

Applies the published C# GitHub Copilot CLI LSP server configuration.

## Behavior

The convention applies a fixed `csharp` server definition that runs `dnx --yes --prerelease roslyn-language-server -- --stdio --autoLoadProjects` for `.cs` and `.cshtml` files.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/copilot-lsp-csharp
```

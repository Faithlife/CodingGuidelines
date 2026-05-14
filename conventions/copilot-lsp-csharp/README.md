# copilot-lsp-csharp

Applies the published C# GitHub Copilot CLI LSP server configuration.

This convention does not support any settings.

It composes [copilot-lsp](../copilot-lsp/README.md) with a fixed `csharp` server definition that runs `dnx --yes --prerelease roslyn-language-server -- --stdio --autoLoadProjects` for `.cs` and `.cshtml` files.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/copilot-lsp-csharp
```

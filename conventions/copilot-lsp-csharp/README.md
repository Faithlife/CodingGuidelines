# copilot-lsp-csharp

Applies the published C# GitHub Copilot CLI LSP server configuration.

## Behavior

The convention applies a fixed `csharp` server definition that runs `dnx roslyn-language-server --yes --prerelease -- --stdio --autoLoadProjects`, sets the working directory to `${PLUGIN_ROOT}`, and applies the server mapping for `.cs`, `.razor`, and `.cshtml` files.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/copilot-lsp-csharp
```

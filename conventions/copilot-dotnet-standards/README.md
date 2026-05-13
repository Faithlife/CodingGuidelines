# copilot-dotnet-standards

A composite convention that sets up Copilot for .NET development in one step.

## What this convention does

Applies three conventions in order:

1. **`apm-install`** — Installs `LogosBible/AgentConfiguration/common/dotnet-standards`, which provides Copilot instruction files for C# coding standards.
2. **`copilot-lsp-csharp`** — Configures the Roslyn language server in `.github/lsp.json` so Copilot has code intelligence for C#.
3. **`copilot-dotnet-format-hook`** — Deploys a `postToolUse` hook that runs `dotnet format` on every `.cs` file the agent edits or creates.

## Settings

None. This convention has no configurable settings.

## Usage

Add to your repository's `.github/conventions.yml`:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/copilot-dotnet-standards
```

Then apply:

```pwsh
repo-conventions apply
```

## See also

- [`copilot-dotnet-format-hook`](../copilot-dotnet-format-hook/README.md) — add only the format hook without the other components.
- [`copilot-lsp-csharp`](../copilot-lsp-csharp/README.md) — add only the Roslyn LSP configuration.
- See [RepoConventions README](../../README.md) for general usage.

# copilot-dotnet-format-hook

Deploys a Copilot `postToolUse` hook that automatically runs `dotnet format` on any `.cs` file after it is edited or created by the agent.

## What this convention does

- Creates `.github/hooks/scripts/dotnet-format.ps1` in the target repository.
- Merges a `postToolUse` hook entry into `.github/hooks/hooks.json` (creates the file if absent; preserves any existing hook entries).

Both operations are idempotent. Running the convention again when files are already correct produces no changes.

## Settings

None. This convention has no configurable settings.

## Requirements

- `dotnet` CLI available in the environment where Copilot runs.
- A `.sln` or project file that `dotnet format` can resolve from the repository root.

## Files created or modified

| Path | Description |
|---|---|
| `.github/hooks/scripts/dotnet-format.ps1` | Hook script that runs `dotnet format --include <file>` |
| `.github/hooks/hooks.json` | Copilot hooks configuration; hook entry is merged in |

## See also

- Use `copilot-dotnet-standards` to install this convention together with the Roslyn LSP server and .NET coding standard instruction files in one step.
- See [RepoConventions README](../../README.md) for general usage.

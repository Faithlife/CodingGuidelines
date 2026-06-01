# agentic-repo

Applies conventions useful for repositories that keep agent customization files in source control.

## Settings

- `apm-install`: Optional sequence of package identifiers to install for the Copilot APM target. Each entry must be a string package identifier accepted by `apm install`. Defaults to no configured packages.

## Behavior

The convention marks common agent customization paths as generated for GitHub linguist, ignores downloaded APM modules, and excludes agent package files from Prettier formatting when the repository appears to use Prettier. It also configures the Copilot APM target and runs APM package updates.

When `apm-install` is set, the convention passes those package identifiers to the `apm` convention's `install` setting.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/agentic-repo
```

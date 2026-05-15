# agentic-repo

Applies conventions useful for repositories that keep agent customization files in source control.

## Behavior

The convention marks common agent customization paths as generated for GitHub linguist, ignores downloaded APM modules, and excludes agent package files from Prettier formatting when the repository appears to use Prettier. If the repository has an `apm.yml`, it also updates the Copilot APM target.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/agentic-repo
```

# agentic-repo

Applies conventions useful for repositories that keep agent customization files in source control.

This convention does not support any settings.

It composes these conventions:

- [gitattributes-section](../gitattributes-section/README.md) adds an `agentic-repo` managed section that marks `apm.lock.yaml`, `.agents/**`, `.github/agents/**`, `.github/hooks/**`, `.github/instructions/**`, and `.github/prompts/**` as generated for GitHub linguist.
- [gitignore-section](../gitignore-section/README.md) adds an `agentic-repo` managed section that ignores `apm_modules/`.
- [prettierignore-section](../prettierignore-section/README.md) adds an `agentic-repo` managed section for `.agents/`, `apm.lock.yaml`, and `apm.yml` when the repository appears to use Prettier.
- [apm-install](../apm-install/README.md) updates the Copilot APM target when `apm.yml` exists.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/agentic-repo
```

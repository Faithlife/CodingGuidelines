# apm-install

Installs configured packages and updates existing packages for the Copilot APM target with `apm`.

## Settings

- `packages`: Optional sequence of package identifiers to pass to `apm install --update --target copilot`. Defaults to no configured packages.

## Behavior

The convention requires the `apm` command to be available when it runs. `copilot` is the only target currently supported.

If no packages are configured and the repository has no root `apm.yml`, the convention leaves the repository unchanged. After `apm install` completes, if the only changed file is `apm.lock.yaml`, the convention restores that file so update-only no-op runs stay clean.

## Examples

Install and update:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm-install
    settings:
      packages:
        - richlander/dotnet-inspect/skills/dotnet-inspect
        - microsoft/playwright-cli/skills/playwright-cli
```

Update only:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm-install
```

# apm

Installs configured packages for the Copilot APM target with `apm` and optionally updates existing packages.

## Settings

- `install`: Optional sequence of package identifiers to pass to `apm install --target copilot`. Defaults to no configured packages.
- `update`: Optional boolean that adds `--update` to `apm install` when `true`. Defaults to `false`.

## Behavior

The convention requires the `apm` command to be available when it runs. `copilot` is the only target currently supported.

If no packages are configured and the repository has no root `apm.yml`, the convention leaves the repository unchanged. When `update` is `true`, the convention adds `--update`; otherwise it runs a plain install. After `apm install` completes, if the only changed file is `apm.lock.yaml`, the convention restores that file so update-only no-op runs stay clean.

## Examples

Install specific packages:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm
    settings:
      install:
        - richlander/dotnet-inspect/skills/dotnet-inspect
        - microsoft/playwright-cli/skills/playwright-cli
```

Update only:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm
    settings:
      update: true
```

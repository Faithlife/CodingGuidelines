# apm

Installs configured packages for the Copilot APM target with `apm` and optionally updates existing packages.

## Settings

- `install`: Optional sequence of package identifiers to pass to `apm install`. Defaults to no configured packages.
- `update`: Optional boolean that runs `apm update --yes` after `apm install` when `true`. Defaults to `false`.

## Behavior

The convention requires the `apm` command to be available when it runs. If packages are configured and the repository has no root `apm.yml`, it first runs `apm init --yes` and removes the generated top-level `author` property because it is optional and often inaccurate. Before installing, it ensures `apm.yml` has a top-level `targets` property. If the property is absent, the convention appends a `copilot` target.

If no packages are configured and the repository has no root `apm.yml`, the convention leaves the repository unchanged. The convention runs `apm install --no-frozen` (apm 0.37+ otherwise verifies a committed lockfile like `--frozen` when `CI` is set, which would prevent the convention from updating it), passing configured packages when present, and then runs `apm update --yes` when `update` is `true`. After `apm` completes, if the only changed file is `apm.lock.yaml`, the convention restores that file so update-only no-op runs stay clean.

Before installing, the convention removes any directory listed under `deployed_files` in `apm.lock.yaml` that has no per-file entries in `deployed_file_hashes`. Older `apm` versions recorded deployed skill directories that way, and newer versions refuse to replace such a directory unless it is identical to what they would deploy ("no trustworthy local deployment baseline"). Removing the directory lets `apm install` redeploy it and record per-file hashes without resorting to `--force`, which would also bypass `apm` security checks.

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

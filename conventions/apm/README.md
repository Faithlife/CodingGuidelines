# apm

Installs configured packages for the Copilot APM target with `apm` and optionally updates existing packages.

## Settings

- `install`: Optional sequence of package identifiers to pass to `apm install`. Defaults to no configured packages.
- `update`: Optional boolean that runs `apm update --yes`. Defaults to `false`. For configured development installs, it runs before `apm install --dev`; otherwise it runs afterward.
- `dev`: Optional boolean that installs configured package identifiers with `apm install --dev`. Defaults to `false`.

## Behavior

The convention requires the `apm` command to be available when it runs. If packages are configured and the repository has no root `apm.yml`, it first runs `apm init --yes` and removes the generated top-level `author` property because it is optional and often inaccurate. Before installing, it ensures `apm.yml` has a top-level `targets` property. If the property is absent, the convention appends a `copilot` target.

If no packages are configured and the repository has no root `apm.yml`, the convention leaves the repository unchanged. By default, it runs `apm install`, passing configured packages when present. With `dev: true`, it passes configured package identifiers to `apm install --dev`. Before APM resolves them, it moves exact configured references from the root `dependencies.apm` list to `devDependencies.apm`. It leaves other package references and dependency kinds unchanged. If it cannot safely edit a non-empty inline dependency mapping or APM list, it stops without rewriting `apm.yml`.

For configured development installs with `update: true`, the convention runs `apm update --yes` before `apm install --dev`. This gives APM a chance to refresh existing references before dependency resolution. A still-cyclic producer manifest must be fixed first; APM cannot update through that cycle. Other installs keep the existing install-then-update order, and `update: false` does not run an update. The convention keeps lockfile changes from this pre-install development update, even when the lockfile is the only changed file. It does not check whether APM replaced a stale cached or locked package snapshot. Inspect the resulting lockfile and installed package when repairing a stale reference; a successful command or post-merge workflow rerun alone does not prove that a stale snapshot changed. The convention does not use `--force`, which APM documents does not refresh references.

APM ignores development dependencies declared by fetched packages. The `dev` setting changes the scope of packages installed into the repository where this convention runs; it does not change dependencies declared by those packages. If the convention cannot safely migrate a manifest or an APM command fails, it exits with an error. RepoConventions then rolls the target repository back to its state before applying this convention.

For runs other than a configured development update, if the only changed file is `apm.lock.yaml`, the convention restores that file so update-only no-op runs stay clean.

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

Install configured packages as development dependencies and update existing references first:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm
    settings:
      install:
        - richlander/dotnet-inspect/skills/dotnet-inspect
      dev: true
      update: true
```

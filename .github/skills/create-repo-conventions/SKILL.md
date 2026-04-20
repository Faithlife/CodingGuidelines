---
name: create-repo-conventions
description: Create or update conventions that are published by this repository.
---

# Create Repo Conventions

Use this skill when authoring or updating convention directories in this repository so other repositories can consume them through repo-conventions.

## Goal

Produce published conventions with a stable path, documented settings, and idempotent behavior that matches the repo-conventions contract.

## When To Use This Skill

- Use this skill when creating a new convention directory to be referenced by consuming repositories.
- Use this skill when editing a published `convention.yml`, `convention.ps1`, `README.md`, or related support files.
- Do not use this skill just to add a convention reference to a consuming repository. Use `use-repo-conventions` for that.

## Convention Model

- A published convention directory may contain `convention.yml`, `convention.ps1`, or both.
- If both files exist, repo-conventions applies `convention.yml` first and then executes `convention.ps1`.
- Composite conventions are for composing other conventions.
- Executable conventions are for inspecting repository state and rewriting files.
- Convention references may carry `settings`, but nested composite settings propagation is not currently implemented.

## Authoring Workflow

- Define the policy boundary first. Prefer one coherent convention over a grab bag of unrelated changes.
- Decide whether the convention should be composite, executable, or both.
- Inspect existing conventions and README content in this repository before introducing new structure or terminology.
- If this is the first convention being created for this repository, put the new convention directory in the `/conventions` directory unless otherwise directed.
- Keep the public surface small: stable path, clearly named settings, predictable outputs.
- Update documentation in the same change when the convention behavior or supported inputs change.

## Writing `convention.yml`

- Use `convention.yml` when the convention is purely composition.
- Keep entries in the intended application order.
- Use explicit local relative paths for conventions published from the same repository.
- Keep settings shallow and JSON-serializable.

Example:

```yaml
conventions:
  - path: ../dotnet-sdk
    settings:
      version: 10
  - path: ../dotnet-slnx
```

## Writing `convention.ps1`

- The script runs with `pwsh` from the root of the target Git repository, not from the convention directory.
- The script receives one argument: the path to a JSON input file.
- Use `$args[0]` to access the path to the JSON input file, since future versions may pass additional arguments.
- The JSON input file contains a single `settings` property.
- Read the JSON input file only if needed.
- Make the script idempotent. A second successful run should produce no further changes.
- Exit with code zero when the repository is already compliant or after successfully making it compliant; use a non-zero exit code only when the convention genuinely cannot complete.
- Prefer deterministic file writes and stable ordering so reruns do not churn diffs.
- Avoid interactive prompts, editor launches, or hidden machine-local dependencies.
- Emit focused output that explains what the convention changed or why it failed.

Minimal pattern:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$conventionInput = Get-Content -Raw $args[0] | ConvertFrom-Json
$settings = $conventionInput.settings

# Inspect the target repository and apply only the required changes.
```

Don't bother reading the input file if your convention doesn't have settings, but keep in mind that settings may be added later and the convention should continue to work.

## Behavioral Constraints

- On success, repo-conventions will auto-commit tracked or untracked changes left behind by the executable convention.
- On failure, repo-conventions will hard-reset the target repository back to the pre-convention HEAD.
- Do not create formatting-only churn unless formatting is the actual purpose of the convention.

## Documentation

- Always include a `README.md` in the convention directory documenting the convention's purpose, supported settings, and any required tools or frameworks.

## Testing

- Test the convention with Pester if possible.
- Use syntax compatible with Pester 3.x, since that's what's generally available.
- Put Pester tests in the same directory as the convention they cover, e.g. `conventions/my-convention/convention.Tests.ps1`.
- Verify behavior against a clean temporary repository.
- Test both an already-compliant repository and a non-compliant repository.
- Re-run after the first successful application to confirm idempotency.
- If the convention has settings, exercise at least one non-default settings case.

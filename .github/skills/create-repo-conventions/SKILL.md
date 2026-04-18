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
	- path: ../dotnet-style
	- path: ../license-files
```

## Writing `convention.ps1`

- The script runs with `pwsh` from the root of the target Git repository, not from the convention directory.
- The script receives one argument: the path to a JSON file.
- The JSON payload contains a single `settings` property.
- Read settings from that payload file; do not expect additional arguments or special environment state.
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

param(
	[Parameter(Mandatory = $true)]
	[string] $PayloadPath
)

$payload = Get-Content -Raw $PayloadPath | ConvertFrom-Json
$settings = $payload.settings

# Inspect the target repository and apply only the required changes.
```

## Behavioral Constraints

- On success, repo-conventions will auto-commit tracked or untracked changes left behind by the executable convention.
- On failure, repo-conventions will hard-reset the target repository back to the pre-convention HEAD.
- Do not create formatting-only churn unless formatting is the actual purpose of the convention.

## Documentation

- Always include a `README.md` in the convention directory documenting the convention's purpose, supported settings, and any required tools or frameworks.

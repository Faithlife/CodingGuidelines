---
name: create-repo-conventions
description: Create or update conventions that are published by this repository.
---

# Create Repo Conventions

Use this skill when authoring or updating published convention directories that other repositories consume through repo-conventions.

## Goal

Produce conventions with a stable published path, documented settings, and idempotent behavior that matches the repo-conventions contract.

## When To Use This Skill

- Use this skill when creating a new published convention directory.
- Use this skill when editing `convention.yml`, `convention.ps1`, a convention-local `README.md`, or files that support those conventions.
- Do not use this skill to wire a consuming repository up to existing conventions. Use `use-repo-conventions` for that.

## Convention Model

- A published convention directory may contain `convention.yml`, `convention.ps1`, or both.
- If both files exist, repo-conventions applies `convention.yml` first and then executes `convention.ps1`.
- Composite conventions are for composing other conventions.
- Executable conventions are for inspecting repository state and rewriting files.
- Convention references may carry `settings`, including propagated child settings resolved from parent settings in composite conventions.
- See `docs/authoring-conventions.md` for the full authoring contract.

## Authoring Workflow

- Define the policy boundary first. Prefer one coherent convention over a grab bag of unrelated changes.
- Decide whether the convention should be composite, executable, or both.
- Inspect existing published conventions in the repository before introducing new structure or terminology.
- Put the convention in the repository's established convention location instead of inventing a new layout for a one-off change.
- Keep the public surface small: stable path, clearly named settings, predictable outputs.
- Update documentation in the same change when the convention behavior or supported inputs change.

## Writing `convention.yml`

- Use `convention.yml` when the convention is purely composition.
- Keep entries in the intended application order.
- Use explicit local relative paths for conventions published from the same repository.
- Keep settings shallow and JSON-serializable.
- When propagating parent settings into child settings, use the supported `${{ settings.foo.bar }}` syntax.
- Use `${{ readText("path") }}` only when the convention genuinely needs file-backed text in child settings.

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
- Convention scripts are encouraged to create their own informative commits when the convention naturally consists of multiple meaningful steps or when the resulting history matters for follow-up tasks such as blame-ignore files.

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

- On success, if the script does not create commits itself, repo-conventions will auto-commit tracked or untracked changes left behind by the executable convention.
- On failure, repo-conventions will hard-reset the target repository back to the pre-convention HEAD.
- Do not create formatting-only churn unless formatting is the actual purpose of the convention.

## Documentation

- Always include a `README.md` in the convention directory documenting the convention's purpose, supported settings, and any required tools or frameworks.
- Keep repository-level consumer docs focused on using conventions; put authoring details in convention-local docs or `docs/authoring-conventions.md`.

## Testing

- Test the convention with Pester if possible.
- Put Pester tests in the same directory as the convention they cover, e.g. `conventions/my-convention/convention.Tests.ps1`.
- Verify behavior against a clean temporary repository.
- Test both an already-compliant repository and a non-compliant repository.
- Re-run after the first successful application to confirm idempotency.
- If the convention has settings, exercise at least one non-default settings case.

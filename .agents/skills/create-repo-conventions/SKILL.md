---
name: create-repo-conventions
description: Create or update published repo-conventions convention directories, including convention.yml, convention.ps1, convention-local README.md, settings, tests, and supporting files.
---

# Create Repo Conventions

Use this guide when authoring or updating convention directories consumed by RepoConventions. It is both a human-readable authoring reference and an AI-agent workflow for safe, idempotent convention changes.

## Goal

Produce conventions with stable paths, documented settings, predictable output, and idempotent behavior that matches the RepoConventions execution contract.

## When To Use This Skill

- Use this skill when creating a new published convention directory.
- Use this skill when editing `convention.yml`, `convention.ps1`, a convention-local `README.md`, or files that support those conventions.

## Authoring Checklist

- Define the policy boundary first. Prefer one coherent convention over a grab bag of unrelated changes.
- Inspect existing published conventions in the repository before introducing new structure or terminology.
- Choose whether the convention is composite, executable, or both.
- Keep the public surface small: stable path, clearly named settings, predictable outputs.
- Write or update the convention-local `README.md` in the same change.
- Test the non-compliant case, the already-compliant case, and a second successful run for idempotency.

## Directory Model

- A published convention directory may contain `convention.yml`, `convention.ps1`, or both.
- If both files exist, repo-conventions applies `convention.yml` first and then executes `convention.ps1`.
- `convention.yml` composes child conventions and can provide pull request settings.
- `convention.ps1` inspects or rewrites the target repository.
- `README.md` documents the convention for consumers.
- Supporting files may be read by the script or by settings expressions.

Recommended layout:

```text
conventions/my-convention/
  README.md
  convention.yml
  convention.ps1
  convention.Tests.ps1
  files/
    supporting-file.txt
```

## `convention.yml`

Use `convention.yml` when a convention composes other conventions, provides default settings for local pull requests, or both.

Composition-only conventions must include a `conventions` sequence. Executable conventions that also contain `convention.ps1` may omit `conventions` and include only `pull-request` settings.

Example:

```yaml
conventions:
  - path: ../dotnet-sdk
    settings:
      version: 10
  - path: ../dotnet-slnx
```

Guidelines:

- Keep child conventions in the order they should be applied.
- Use explicit local relative paths, such as `../dotnet-sdk`, for conventions published from the same repository.
- Keep settings JSON-compatible: objects, arrays, strings, numbers, booleans, or null.
- Keep settings shallow unless nesting communicates a real domain boundary.
- Avoid formatting-only churn in generated files unless formatting is the purpose of the convention.

### Child Paths

Child paths use the same forms as repository configuration:

- `./child` or `../child` resolves relative to the YAML file that contains the reference.
- `/child` resolves from the root of the repository that contains that YAML file.
- Remote paths use `owner/repo/path@ref`.

Local paths must stay inside the repository that contains the YAML file. This rule applies to conventions checked into the target repository and to convention repositories cloned from GitHub.

### Child Settings Expressions

Composite conventions can map parent settings into child settings with expressions.

`settings` lookup:

```yaml
conventions:
  - path: ../dotnet-sdk
    settings:
      version: ${{ settings.sdk.version }}
```

- Reads a dotted property path from the parent convention's settings object.
- When the whole value is one expression, preserves JSON-compatible types such as strings, numbers, booleans, arrays, objects, and null.
- When embedded in a larger string, converts strings directly, null to `null`, and arrays or objects to compact JSON.
- Missing values are omitted from object properties and array items. If the missing expression is embedded in a larger string, it contributes an empty string.
- If an array expression is used as an array item, its items are spliced into the destination array.

`readText("path")`:

```yaml
conventions:
  - path: ../write-file
    settings:
      body: ${{ readText("./body.txt") }}
```

- Reads UTF-8 text from a file. A UTF-8 BOM is ignored.
- Relative paths resolve from the YAML file that contains the expression.
- Paths beginning with `/` resolve from the root of the repository that contains the YAML file.
- Native absolute paths and paths that escape the containing repository are rejected.
- Use it when file-backed text is clearer than embedding long YAML strings.

### Pull Request Metadata

`convention.yml` can include `pull-request` settings:

```yaml
pull-request:
  labels:
    - dependencies
  auto-merge: true
  merge-method: squash
```

This metadata is applied only when the convention contributes commits to a `--open-pr` run. It is honored whether the convention is stored in the target repository or cloned from a remote repository. Consumers can supplement list values and override scalar values on their own convention reference or top-level configuration.

Supported properties are `labels`, `reviewers`, `assignees`, `draft`, `auto-merge`, and `merge-method`. For complete consumer-side behavior and CLI overrides, see [../../README.md](../../README.md).

## `convention.ps1`

Use `convention.ps1` when the convention must inspect repository state, run tools, or rewrite files.

Execution contract:

- The script runs with `pwsh -NoProfile`.
- The current working directory is the target Git repository root, not the convention directory.
- The first argument is the path to a JSON input file.
- Use `$args[0]` to access the input path so future arguments do not break the script.
- The JSON input file contains a single `settings` property.
- RepoConventions captures stdout and stderr as UTF-8. Set `[Console]::OutputEncoding` before invoking native tools so their output is emitted as UTF-8 too.

Standard header for `convention.ps1`:

```pwsh
#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
```

Then, if settings are used:

```pwsh
$conventionInput = Get-Content -Raw $args[0] | ConvertFrom-Json
$settings = $conventionInput.settings
```

Authoring expectations:

- Read the JSON input only when settings are needed.
- Make the script idempotent. A second successful run should produce no further changes.
- Exit with code zero when the repository is already compliant or after successfully making it compliant.
- Use a non-zero exit code only when the convention genuinely cannot complete.
- Avoid interactive prompts, editor launches, global machine-local state, and hidden credentials.
- Prefer deterministic file writes, stable ordering, and stable line endings.
- Emit focused output that explains what changed or why the convention cannot continue.
- If the convention naturally consists of multiple meaningful steps, the script may create its own commits with informative messages.

## Commit and Failure Behavior

- On success, if `convention.ps1` leaves tracked or untracked changes and does not create commits itself, RepoConventions creates `Apply convention <name>`.
- If the script creates commits itself, RepoConventions preserves those commits.
- If the convention leaves no changes or new commits, RepoConventions does not add a commit for that convention.
- If the script exits with a non-zero code, RepoConventions hard-resets the target repository to the commit before that convention started and stops the run.
- RepoConventions builds the convention plan before applying any convention, so path and settings-expression errors prevent partial application.

## Documentation

Always include a `README.md` in the convention directory. Document:

- what the convention does
- every supported setting, including defaults and examples
- required tools, frameworks, or repository assumptions
- notable files the convention creates, rewrites, or commits
- any important limitations or follow-up steps for consumers

Keep repository-level consumer docs focused on using RepoConventions.

## Testing

- Test the convention with Pester if possible.
- Put Pester tests in the same directory as the convention they cover, e.g. `conventions/my-convention/convention.Tests.ps1`.
- Prefer new temporary repositories with no preexisting tracked or untracked file changes so tests exercise real files, git state, and command behavior.
- Test both an already-compliant repository and a non-compliant repository.
- Re-run after the first successful application to confirm idempotency.
- If the convention has settings, exercise at least one non-default settings case.
- Test failure paths when settings are required or external tools may be unavailable.

## Agent Workflow

When an AI agent updates a convention:

- Read the existing convention directory and nearby conventions first.
- Preserve the published path and setting names unless the user explicitly requests a breaking change.
- Update `convention.yml`, `convention.ps1`, local docs, and tests as one coherent change.
- Prefer small, deterministic scripts over broad repository rewrites.
- Validate by running the narrowest meaningful tests, then the repository's required final test command when appropriate.

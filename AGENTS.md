# Agent Instructions

## PowerShell Scripts

PowerShell scripts should start with this header:

```pwsh
#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
```

- DO NOT use hyphens in PowerShell function names local to a script, but DO use hyphens and approved PowerShell verbs in functions in a script that are designed to be used by other scripts.
- Convention scripts are invoked with `$args[0]` set to a valid convention input JSON path. Do not check `$args.Count`, validate `$args[0]`, or assign `$args[0]` to a local variable just to pass it once.
- Always use `ConvertFrom-Json -AsHashtable`.
- Don't nest `Join-Path` calls, i.e. use `Join-Path A B C`, not `Join-Path (Join-Path A B) C`.
- Each paragraph of PowerShell code should have a one-line descriptive comment.
- Write UTF-8 files with `[System.IO.File]::WriteAllText($path, $content, $utf8)`.

## Pester

- Only run one Pester test script at a time.
- When running `Invoke-Pester`, do not use `-Output`. Just use `Invoke-Pester -Path <script>`.
- `Invoke-Pester` can report failed tests while the PowerShell command itself exits with code 0. Read the Pester summary, not just the terminal exit code, unless the repo-specific runner converts failures into a non-zero exit.
- VS Code terminal notifications may report long-running Pester scripts as waiting for input even when no prompt is present. Inspect the terminal output before sending input; many repo-conventions tests are quiet for 10-20 seconds while child processes run.
- `conventions/RunAllTests.ps1` covers convention tests under `conventions/` and `.github/conventions/`.

## Markdown

- Use `./path/file.md` when linking to a sibling or descendant, not `path/file.md`.
- Prefer unordered lists to tables unless three or more columns are needed.

## Convention READMEs

- Every convention directory must have a local `README.md` that documents the consumer-facing contract for that convention.
- Start with the convention name as the main heading, followed by a concise first paragraph that describes what files or repository state the convention manages. The root README conventions table is generated from this paragraph.
- Include a `Settings` section when the convention accepts settings. Document every setting, whether it is required or optional, valid values, defaults, and important validation rules.
- Do not state explicitly when a convention does not support settings; that's implied by the lack of documentation for them.
- Document notable behavior in a `Behavior` section without getting too deep into specifics. Focus on WHY, not precisely WHAT.
- For composite conventions, don't enumerate the child conventions in the `Behavior` section, but do summarize the main effects.
- Include an `Example` or `Examples` section at the end with a minimal YAML usage example using the published path. For settings-based conventions, show a realistic settings example.
- Don't mention implementation details that are irrelevant to consumers. For example, do not mention the exact commit message used; that's the WHAT, not the WHY.

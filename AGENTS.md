# Agent Instructions

## PowerShell Scripts

- In PowerShell scripts, DO NOT use hyphens in function names local to a script, but DO use hyphens and approved PowerShell verbs in functions in a script that are designed to be used by other scripts.
- Convention scripts are invoked with `$args[0]` set to a valid convention input JSON path. Do not check `$args.Count`, validate `$args[0]`, or assign `$args[0]` to a local variable just to pass it once.
- Always use `ConvertFrom-Json -AsHashtable`.
- PowerShell scripts define a no-BOM UTF-8 `$utf8` encoding in the standard header. Write UTF-8 files with `[System.IO.File]::WriteAllText($path, $content, $utf8)`.
- Don't nest `Join-Path` calls, i.e. use `Join-Path A B C`, not `Join-Path (Join-Path A B) C`.
- Each paragraph of PowerShell code should have a one-line descriptive comment.

## Pester

- Only run one Pester test script at a time.
- When running `Invoke-Pester`, do not use `-Output`. Just use `Invoke-Pester -Path <script>`.
- `Invoke-Pester` can report failed tests while the PowerShell command itself exits with code 0. Read the Pester summary, not just the terminal exit code, unless the repo-specific runner converts failures into a non-zero exit.

## Test Running

- VS Code terminal notifications may report long-running Pester scripts as waiting for input even when no prompt is present. Inspect the terminal output before sending input; many repo-conventions tests are quiet for 10-20 seconds while child processes run.
- `conventions/RunAllTests.ps1` covers convention tests under `conventions/` and `.github/conventions/`.

## Convention READMEs

- Every convention directory must have a local `README.md` that documents the consumer-facing contract for that convention.
- Start with the convention name as the H1, followed by a concise first paragraph that describes what files or repository state the convention manages. The root README conventions table is generated from this paragraph.
- Do not link to RepoConventions in each convention description; keep those links in broader usage documentation instead.
- Include a `Settings` section when the convention accepts settings. Document every setting, whether it is required or optional, valid values, defaults, and important validation rules.
- State explicitly when a convention does not support settings.
- Document notable behavior: files created or replaced, managed section marker names, generated assets, external tools invoked, commits the script creates itself, and conditions that cause the convention to skip or fail.
- For composite conventions, list the child conventions or summarize the main effects so consumers do not have to read `convention.yml` to understand the result.
- Include a minimal YAML usage example with the published path. For settings-based conventions, show a realistic settings example.
- Keep implementation details out unless they affect consumers, and update the README in the same change as `convention.yml`, `convention.ps1`, packaged files, or tests.

# AGENTS

Repository instructions for automated coding agents.

- In PowerShell scripts, DO NOT use hyphens in function names local to a script, but DO use hyphens and approved PowerShell verbs in functions in a script that are designed to be used by other scripts.
- Convention scripts are invoked with `$args[0]` set to a valid convention input JSON path. Do not check `$args.Count`, validate `$args[0]`, or assign `$args[0]` to a local variable just to pass it once.
- Always use `ConvertFrom-Json -AsHashtable`.
- PowerShell scripts define a no-BOM UTF-8 `$utf8` encoding in the standard header. Write UTF-8 files with `[System.IO.File]::WriteAllText($path, $content, $utf8)` instead of adding a shared file-write helper.
- Only run one Pester test script at a time.
- When running `Invoke-Pester`, do not use `-Output`. Just use `Invoke-Pester -Path <script>`.
- VS Code terminal notifications may report long-running Pester scripts as waiting for input even when no prompt is present. Inspect the terminal output before sending input; many repo-conventions tests are quiet for 10-20 seconds while child processes run.
- `Invoke-Pester` can report failed tests while the PowerShell command itself exits with code 0. Read the Pester summary, not just the terminal exit code, unless the repo-specific runner converts failures into a non-zero exit.
- `conventions/RunAllTests.ps1` covers convention tests under `conventions/` and `.github/conventions/`, but use a file search for `*.Tests.ps1` when the task asks for all tests so any other test locations are not missed.
- When a test says a generated or published file is out of sync, prefer running the repository's generator script over hand-editing the generated file.

# AGENTS

Repository instructions for automated coding agents.

- In PowerShell scripts, DO NOT use hyphens in function names local to a script, but DO use hyphens and approved PowerShell verbs in functions in a script that are designed to be used by other scripts.
- Only run one Pester test script at a time.
- When running `Invoke-Pester`, do not use `-Output`. Just use `Invoke-Pester -Path <script>`.
- When a helper function needs to configure PowerShell state for later native commands, remember that ordinary variable assignment inside the function is local. Use the appropriate caller scope, e.g. `$script:OutputEncoding`, when the convention script must keep the value after the helper returns.
- For convention scripts that pipe instructions or other text into native CLIs, set `[Console]::InputEncoding`, `[Console]::OutputEncoding`, and `$script:OutputEncoding` before invoking the tool so both console output and native stdin use UTF-8.
- VS Code terminal notifications may report long-running Pester scripts as waiting for input even when no prompt is present. Inspect the terminal output before sending input; many repo-conventions tests are quiet for 10-20 seconds while child processes run.
- `Invoke-Pester` can report failed tests while the PowerShell command itself exits with code 0. Read the Pester summary, not just the terminal exit code, unless the repo-specific runner converts failures into a non-zero exit.
- `conventions/RunAllTests.ps1` covers convention tests under `conventions/`, but it does not cover every Pester test in the repository. Use a file search for `*.Tests.ps1` when the task asks for all tests.
- When a test says a generated or published file is out of sync, prefer running the repository's generator script over hand-editing the generated file.

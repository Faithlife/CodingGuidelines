# AGENTS

Repository instructions for automated coding agents.

- In PowerShell scripts, DO NOT use hyphens in function names local to a script, but DO use hyphens and approved PowerShell verbs in functions in a script that are designed to be used by other scripts.
- Only run one Pester test script at a time.
- When running `Invoke-Pester`, do not use `-Output`. Just use `Invoke-Pester -Path <script>`.
- When a helper function needs to configure PowerShell state for later native commands, remember that ordinary variable assignment inside the function is local. Use the appropriate caller scope, e.g. `$script:OutputEncoding`, when the convention script must keep the value after the helper returns.
- For convention scripts that pipe instructions or other text into native CLIs, set `[Console]::InputEncoding`, `[Console]::OutputEncoding`, and `$script:OutputEncoding` before invoking the tool so both console output and native stdin use UTF-8.
- If a convention helper must preserve a native CLI's UTF-8 stdout/stderr exactly, do not pipe the native command through PowerShell. Prefer `System.Diagnostics.ProcessStartInfo` with redirected stdin only and inherited stdout/stderr so PowerShell cannot decode and re-encode the tool's output.
- On Windows, `Get-Command copilot` may resolve to VS Code's `copilot.ps1` bootstrapper before the real Copilot executable. If preserving Copilot output matters, resolve past the PowerShell bootstrapper to an application outside the bootstrapper directory, preferably `copilot.exe`.
- VS Code terminal notifications may report long-running Pester scripts as waiting for input even when no prompt is present. Inspect the terminal output before sending input; many repo-conventions tests are quiet for 10-20 seconds while child processes run.

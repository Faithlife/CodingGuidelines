# Remove Invoke-CopilotWithIsolatedConfig

Plan for removing `Invoke-CopilotWithIsolatedConfig` and replacing the current agent handoffs with deterministic PowerShell behavior.

## Goal

Remove all runtime dependency on the Copilot CLI for conventions that currently call `Invoke-CopilotWithIsolatedConfig`, while preserving the convention outcomes that matter to repositories.

The build-fix portion of the current `dotnet-sdk` instruction should be dropped. The convention should update `global.json` only; if changing the SDK causes build breakage, the repository owner is responsible for fixing it.

## Current Scope

The helper is defined in [../conventions/scripts/Helpers.ps1](../conventions/scripts/Helpers.ps1). It is currently used by:

- [../conventions/dotnet-sdk/convention.ps1](../conventions/dotnet-sdk/convention.ps1) to ask Copilot to create or update `global.json`.
- [../conventions/gitattributes-lf/convention.ps1](../conventions/gitattributes-lf/convention.ps1) to ask Copilot to repair an existing `.gitattributes` file before line-ending renormalization.

Related tests and test helpers to adjust:

- [../conventions/scripts/Helpers.Tests.ps1](../conventions/scripts/Helpers.Tests.ps1) tests the isolated Copilot invocation and should be deleted or repurposed once the helper is removed.
- [../conventions/scripts/TestHelpers.ps1](../conventions/scripts/TestHelpers.ps1) contains fake Copilot command helpers used by helper tests and repo-conventions apply tests.
- [../conventions/dotnet-sdk/convention.Tests.ps1](../conventions/dotnet-sdk/convention.Tests.ps1) stubs `copilot` for missing `global.json` cases.
- [../conventions/gitattributes-lf/convention.Tests.ps1](../conventions/gitattributes-lf/convention.Tests.ps1) stubs `copilot` for noncompliant `.gitattributes` cases.

Do not remove unrelated references to Copilot in `copilot-lsp`, `copilot-lsp-csharp`, or `apm-install`; those conventions manage Copilot configuration or install packages for the Copilot APM target and do not use this helper.

## Viability Of Deterministic PowerShell

This change is viable. The current prompts ask Copilot to perform tightly bounded file edits that are straightforward to express as deterministic PowerShell.

For `dotnet-sdk`, the current instruction says to:

- Create `global.json` when missing.
- Ensure `sdk.version` is `$majorVersion.0.100`.
- Ensure `sdk.rollForward` is `latestFeature`.
- Preserve unrelated properties in `global.json`.
- Modify no files other than `global.json`.
- Build the repository and repair build breaks.

PowerShell can deterministically implement every item except the build-and-repair loop. That loop should be intentionally removed. The resulting convention will be more predictable and will not need a model, tool permissions, temporary Copilot state, or build heuristics.

For `gitattributes-lf`, the current instruction says to:

- Make the first line exactly `* text=auto eol=lf`.
- Move that line to the first line if it already exists later.
- Remove every other rule containing `eol=`.
- Remove redundant repository-wide newline rules made obsolete by the required first line, including `* text=auto` and `* -text`.
- Preserve rules that are not about line endings.
- Modify no files other than `.gitattributes`.
- Leave the working tree unstaged before the convention stages its own commits.

PowerShell can deterministically implement all of this with line-based filtering because `.gitattributes` is already line-oriented and the convention only needs to manage repository-wide newline policy. The main judgment call is preserving comments and blank lines. The recommended implementation should preserve non-removed comments and rules, remove duplicate required rules, and avoid adding extra blank lines at the top.

## Implementation Steps

- Update [../conventions/dotnet-sdk/convention.ps1](../conventions/dotnet-sdk/convention.ps1):
  - Replace `$copilotInstructions` and `Invoke-CopilotWithIsolatedConfig` with a local function such as `SetGlobalJsonSdkVersion`.
  - Parse existing `global.json` with `ConvertFrom-Json -AsHashtable` when it exists.
  - Treat malformed or non-object JSON as nonconforming and replace it with a minimal valid object.
  - Ensure the top-level `sdk` value is a hashtable.
  - Set `sdk.version` to `$majorVersion.0.100` and `sdk.rollForward` to `latestFeature`.
  - Preserve unrelated top-level properties and unrelated `sdk` properties.
  - Write the file with `ConvertTo-Json -Depth 100` and `[System.IO.File]::WriteAllText(..., $utf8)`.
  - Change output from `starting Copilot` to deterministic wording such as `updating global.json`.
  - Keep the existing post-write `GetGlobalJsonSdkStatus` validation.

- Update [../conventions/gitattributes-lf/convention.ps1](../conventions/gitattributes-lf/convention.ps1):
  - Replace `InvokeCopilotForGitattributesRepair` with a deterministic repair function such as `SetGitattributesLfRule`.
  - If `.gitattributes` is missing, keep the existing create behavior.
  - If `.gitattributes` exists but is noncompliant, read all lines.
  - Build a new line list starting with `* text=auto eol=lf`.
  - Skip later lines that exactly equal the required rule.
  - Skip rules containing `eol=`.
  - Skip obsolete repository-wide rules such as `* text=auto` and `* -text`.
  - Preserve all other lines, including comments, blank lines, and non-line-ending rules.
  - Write the result with a single final LF newline.
  - Keep the existing post-repair `TestConformingGitattributes` validation.
  - Preserve the existing commit flow: `Use LF`, `Convert CRLF to LF`, update `.git-blame-ignore-revs`, and final reset.

- Remove the shared helper:
  - Delete `Invoke-CopilotWithIsolatedConfig` from [../conventions/scripts/Helpers.ps1](../conventions/scripts/Helpers.ps1).
  - Keep `New-TemporaryDirectory` because it is used by tests and other helpers.
  - Delete [../conventions/scripts/Helpers.Tests.ps1](../conventions/scripts/Helpers.Tests.ps1) if it only tests the removed helper after the implementation change.

- Clean up test-only Copilot helpers:
  - Search for `New-TestCopilotCommand` and `New-TemporaryTestCopilotCommand` after removing helper tests.
  - If no remaining tests need fake Copilot commands, remove those functions from [../conventions/scripts/TestHelpers.ps1](../conventions/scripts/TestHelpers.ps1).
  - If repo-conventions apply tests still need a command on `PATH` for unrelated conventions, keep only the minimal helper they use and rename it away from Copilot-specific behavior only if that improves clarity.

- Update tests:
  - In [../conventions/dotnet-sdk/convention.Tests.ps1](../conventions/dotnet-sdk/convention.Tests.ps1), remove `global:copilot` stubs and assert direct `global.json` output for missing, lower-version, malformed, and preserve-extra-properties scenarios.
  - In [../conventions/gitattributes-lf/convention.Tests.ps1](../conventions/gitattributes-lf/convention.Tests.ps1), remove `global:copilot` stubs and assert deterministic repair of redundant `eol=` rules, duplicate required rules, obsolete repository-wide rules, comments, blank lines, and preserved binary/custom rules.
  - Remove output assertions that say `starting Copilot` and replace them with the new deterministic messages.
  - Keep idempotence tests for both conventions.

- Update docs only if behavior text becomes misleading:
  - [../conventions/dotnet-sdk/README.md](../conventions/dotnet-sdk/README.md) already describes the desired deterministic behavior and probably does not need a change.
  - [../conventions/gitattributes-lf/README.md](../conventions/gitattributes-lf/README.md) already describes the desired deterministic behavior and probably does not need a change.

## Suggested Order

- First, implement deterministic `dotnet-sdk` and its tests. This is the smallest replacement and proves the pattern.
- Next, implement deterministic `.gitattributes` repair and update its tests. This has more edge cases and affects commit history behavior.
- Then remove `Invoke-CopilotWithIsolatedConfig` and any unused fake Copilot test helpers.
- Finally, run focused Pester tests and then the full convention suite.

## Verification

Run these focused tests first:

```pwsh
Invoke-Pester -Path ./conventions/dotnet-sdk/convention.Tests.ps1
Invoke-Pester -Path ./conventions/gitattributes-lf/convention.Tests.ps1
Invoke-Pester -Path ./conventions/scripts/Helpers.Tests.ps1
```

If [../conventions/scripts/Helpers.Tests.ps1](../conventions/scripts/Helpers.Tests.ps1) is deleted, omit that command.

Then run the full convention suite:

```pwsh
./conventions/RunAllTests.ps1
```

## Risks And Decisions

- JSON formatting will change when rewriting `global.json`. That is acceptable unless preserving exact formatting becomes a requirement. Preserving data is more important than preserving whitespace.
- PowerShell hashtables may not preserve property ordering exactly as the original JSON. If stable ordering matters, write `sdk` first for newly created files and accept existing-order differences for repaired files.
- `.gitattributes` line filtering must be conservative. Only remove lines that clearly match the current Copilot prompt requirements: the required rule duplicate, any rule containing `eol=`, and exact obsolete repository-wide rules.
- The convention will no longer try to build or repair source code after changing `global.json`. This is an intentional behavior change and should be reflected in tests by asserting only `global.json` content and conformity.

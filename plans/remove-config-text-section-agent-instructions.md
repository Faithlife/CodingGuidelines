# Remove Config Text Section Agent Instructions

## Goal

Remove Copilot agent-instruction support from `config-text-section`. Move the useful `.editorconfig` cleanup behavior into `editorconfig-section` so applying editorconfig conventions is deterministic and does not invoke an agent. Do not preserve the C# build-and-fix behavior; after this change, validating or fixing builds is the user's responsibility.

## Current State

- `conventions/config-text-section` accepts `settings.agent.instructions` and invokes Copilot after it changes the target file.
- `conventions/editorconfig-section` is a thin composite wrapper over `config-text-section` and forwards `settings.agent` directly.
- The editorconfig wrapper conventions (`editorconfig-root`, `editorconfig-csharp`, `editorconfig-json`, `editorconfig-md`, `editorconfig-ps1`, and `editorconfig-yaml`) pass file-backed `agent-instructions.md` content through `editorconfig-section`.
- Those instruction files mostly ask the agent to remove redundant unmanaged `.editorconfig` rules after the managed section changes.
- `editorconfig-csharp/agent-instructions.md` also asks the agent to build .NET solutions and fix failures; this step should be removed rather than automated.

## Desired Behavior

- `config-text-section` only manages named text sections. It should no longer parse `agent`, validate `agent.instructions`, invoke Copilot, or reconcile agent edits.
- `editorconfig-section` should still write the configured managed section, then deterministically clean redundant unmanaged `.editorconfig` content that is made unnecessary by the managed section.
- Managed `DO NOT EDIT` sections must remain authoritative and untouched except for the target section that is being applied.
- Cleanup should leave intentional, non-redundant unmanaged `.editorconfig` rules alone.
- The root editorconfig section should be first when `name` is `root`.
- Redundant `root = true` outside the managed `root` section should be removed.
- For unmanaged `[*]` sections, remove `indent_size`, `indent_style`, `tab_width`, and `insert_final_newline` when applying the `root` section, and remove an empty `[*]` section left behind by that cleanup.
- The convention should never build C# projects or invoke tools to repair source after editorconfig changes.

## Implementation Options

### PowerShell Cleanup

Pros:

- Matches the current convention implementation style and test harness.
- Adds no runtime dependency beyond PowerShell, which every executable convention already requires.
- Keeps the convention useful for non-.NET repositories where a .NET SDK may not be installed.
- Makes it straightforward to preserve existing file text, line endings, comments, and managed blocks because the script can work line-by-line on the original file.

Cons:

- Rich `.editorconfig` semantics are awkward in PowerShell, especially glob coverage and section precedence.
- A broad cleanup algorithm could become hard to read and easy to over-apply.
- Complex parsing code will need careful tests for comments, blank lines, duplicate properties, malformed sections, and managed-block boundaries.

### C# Helper Run From PowerShell

Pros:

- Better language support for modeling parsed lines, sections, properties, and rewrite decisions.
- Easier to write and maintain a small parser/rewrite engine if cleanup grows beyond simple line-oriented rules.
- Can be unit tested more naturally if it becomes a standalone helper rather than inline script logic.

Cons:

- Running C# from a convention introduces bootstrapping complexity: compiling with `Add-Type`, generating a temporary project, or running a checked-in helper all add moving parts.
- Using `dotnet run` or `dotnet build` for the helper would require a .NET SDK in target repositories and could be affected by the target repository's `global.json` or NuGet configuration.
- Restore/compile time would make a small editorconfig convention noticeably heavier.
- It is easy for consumers to confuse a C# helper build with the C# project build behavior that this plan intentionally removes.

### `EditorConfig.Core.EditorConfigParser`

`C:\Code\EditorConfigFix` has a concrete example of using the `editorconfig` NuGet package. It references `editorconfig` version `0.15.0`, calls `EditorConfigFile.Parse` to load discovered `.editorconfig` files, and uses `new EditorConfigParser().Parse(fullPath, editorConfigFiles)` to resolve effective settings for a target file. It also uses `ConfigSection.Glob` plus `GlobMatcher` to identify matching sections.

Pros:

- Uses an existing parser for `.editorconfig` syntax instead of fully hand-rolling parsing.
- Could help validate section/property parsing and reduce bugs in interpreting ordinary editorconfig files.
- If future behavior needs actual editorconfig property resolution, a library is preferable to recreating the full spec.
- The `EditorConfigFix` example gives us a known working package version and API shape if we later choose a C# helper.

Cons:

- The cleanup needs a source-preserving rewrite: keep comments, blank lines, line endings, managed block boundaries, and unrelated formatting. A parser focused on editorconfig interpretation is unlikely to provide the exact trivia-preserving edit model needed here.
- The library does not remove the need for custom logic to decide whether one unmanaged section is redundant with a managed section.
- Adding a NuGet package means runtime restore or vendoring a dependency, both of which are a poor fit for a lightweight published convention.
- A NuGet restore can depend on network access and target-repository package configuration, making convention application less deterministic.
- The `EditorConfigFix` usage resolves settings for ordinary target files; it does not demonstrate rewriting `.editorconfig` files while preserving source trivia.

Recommendation:

- Keep `editorconfig-section` as a PowerShell convention for this change.
- Keep the first deterministic cleanup intentionally conservative: remove only mechanically safe redundant rules, such as exact property/value duplicates in the same unmanaged section header as the managed section and the explicit `root`/`[*]` cases listed above.
- Do not use `EditorConfig.Core.EditorConfigParser` for the first implementation because the main problem is safe source rewriting, not just parsing or effective-setting resolution.
- Reconsider a small C# helper only if the cleanup scope expands to require deeper editorconfig semantics or the PowerShell parser becomes difficult to test and review. If that happens, use the `EditorConfigFix` package usage as the reference point, prefer a checked-in helper with clear SDK expectations, and avoid runtime NuGet restore during convention application.

## Implementation Plan

- Replace `conventions/editorconfig-section/convention.yml` with executable behavior, likely by adding `convention.ps1` while preserving the published `editorconfig-section` path.
- Reuse the shared section-writing implementation where practical, but expose it in a way that lets `editorconfig-section` post-process `.editorconfig` content without using `settings.agent`.
- Remove `Get-ConfigTextSectionAgentInstructions`, `Get-ConfigTextSectionAgent`, the `agent` parsing in `Invoke-ConfigTextSection`, and the Copilot invocation/reconciliation block from `conventions/scripts/ConfigTextSection.ps1`.
- Update `conventions/config-text-section/convention.ps1` only if needed to match any helper signature changes.
- Implement `.editorconfig` parsing helpers for `editorconfig-section` that can identify:
  - managed blocks bounded by `# DO NOT EDIT: <name> convention` and `# END DO NOT EDIT`
  - unmanaged section headers such as `[*]` and `[*.cs]`
  - property assignments inside each section
  - blank/comment-only sections that become removable after cleanup
- Implement redundant-rule cleanup conservatively:
  - compare unmanaged rules against the target managed section's rules
  - remove unmanaged assignments with the same property name and value when they appear under the same section header as a section in the managed target section
  - remove unmanaged sections only when all remaining lines are blank or comments after rule removal
  - never remove rules or sections inside any managed block
  - preserve line endings and surrounding content as much as possible
- Special-case `name: root` cleanup for root-wide rules:
  - ensure the managed `root` block appears before all unmanaged and managed `.editorconfig` sections
  - remove unmanaged `root = true`
  - apply the `[*]` broad-rule cleanup described above
- Remove `agent` forwarding from `editorconfig-section` and remove `agent:` settings from the editorconfig wrapper `convention.yml` files.
- Delete the now-unused editorconfig `agent-instructions.md` files once their deterministic behavior is covered by tests.

## Tests

- Update `conventions/config-text-section/convention.Tests.ps1`:
  - remove tests that stub or assert Copilot invocation
  - remove tests for missing, null, empty, whitespace, and non-string `agent.instructions`
  - add or update a test showing `agent` is no longer part of the public behavior; decide during implementation whether unsupported `agent` is ignored for compatibility or rejected as an unknown setting if the convention has an established unknown-setting policy
  - keep creation, replacement, idempotency, path resolution, marker validation, suffix, and preservation tests
- Update `conventions/editorconfig-section/convention.Tests.ps1`:
  - replace the pass-through agent test with deterministic redundant-rule cleanup tests
  - test that managed sections are never modified by cleanup
  - test idempotency after cleanup by applying the convention twice
  - test native commit settings still work when `.editorconfig` changes
- Add focused cleanup scenarios for each behavior formerly described by agent instructions:
  - root section moves before other sections
  - duplicate unmanaged `root = true` is removed
  - redundant unmanaged rules matching the managed target section are removed
  - empty unmanaged sections left by cleanup are removed
  - unmanaged `[*]` indentation/final-newline rules are removed when applying `root`
  - C# cleanup removes redundant `.editorconfig` rules but does not run `dotnet`, `build.ps1`, or Copilot
- Run only one Pester script at a time while iterating:
  - `Invoke-Pester -Path conventions/config-text-section/convention.Tests.ps1`
  - `Invoke-Pester -Path conventions/editorconfig-section/convention.Tests.ps1`
- Finish with `conventions/RunAllTests.ps1` if the focused tests pass.

## Documentation

- Update `conventions/config-text-section/README.md` to remove `agent` and `agent.instructions` settings and any Copilot behavior from the example.
- Update `conventions/editorconfig-section/README.md` only where the current documentation would become inaccurate, such as removing the `agent` setting. Do not document removed Copilot or build behavior as historical context.
- Update README files for the editorconfig wrapper conventions only if they mention agent behavior directly.
- If deleting `agent-instructions.md` files, make sure no `readText("agent-instructions.md")` references remain.

## Migration Notes

- Existing consumers that configure `settings.agent` under `config-text-section` or `editorconfig-section` will stop getting Copilot follow-up behavior.
- Existing editorconfig wrapper conventions in this repository should not require consumer changes because their internal `agent` settings will be removed.
- C# repositories may need to build manually after applying updated editorconfig conventions; this is an intentional behavior change.

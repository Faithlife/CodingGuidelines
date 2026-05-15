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
  - remove unmanaged assignments with the same property name and value when the managed section already covers the same or broader section
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
- Update `conventions/editorconfig-section/README.md` to document deterministic redundant-rule cleanup and explicitly note that it does not run builds or invoke Copilot.
- Update README files for the editorconfig wrapper conventions only if they mention agent behavior directly.
- If deleting `agent-instructions.md` files, make sure no `readText("agent-instructions.md")` references remain.

## Migration Notes

- Existing consumers that configure `settings.agent` under `config-text-section` or `editorconfig-section` will stop getting Copilot follow-up behavior.
- Existing editorconfig wrapper conventions in this repository should not require consumer changes because their internal `agent` settings will be removed.
- C# repositories may need to build manually after applying updated editorconfig conventions; this is an intentional behavior change.

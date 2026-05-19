# editorconfig-section subset rule cleanup plan

## Goal

Allow `conventions/editorconfig-section` to remove unmanaged `.editorconfig` rules when the unmanaged section is a provable subset of a managed section, not only when the section headers match exactly. The motivating case is a managed section such as `[*.{cs,cshtml,razor}]` removing duplicated rules from an unmanaged `[*.cs]` section.

## Current Behavior

- `GetManagedEditorConfigRules` parses the configured managed `text` into a dictionary keyed by exact section header, such as `[*.md]`.
- `SetRedundantEditorConfigRuleRemoval` removes an unmanaged rule only when:
  - the unmanaged line is not inside any managed block,
  - the line has a key/value pair,
  - the unmanaged line has a section header that exists exactly in the managed rules dictionary,
  - the managed section contains the same key and the same value.
- `SetEmptyEditorConfigSectionRemoval` already removes an unmanaged section when cleanup removes its only semantic rules, so the subset behavior should be able to reuse that logic.

## Proposed Approach

- Keep the existing exact-match behavior and root-specific cleanup unchanged.
- Add a small set of helpers in `convention.ps1` for conservative section subset checks:
  - normalize section headers by trimming and stripping the outer `[` and `]`, returning the raw section key,
  - expand simple comma brace alternatives into finite pattern alternatives, for example `*.{cs,cshtml,razor}` -> `*.cs`, `*.cshtml`, `*.razor`,
  - compare expanded section-key sets and treat an unmanaged section as covered when every unmanaged alternative is present in the managed alternatives.
- Use conservative matching only. If a section key contains unsupported glob constructs for subset proof, do not treat it as a subset. This avoids removing rules unless the script can clearly prove redundancy.
- Update `SetRedundantEditorConfigRuleRemoval` so that for non-root section cleanup it checks managed sections whose key covers the unmanaged section key, rather than only `ManagedRules.ContainsKey($line.SectionHeader)`.
- Preserve the existing key/value redundancy rules:
  - property names stay case-insensitive via the existing section rule dictionaries,
  - values stay ordinal/exact,
  - rules inside managed blocks remain untouched.

## Subset Semantics To Implement First

- Exact section header matches still count.
- Brace-list supersets count, including the motivating example:
  - managed `[*.{cs,cshtml,razor}]` covers unmanaged `[*.cs]`, `[*.cshtml]`, and `[*.razor]`.
- Brace-list-to-brace-list subset checks count when expansion is finite and exact:
  - managed `[*.{cs,cshtml,razor}]` covers unmanaged `[*.{cs,razor}]`.
- The first implementation will not try to solve arbitrary glob implication, such as proving `[*.generated.cs]` is a subset of `[*.cs]`, unless we explicitly decide to broaden the scope before implementation.

## Tests

Add focused Pester coverage in `conventions/editorconfig-section/convention.Tests.ps1`:

- A managed `[*.{cs,cshtml,razor}]` section removes a duplicate rule from an unmanaged `[*.cs]` section.
- If the subset section becomes empty after cleanup, the existing empty-section removal removes the `[*.cs]` section too.
- A subset section with other non-redundant rules keeps the section and removes only the duplicated key/value line.
- A non-covered section, such as unmanaged `[*.vb]` with the same key/value, is preserved.
- Re-run the convention in at least one subset cleanup test to confirm idempotency and a clean git status.

## Documentation

Update `conventions/editorconfig-section/README.md` to mention that redundant unmanaged rules are removed not only from exactly matching sections, but also from sections that are conservatively recognized as subsets of managed section keys.

## Validation

- Run only the relevant Pester test script first:

```pwsh
Invoke-Pester -Path conventions/editorconfig-section/convention.Tests.ps1
```

- If that passes, consider running the broader convention test suite before finalizing:

```pwsh
./conventions/RunAllTests.ps1
```

## Open Decision

Should `[*]` managed sections be treated as covering every other section for this cleanup? It is logically a superset, but it would broaden cleanup beyond the brace-list case that motivated the change. I recommend leaving that out of the first implementation unless you want root-wide managed rules to remove identical rules from narrower unmanaged sections.

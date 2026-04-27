# Prettierignore Detection Plan

## Goal

Change the `prettierignore-section` convention so it only manages `.prettierignore` in repositories that appear to use Prettier.

The convention should:

- Continue publishing the same convention path: `conventions/prettierignore-section`.
- Keep the existing settings surface: `name`, `text`, `agent`, and `commit`.
- Treat an existing `.prettierignore` file as enough evidence that the repository uses Prettier.
- Detect common Prettier configuration files.
- Detect Prettier listed in an NPM package manifest.
- Exit successfully without changing files when Prettier is not detected.
- Stay idempotent.

## Starting Shape

Before this change, `conventions/prettierignore-section/convention.yml` was a pure composite convention over `conventions/config-text-section`.

That works for unconditional file management, but it leaves no place to inspect the target repository before `config-text-section` creates `.prettierignore`. Adding a `convention.ps1` beside the existing `convention.yml` would not solve this, because repo-conventions applies `convention.yml` before running `convention.ps1` when both files exist.

## Recommendation

Extract the reusable section-management logic from `conventions/config-text-section/convention.ps1` into `conventions/scripts/ConfigTextSection.ps1`, then replace `conventions/prettierignore-section/convention.yml` with an executable `convention.ps1` that performs Prettier detection before calling the shared helper.

This keeps the extra policy local to `prettierignore-section`, avoids expanding the generic `config-text-section` contract for one convention, and lets both conventions share the same file rewrite, agent, and commit behavior without shelling out to another convention script.

Expected files after the change:

```text
conventions/scripts/
  ConfigTextSection.ps1

conventions/config-text-section/
  convention.ps1
  convention.Tests.ps1
  README.md

conventions/prettierignore-section/
  convention.ps1
  convention.Tests.ps1
  README.md
```

Remove `prettierignore-section/convention.yml`, because keeping it would still run `config-text-section` unconditionally.

## Detection Rules

The wrapper should consider Prettier present when any of these are true:

- `.prettierignore` exists at the repository root.
- A root Prettier configuration file exists.
- The root `package.json` has a `prettier` property.
- A root `package.json` lists `prettier` in `dependencies`, `devDependencies`, `peerDependencies`, or `optionalDependencies`.

Suggested root config file names:

- `.prettierrc`
- `.prettierrc.json`
- `.prettierrc.json5`
- `.prettierrc.yaml`
- `.prettierrc.yml`
- `.prettierrc.js`
- `.prettierrc.cjs`
- `.prettierrc.mjs`
- `.prettierrc.ts`
- `.prettierrc.cts`
- `.prettierrc.mts`
- `prettier.config.js`
- `prettier.config.cjs`
- `prettier.config.mjs`
- `prettier.config.ts`
- `prettier.config.cts`
- `prettier.config.mts`

Start with root-level detection. If later consumers need monorepo-wide detection, add that intentionally with tests for workspaces and nested packages instead of doing an unbounded repository scan in the first pass.

## Wrapper Flow

The new `prettierignore` script should:

- Read the convention input JSON and validate the settings needed to pass through to `config-text-section`.
- Check whether Prettier is present using the detection rules above.
- If Prettier is not present, write a focused message such as `Prettier was not detected; leaving '.prettierignore' unchanged.` and exit with code zero.
- If Prettier is present, build the same effective settings currently expressed in `convention.yml`.
- Call `Invoke-ConfigTextSection` from `../scripts/ConfigTextSection.ps1` with those settings while the working directory remains the target repository root.

The generated `config-text-section` settings should match the current composite mapping:

```yaml
path: .prettierignore
name: <settings.name>
text: <settings.text>
comment-prefix: '#'
agent: <settings.agent>
commit: <settings.commit>
```

The script should only include optional settings that were present in the original input, so missing `agent`, `commit`, `name`, or `text` continue to behave consistently with `config-text-section` validation.

## Package Detection Details

Use structured JSON parsing for `package.json` instead of string matching.

The package check should:

- Ignore a missing `package.json`.
- Fail with a clear error if `package.json` exists but cannot be parsed, because a malformed package manifest makes dependency detection unreliable.
- Treat `prettier` in any supported dependency block as a match.
- Treat a top-level `prettier` configuration property as a match even if the package does not list `prettier` directly.

Do not use lockfiles as the primary signal in the first pass. Lockfiles can contain transitive Prettier references, which would make repositories look like direct Prettier users when they are not.

## Tests

Add `conventions/prettierignore-section/convention.Tests.ps1` using `conventions/scripts/TestHelpers.ps1`.

Suggested Pester cases:

- Does nothing when there is no `.prettierignore`, no Prettier config, and no root package Prettier signal.
- Applies the configured section when `.prettierignore` already exists.
- Applies the configured section when `.prettierrc` exists.
- Applies the configured section when `prettier.config.js` exists.
- Applies the configured section when `package.json` has a top-level `prettier` property.
- Applies the configured section when `package.json` has `devDependencies.prettier`.
- Does not treat a lockfile-only transitive Prettier reference as a match.
- Fails clearly when `package.json` is malformed.
- Passes through managed section settings to `config-text-section`.
- Passes through `commit` settings and creates the same commit that `config-text-section` would create.
- Is idempotent on a second run.

Per repository instructions, run only this Pester script directly:

```powershell
Invoke-Pester -Path conventions/prettierignore-section/convention.Tests.ps1
```

## Documentation

Update `conventions/prettierignore-section/README.md` to explain that the convention is conditional.

The README should document:

- `.prettierignore` is modified only when Prettier is detected.
- Existing `.prettierignore` counts as detection.
- Root Prettier config files count as detection.
- Root `package.json` Prettier config or dependency entries count as detection.
- Repositories without those signals are left unchanged.

Update `conventions/config-text-section/README.md` to mention that the reusable implementation lives in `conventions/scripts/ConfigTextSection.ps1` for executable conventions that need section behavior plus their own repository inspection.

## Alternative: Add A Predicate Setting To `config-text-section`

Another possible design is adding a generic setting to `config-text-section`, such as `apply-when-script`, `condition-script`, or `skip-when-script`, then keeping `prettierignore-section` as a composite convention that passes a predicate script path into `config-text-section`.

This is not the recommended first step.

Pros:

- Keeps composition as the public mechanism.
- Could support future conditional text-file conventions.

Cons:

- Expands the generic `config-text-section` API with script execution semantics.
- Requires defining path resolution, input shape, output contract, and failure behavior for predicate scripts.
- Makes `config-text-section` responsible for policy decisions outside text management.
- Adds a new public extension point before there is more than one concrete consumer.

Use this option later only if multiple conventions need the same conditional behavior.

## Reusable Config-Text-Section Logic

Extract the file-rewrite functions from `config-text-section` into a reusable runtime helper and then implement `prettierignore-section` entirely in its own script.

This is the preferred implementation because it gives `prettierignore-section` room for repository inspection while keeping section rewrite behavior shared with `config-text-section`.

## Implementation Order

- Extract `conventions/scripts/ConfigTextSection.ps1` and update `config-text-section/convention.ps1` to call it.
- Add the `prettierignore-section` executable script and remove the composite YAML file.
- Add focused tests for detection, pass-through behavior, and idempotency.
- Update the `config-text-section` and `prettierignore-section` READMEs.
- Run `Invoke-Pester -Path conventions/prettierignore-section/convention.Tests.ps1`.
- Run `Invoke-Pester -Path conventions/config-text-section/convention.Tests.ps1` to confirm the shared helper preserves existing behavior.

# PowerShell Function Reuse Across Conventions

## Goal

Define a small, practical plan for reusing PowerShell functions across published conventions in this repository using repo-local shared scripts under `conventions/scripts`.

The plan should answer four questions:

- Do the existing conventions show a real need for shared functions?
- Which functions are worth sharing?
- How should shared functions be distributed?
- Would RepoConventions need new CLI functionality to support that cleanly?

## Current Evidence

The repository already shows two different kinds of reuse pressure.

### Strong Need: Test Helpers

The Pester suites repeat the same mechanics in multiple places:

- `NewTestDirectory` appears in multiple files, including `conventions/config-lines/convention.Tests.ps1`, `conventions/dotnet-sdk/convention.Tests.ps1`, `conventions/dotnet-slnx/convention.Tests.ps1`, `conventions/gitattributes-lf/convention.Tests.ps1`, and `conventions/apm-install-updates/convention.Tests.ps1`.
- `WriteUtf8NoBomFile` is duplicated in several test files.
- Multiple suites repeat the pattern of creating a temporary JSON input file, invoking `convention.ps1` from a temporary repository directory, and cleaning up afterward.
- The git-backed tests in `conventions/gitattributes-lf/convention.Tests.ps1` add another reusable layer: initialize a repository, read commit IDs, read commit subjects, and inspect status.

This duplication is large enough to justify a shared test helper surface now.

### Moderate Need: Runtime Helpers

The executable conventions also repeat low-level mechanics:

- `WriteUtf8NoBomFile` exists in both `conventions/config-lines/convention.ps1` and `conventions/gitattributes-lf/convention.ps1`.
- Several scripts read convention input JSON using the same `Get-Content ... | ConvertFrom-Json` pattern.
- `conventions/gitattributes-lf/convention.ps1` and `conventions/dotnet-sdk/convention.ps1` both set up temporary Copilot config directories and validate external commands before invoking them.
- `conventions/config-lines/convention.ps1` already contains reusable file-content utilities such as newline detection.

The reuse signal is real, but smaller than the test duplication. The current conventions are still specialized enough that most policy logic should remain local to each convention.

### Existing Reuse That Already Works

Convention composition is already the correct reuse mechanism for policy-level behavior.

Examples:

- `conventions/gitattributes/convention.yml` delegates to `conventions/config-lines`.
- `conventions/gitignore/convention.yml` delegates to `conventions/config-lines`.
- `conventions/prettierignore/convention.yml` delegates to `conventions/config-lines`.

This means the repository does not need a shared PowerShell layer for every kind of reuse. It only needs shared functions for repeated low-level mechanics.

## Recommendation

Adopt a local-sharing-first approach.

### Phase 1: Consolidate Test Helpers

Create one repo-local support file for convention tests and have test files dot-source it.

Suggested location:

```text
conventions/scripts/TestHelpers.ps1
```

Suggested helper functions:

- `New-TestDirectory`
- `Write-Utf8NoBomFile`
- `New-ConventionInputFile`
- `Invoke-ConventionScript`
- `Initialize-TestRepository`
- `Get-CommitId`
- `Get-CommitSubjects`
- `Get-GitStatusLines`

This phase has the best cost-to-value ratio:

- It removes the most duplication.
- It reduces drift between convention test suites.
- It fits the current RepoConventions behavior because published conventions are checked out from the full repository.
- It does not change the published convention surface.

### Phase 2: Add a Small Runtime Helper Surface Only If More Conventions Need It

Add one repo-local runtime helper script only for low-level, policy-free helpers that are already used by multiple executable conventions.

Suggested location:

```text
conventions/scripts/Helpers.ps1
```

Do not introduce a large shared runtime module up front. Only extract helpers that are low-level, policy-free, and already used by multiple executable conventions.

Good candidates:

- `Write-Utf8NoBomFile`
- `Get-LineEnding`
- `Read-ConventionSettings`
- `Require-Setting`
- `Set-Utf8ConsoleEncoding`
- `New-TemporaryCopilotConfigDirectory` or an equivalent scoped helper
- `Assert-CommandAvailable`

Poor candidates:

- `.gitattributes` repair logic
- `global.json` validation logic
- `.sln` to `.slnx` migration logic
- any helper that hides convention-specific policy decisions

The rule should be: share mechanics, not policy.

## Distribution Options

There are three logical distribution options for this repository.

### Option 1: Repo-Local Shared Scripts Under `conventions/scripts`

Use repo-local shared scripts for tests and low-level runtime helpers.

Example:

```text
conventions/scripts/
  Helpers.ps1
  TestHelpers.ps1
```

Pros:

- Solves the current duplication with the smallest design change.
- Requires no RepoConventions changes because the full repository is checked out.
- Gives one stable location for shared scripts.
- Keeps helper reuse local to this repository for now.
- Gives one authoritative implementation of the repeated low-level helpers.
- Makes future conventions easier to author.

Cons:

- Convention scripts become coupled to the published repository layout.
- Shared runtime helpers still need discipline so policy logic does not leak into common files.
- The helper surface must stay intentionally small and stable because multiple conventions may depend on it.

This should be the immediate next step.

### Option 2: Published PowerShell Package

Publish a PowerShell module package and install it before convention scripts run.

Example:

```powershell
Import-Module Faithlife.CodingGuidelines.ConventionSupport -Force
```

Pros:

- Uses normal PowerShell distribution mechanics.
- Gives one versioned package surface for helpers.
- Makes helper reuse possible outside this repository.

Cons:

- Adds package installation and trust as part of convention execution.
- Requires deterministic package version resolution in CI and local runs.
- Introduces another external dependency even when conventions are otherwise self-contained.
- Does not fit the current RepoConventions execution model as cleanly as shipping support files with the convention itself.

This is a real option, but it is not the best immediate fit. It becomes more attractive only if the helper surface needs to be reused across many repositories or outside RepoConventions entirely.

## RepoConventions CLI Support

New CLI functionality is not required for the current plan.

RepoConventions checks out the full published repository, so convention scripts can dot-source repo-local shared files by resolving paths relative to `$PSScriptRoot`.

That means both of these are viable now:

- `conventions/scripts/TestHelpers.ps1` for test reuse inside this repository
- `conventions/scripts/Helpers.ps1` for low-level runtime reuse across published convention directories

Additional CLI support would only become interesting later if this repository wanted a cleaner formal contract for definition-relative assets or if RepoConventions ever stopped checking out the full repository.

## Naming and Style Rules

Reusable PowerShell helpers should use traditional PowerShell `Verb-Noun` names with hyphens.

Style rules:

- use approved PowerShell verbs where possible
- keep function names concrete and task-focused
- treat reusable helpers as public-style commands, even when they are dot-sourced from a repo-local support file

Examples:

- `New-TestDirectory`
- `Write-Utf8NoBomFile`
- `Initialize-TestRepository`
- `Read-ConventionSettings`

## Sample Reuse

One practical pattern is a repo-local support file that multiple Pester suites dot-source:

```powershell
. "$PSScriptRoot\..\scripts\TestHelpers.ps1"

Describe 'config-lines convention' {
  It 'creates a repository-root-relative file' {
    $testDirectory = New-TestDirectory
    $inputPath = New-ConventionInputFile -Settings @{ path = '/.gitignore'; entries = @('bin/', 'obj/') }

    try {
      $output = Invoke-ConventionScript -ScriptPath (Join-Path $PSScriptRoot 'convention.ps1') -RepositoryRoot $testDirectory -InputPath $inputPath
      (Get-Content -LiteralPath (Join-Path $testDirectory '.gitignore') -Raw) | Should Be "bin/`nobj/`n"
      $output[-1].ToString() | Should Be "Added 2 entries to '$(Join-Path $testDirectory '.gitignore')'."
    }
    finally {
      Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $testDirectory -Recurse -Force
    }
  }
}
```

This keeps each test focused on convention behavior while the reusable helpers own the temporary directory, JSON input, and script invocation mechanics.

The same pattern works for runtime helpers:

```powershell
. "$PSScriptRoot\..\scripts\Helpers.ps1"

$settings = Read-ConventionSettings -InputPath $args[0]
$targetPath = Get-RepositoryPath -PathSetting $settings.path
Write-Utf8NoBomFile -Path $targetPath -Content $newContent
```

## Proposed Rollout

1. Add `conventions/scripts/TestHelpers.ps1` and migrate the current Pester suites to it.
2. Add `conventions/scripts/Helpers.ps1` only for low-level runtime helpers already duplicated across executable conventions.
3. Keep policy logic inside each convention and limit the shared scripts to mechanics.
4. Reassess later whether a published module package is justified.

## Decision

The existing conventions do demonstrate a need for shared PowerShell functions, with the strongest immediate need in tests and a smaller but real need in runtime mechanics.

The best next step is to centralize reusable helpers under `conventions/scripts` now.

Use `TestHelpers.ps1` for Pester support and `Helpers.ps1` for only the most repeated low-level runtime helpers, while continuing to use composition for policy reuse and keeping convention-specific logic local.

RepoConventions does not need new CLI functionality for this plan because the full repository is already checked out.

Published PowerShell packages are an option, but they should stay behind convention-relative support files in priority. They are most appropriate when the shared helper surface needs to be versioned and consumed beyond this repository.

In short: the recommendation is repo-local sharing under `conventions/scripts`, with published packages reserved for a later stage if the helper surface needs stronger versioning or wider reuse.

# NuGet Package Repository Standards Plan

## Goal

Bring the NuGet-package-publishing repositories in this workspace to a shared, convention-driven baseline for repository infrastructure, build and publish behavior, project-wide MSBuild settings, and common support files.

The plan intentionally avoids source-code modernization except where a repository-wide setting cannot be changed safely without touching source later.

## Scope

Repositories reviewed:

- `DapperUtility`
- `EditorConfigFix`
- `FaithlifeAnalyzers`
- `FaithlifeBuild`
- `FaithlifeDataAnnotations`
- `FaithlifeFakeData`
- `FaithlifeReflection`
- `FaithlifeTesting`
- `FindReplaceCode`
- `Parsing`
- `RepoConventions`
- `SolutionItems`

Primary file families in scope:

- `.github/conventions.yml`
- `.github/workflows/*`
- `build.ps1`, `build.cmd`, `build.sh`, and `tools/Build/*`
- `global.json`
- `*.sln` and `*.slnx`
- `Directory.Build.props`
- `Directory.Packages.props`
- `nuget.config`
- `.editorconfig`, `.gitattributes`, `.gitignore`
- root `LICENSE`, `README.md`, `CONTRIBUTING.md`, release notes/history files, and solution items

## Current State Summary

Most repositories are already close to the current convention-driven baseline:

- 11 repositories use the published `build.ps1` from `CodingGuidelines/conventions/build-script`.
- 11 repositories have `.github/conventions.yml`.
- 11 repositories use `.slnx`.
- 11 repositories pin SDK `10.0.100` in `global.json`.
- 11 repositories have `tools/Build/Build.csproj` targeting `net10.0`.
- 11 repositories use the generated `ci.yml` and `copilot-setup-steps.yml` workflow pair.
- 8 repositories use `Directory.Packages.props`.

Notable outliers:

- `FaithlifeTesting` has no `global.json`, uses `.sln`, `build.cmd`/`build.sh`, `tools/Build` targets `net5.0`, legacy `build.yaml`, no `.github/conventions.yml`, and no `Directory.Packages.props`.
- `FaithlifeFakeData`, `FaithlifeReflection`, and `Parsing` use the modern SDK/build/workflow pattern but do not use `Directory.Packages.props`.
- Common root config files still have several variants: `.editorconfig`, `.gitattributes`, `.gitignore`, and `nuget.config` are not yet uniform across the set.

## Target Standards

### Repository Conventions

Standardize on `.github/conventions.yml` in every package repository.

Preferred target declaration:

```yaml
# applied automatically by https://github.com/Faithlife/RepoConventionsApplier (DO NOT REMOVE THIS LINE)
conventions:
  - path: Faithlife/CodingGuidelines/conventions/faithlife-dotnet-library

pull-request:
  reviewers:
    - ejball
```

Rationale:

- `faithlife-dotnet-library` is the composite convention for package-producing Faithlife .NET libraries.
- It includes auto-apply, `dotnet-common`, generated build project files, generated workflows, MIT license, and common solution items.
- It also avoids copy-pasting the same child convention list across repositories.

Open question: should repositories currently using the expanded child list be migrated to the composite convention immediately, or only as they otherwise change? The composite currently includes `dotnet-solution-items-common`, which the expanded list does not include in most repositories.

Add `nuget-config` to `faithlife-dotnet-library` so the package repository composite owns the root NuGet source configuration.

### SDK And Solution Format

Standardize on:

- `global.json` with SDK `10.0.100` or the current approved .NET 10 SDK.
- `.slnx` at the repository root.
- `tools/Build/Build.csproj` targeting `net10.0`.
- `dotnet-common`, `dotnet-sdk-10`, `dotnet-slnx`, and `faithlife-dotnet-library-build` as the owning conventions.

Initial targets:

- Evaluate `FaithlifeTesting` for migration from no `global.json`, `.sln`, and `net5.0` build project.

Open questions:

- Should `FaithlifeTesting` preserve `build.cmd` and `build.sh` wrappers for compatibility, or should it move fully to the standard `build.ps1` entry point?

### Build And Publish Infrastructure

Standardize on:

- Generated root `build.ps1` from `build-script`.
- Generated `tools/Build/Build.cs` and `Build.csproj` from `faithlife-dotnet-library-build`.
- Generated `.github/workflows/ci.yml` and `.github/workflows/copilot-setup-steps.yml` from `faithlife-dotnet-library-workflow`.
- Package publish through the shared `build.ps1 publish --skip package --trigger publish-nuget-output` workflow path.
- `NuGet/login@v1` and the generated workflow's `NUGET_API_KEY` handoff, unless a repository has a documented exception.

Initial targets:

- Replace `FaithlifeTesting/.github/workflows/build.yaml` with generated `ci.yml` after confirming its test/build matrix needs.

Open questions:

- Should generated publish use only `NuGet/login`, or should some repositories keep direct `NUGET_API_KEY` secrets during migration?
- Should legacy `BUILD_BOT_PASSWORD` publishing paths be removed everywhere once workflows are generated?

### Central Package Management

Standardize on `Directory.Packages.props` with:

- `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`.
- `PackageVersion` entries for project and test dependencies.
- `GlobalPackageReference` entries for analyzers and build-wide tooling where appropriate.
- Current shared analyzer versions, including `StyleCop.Analyzers` `1.2.0-beta.556` and a consistent `Faithlife.Analyzers` version.

Initial targets:

- Add `Directory.Packages.props` to `FaithlifeFakeData`, `FaithlifeReflection`, `FaithlifeTesting`, and `Parsing`.
- Move analyzer package references out of `Directory.Build.props` in repositories that still keep them there.
- Normalize `Faithlife.Analyzers` versions across repositories that already use central package management.

Open questions:

- Should central package management be enforced by a new CodingGuidelines convention, or should it remain a manual per-repository migration because package versions are repository-specific?
- Should a convention manage only the shared `GlobalPackageReference` analyzer block while leaving `PackageVersion` entries local?
- What should the approved `Faithlife.Analyzers` version be across the package repositories?

### Directory.Build.props

Standardize the common property block while preserving package-specific versioning and compatibility choices.

Common desired properties:

- `VersionPrefix` remains repository-specific.
- `PackageValidationBaselineVersion` is used for every public library package; for first-time enablement, set it to the current `VersionPrefix` so baseline validation is disabled until the next version bump.
- `LangVersion` is pinned to the same newest C# version supported by the approved SDK across all repositories.
- `Nullable` is current and intentional.
- `ImplicitUsings` is enabled unless there is a compatibility reason not to.
- `TreatWarningsAsErrors` is true.
- `NeutralLanguage` is `en-US`.
- `DebugType` is `embedded` where supported.
- `GitHubOrganization` and `RepositoryName` are used to construct repository URLs.
- `PackageLicenseExpression` is `MIT`.
- `PackageProjectUrl`, `PackageReleaseNotes`, and `RepositoryUrl` follow the same URL pattern, with `RepositoryUrl` not using a `.git` suffix.
- `Authors` is `Faithlife`.
- Automatic MSBuild properties provided by `Faithlife.Build` are not duplicated in `Directory.Build.props`; this includes `AllowedOutputExtensionsInPackageBuildOutputFolder`, `AssemblyVersion`, `ContinuousIntegrationBuild`, and `PublishRepositoryUrl`, plus SDK-provided Source Link properties such as `EmbedUntrackedFiles` and `SourceLinkGitHubHost`.
- `EnableNETAnalyzers`, `AnalysisLevel`, and `EnforceCodeStyleInBuild` are enabled consistently.
- `GenerateDocumentationFile` is true for every package repository.
- `IsPackable` and `IsTestProject` default to false at the repo level, with package projects opting in.
- `SelfContained` is false.
- `UseArtifactsOutput` is true for SDKs that support it.
- NuGet audit settings are consistent for repos where the SDK supports them.

Initial targets:

- Align newer repositories that already look similar: `EditorConfigFix`, `RepoConventions`, and `SolutionItems`.
- Bring `DapperUtility`, `FaithlifeDataAnnotations`, `FindReplaceCode`, `FaithlifeBuild`, `FaithlifeAnalyzers`, `FaithlifeFakeData`, `FaithlifeReflection`, and `Parsing` toward the same property order and common property set.
- Treat `FaithlifeTesting` as a later migration because changing language version, nullability, debug symbols, and package compatibility settings may expose source-level work.

Open questions:

- Should nullable be `enable` for every package repo, with source fixes scheduled separately, or should legacy packages be allowed to keep `disable`?

### NuGet Package Metadata

Standardize package project metadata so every published package has:

- `IsPackable` set to true in the package project.
- A clear `Description`.
- `PackageReadmeFile` set to `README.md` where NuGet should display the repository README.
- `RewritePackageReadmeLinks` set to true wherever `PackageReadmeFile` is specified, so repository-relative Markdown links are rewritten for nuget.org while same-document anchors and absolute links are preserved.
- MIT license metadata inherited from `Directory.Build.props`.
- Repository and project URL metadata inherited from `Directory.Build.props`.
- Source Link publishing metadata enabled.

Initial targets:

- Add missing package readme metadata to `FaithlifeAnalyzers` and `FaithlifeTesting` packages if desired.
- Add or verify descriptions for packages where the inventory found missing descriptions, notably `Faithlife.Testing.RabbitMq` and `Faithlife.FindReplaceCode.Tool`.

Open question: should analyzer packages, test helper packages, and command-line tool packages all use the same NuGet README policy?

### Common Root Files

Standardize files already covered by conventions:

- `.editorconfig` through the editorconfig conventions included by `dotnet-common`.
- `.gitattributes` through `gitattributes-lf` and `gitattributes-csharp`.
- `LICENSE` through `faithlife-license-mit`.
- `build.ps1` through `build-script`.
- `global.json` through `dotnet-sdk-10`.
- `.slnx` through `dotnet-slnx`.
- common solution items through `dotnet-solution-items-common`.

Consider extending conventions for files not currently covered by the composite package baseline:

- `nuget.config`, by adding the existing `nuget-config` convention to `faithlife-dotnet-library`.
- `.gitignore`, by creating a convention that manages a standard package-repository section rather than replacing repository-specific ignore rules.
- `CONTRIBUTING.md`, if it should be shared across package repositories.
- `Directory.Packages.props`, by creating a convention that manages shared analyzer `GlobalPackageReference` entries while leaving repository-specific `PackageVersion` items local.
- `Directory.Build.props`, by creating a settings-driven convention that owns the common property block and accepts repository-specific settings such as version, package validation baseline, nullable mode, and any temporary warning suppressions.

Open questions:

- Should `CONTRIBUTING.md` become convention-managed for package repositories?
- Should root `.DotSettings` files be standardized, ignored, or left repository-specific? Several repositories have `.DotSettings.user`, and only a few have shared `.DotSettings`.
- Should every repository have an `AGENTS.md`, or should agent guidance stay centralized in CodingGuidelines unless a repository has real local exceptions?

## Work Plan

### Phase 1: Define The Standard In CodingGuidelines

- Use the composite `faithlife-dotnet-library` convention as the approved package repository declaration shape.
- Add `nuget-config` to `faithlife-dotnet-library`.
- Create or update conventions for the proposed shared analyzer package references, `.gitignore` section, and common `Directory.Build.props` section.
- Document the approved package repository standard in CodingGuidelines so future repos have one source of truth.

Validation:

- Run the narrow CodingGuidelines convention tests for any changed conventions.
- Run `conventions/RunAllTests.ps1` if convention behavior changes broadly.

### Phase 2: Normalize Repositories Already Close To The Baseline

Target repositories:

- `DapperUtility`
- `EditorConfigFix`
- `FaithlifeAnalyzers`
- `FaithlifeBuild`
- `FaithlifeDataAnnotations`
- `FaithlifeFakeData`
- `FaithlifeReflection`
- `FindReplaceCode`
- `Parsing`
- `RepoConventions`
- `SolutionItems`

Work:

- Migrate expanded convention declarations to the approved standard.
- Apply `faithlife-dotnet-library` or the approved child convention set.
- Add missing `Directory.Packages.props` files where source-level dependency changes are minimal.
- Normalize `.editorconfig`, `.gitattributes`, `nuget.config`, and solution items through conventions.
- Normalize shared `Directory.Build.props` properties that do not require source changes.
- Update package metadata gaps such as missing readmes or descriptions.

Validation per repository:

- Run `./build.ps1 restore`.
- Run `./build.ps1 build --skip restore`.
- Run `./build.ps1 test --skip build`.
- Run `./build.ps1 package --skip test`.

### Phase 3: Migrate FaithlifeTesting

Work:

- Add `global.json` and `.github/conventions.yml` if the .NET 10 baseline is accepted.
- Move from `.sln` to `.slnx`.
- Replace `build.cmd`/`build.sh` with standard `build.ps1`, or keep thin compatibility wrappers if needed.
- Regenerate `tools/Build` for `net10.0`.
- Replace legacy `build.yaml` with generated `ci.yml` and `copilot-setup-steps.yml`.
- Add `Directory.Packages.props` and move analyzer references out of `Directory.Build.props`.
- Decide separately whether nullable and language-version changes are allowed to cause source work.

Validation:

- Run package build on Windows and Linux if wrappers are preserved.
- Verify all three packages still produce `.nupkg` files.

## Tracking Checklist

- [ ] Add `nuget-config` to the `faithlife-dotnet-library` composite convention.
- [ ] Create or update a convention for shared analyzer `GlobalPackageReference` entries.
- [ ] Create or update a convention-managed package repository `.gitignore` section.
- [ ] Create or update a settings-driven convention for the common `Directory.Build.props` property block.
- [ ] Decide whether nullable should be `enable` for every in-scope package repository.
- [ ] Decide whether `FaithlifeTesting` should keep compatibility `build.cmd` and `build.sh` wrappers.
- [ ] Update CodingGuidelines conventions and docs for the approved standard.
- [ ] Apply the standard to repositories already close to baseline.
- [ ] Migrate `FaithlifeTesting`.
- [ ] Verify every in-scope repository can restore, build, test, package, and publish through its approved path.

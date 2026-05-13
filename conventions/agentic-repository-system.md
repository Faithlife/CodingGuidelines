# Agentic Repository System

Logos repositories need agent tooling that is consistent, reusable, and easy to roll out.

Without a shared system, every repository has to hand-wire skills, prompts, MCP servers, generated files, and ignore rules. Teams then have to repeat the same setup in each repository and keep it aligned over time.

This system splits that work into four parts:

- [`microsoft/apm`](https://github.com/microsoft/apm) installs and locks agent dependencies for one repository.
- [`LogosBible/AgentConfiguration`](https://github.com/LogosBible/AgentConfiguration) publishes the shared Logos packages that repositories consume.
- [`Faithlife/RepoConventions`](https://github.com/Faithlife/RepoConventions) applies that setup across repositories.
- [`Faithlife/CodingGuidelines`](https://github.com/Faithlife/CodingGuidelines) provides the conventions that prepare repositories for APM and run the install step.

## What Each Piece Does

| Tool or repo                    | What it is                                 | Problem it solves                                                                       | How it solves it                                                                                                     |
| ------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `microsoft/apm`                 | Agent package manager                      | Agent setup is slow, manual, and inconsistent                                           | Reads `apm.yml`, resolves dependencies, writes `apm.lock.yaml`, `.agents/`, and target files under `.github/`        |
| `LogosBible/AgentConfiguration` | Shared Logos APM packages                  | Teams keep rebuilding the same skills, prompts, and MCP setup                           | Publishes reusable packages under `common/` and team folders, each with its own `apm.yml`                            |
| `Faithlife/RepoConventions`     | Repository rollout tool                    | Applying the same repo changes across many repositories is tedious                      | Reads `.github/conventions.yml`, applies `convention.yml` and `convention.ps1`, commits changes, and can open a PR   |
| `Faithlife/CodingGuidelines`    | Shared conventions used by RepoConventions | APM-managed repos need the same ignore rules, generated-file handling, and install step | Publishes conventions such as `conventions/agentic-repo/convention.yml` and `conventions/apm-install/convention.ps1` |

## How They Fit Together

A repository that wants shared agent tooling follows this path.

1. The repository picks a package such as `LogosBible/AgentConfiguration/common/web`.
2. `RepoConventions` or a developer installs that package.
3. `CodingGuidelines` conventions prepare the repository for APM-managed files.
4. `APM` installs the package and all of its dependencies.
5. The repository gets the same agent setup every time.

When a repository is managed by RepoConventions, the flow is:

1. `.github/conventions.yml` lists a convention path such as `LogosBible/AgentConfiguration/common/web`.
2. `repo-conventions apply` resolves that path and runs its `convention.yml`.
3. `LogosBible/AgentConfiguration/common/web/convention.yml` applies `Faithlife/CodingGuidelines/conventions/agentic-repo`.
4. The same convention applies `Faithlife/CodingGuidelines/conventions/apm-install` with package `LogosBible/AgentConfiguration/common/web`.
5. `conventions/agentic-repo/convention.yml` updates `.gitattributes`, `.gitignore`, and `.prettierignore` for APM-managed files.
6. `conventions/apm-install/convention.ps1` runs `apm install --update --target agent-skills`.
7. `APM` reads `apm.yml`, installs dependencies, and writes generated outputs such as `apm.lock.yaml` and `.agents/skills/`.

## Concrete Example

This RepoConventions entry:

```yaml
conventions:
  - path: LogosBible/AgentConfiguration/common/web
```

ends up doing three concrete things:

1. It applies `Faithlife/CodingGuidelines/conventions/agentic-repo`.
2. It applies `Faithlife/CodingGuidelines/conventions/apm-install` with package `LogosBible/AgentConfiguration/common/web`.
3. It adds `.playwright-cli/` to `.gitignore` through `Faithlife/CodingGuidelines/conventions/gitignore-section`.

That package's `apm.yml` currently installs `microsoft/playwright-cli/skills/playwright-cli`, so the repository gets shared browser automation tooling without defining it by hand.

`conventions/agentic-repo/convention.yml` currently standardizes these APM-related files:

- `.gitattributes` marks `apm.lock.yaml` and `.agents/**` as generated.
- `.gitignore` ignores `apm_modules/` and `.apm-pin`.
- `.prettierignore` ignores `.agents/`, `apm.lock.yaml`, and `apm.yml`.

## How To Adopt It

### Use RepoConventions for shared rollout

Use this path when many repositories should get the same setup.

Requirements: the target repository must have a clean working tree, and `gh` must be installed and authenticated when you use `--open-pr`.

1. Install `repo-conventions`.
2. Add a package-backed convention reference to `.github/conventions.yml`.
3. Run `repo-conventions apply` from the repository root.
4. Commit the updated files, including `apm.yml`, `apm.lock.yaml`, `.agents/`, and any convention-managed config files.

Example:

```sh
repo-conventions add LogosBible/AgentConfiguration/common/web
repo-conventions apply
```

Use `repo-conventions apply --open-pr` when you want the tool to push the branch and open or update the pull request.

### Use APM directly for one repository

Use this path when one repository manages its own agent setup directly.

Requirement: the repository needs GitHub access to read private packages from `LogosBible/AgentConfiguration`.

1. Install `apm`.
2. Run `apm init` in the repository root.
3. Run `apm install LogosBible/AgentConfiguration/common/web`.
4. Commit `apm.yml`, `apm.lock.yaml`, `.agents/`, and generated target files.

Example:

```sh
apm init
apm install LogosBible/AgentConfiguration/common/web
```

## Where New Content Goes

- Put repository-only skills in `/.github/skills/` in that repository.
- Put skills that ship with a source repository for its consumers in `/skills/` in that source repository.
- Put shared Logos packages in `LogosBible/AgentConfiguration/common/` or the relevant team folder.

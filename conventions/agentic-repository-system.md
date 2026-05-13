# Agentic Repository System

AI coding agents (GitHub Copilot, Claude Code, etc.) work better when a repository contains configuration: skills that teach the agent how to do specific tasks, prompts that set context, and MCP servers that give the agent new capabilities. These files live in the repository so every developer gets the same agent behavior.

Setting this up by hand in every repository is slow and inconsistent. This system automates it with four tools.

## Problem 1: Agent setup is manual

**Tool: [APM](https://github.com/microsoft/apm)** (Agent Package Manager, by Microsoft)

APM is like npm, but for agent configuration. You declare what your agents need in an `apm.yml` file, and `apm install` downloads and wires up everything — skills, prompts, MCP servers, and their transitive dependencies.

A repository's `apm.yml` might look like:

```yaml
name: my-project
dependencies:
  apm:
    - microsoft/playwright-cli/skills/playwright-cli
```

Running `apm install` reads that file, resolves dependencies, and writes:

- `apm.lock.yaml` — pinned versions and integrity hashes (like `package-lock.json`)
- `.agents/skills/` — the actual skill files agents read
- target files under `.github/` — e.g. `copilot-instructions.md`

Any developer who clones the repo and runs `apm install` gets the same agent setup.

## Problem 2: Teams rebuild the same skills

**Tool: [AgentConfiguration](https://github.com/LogosBible/AgentConfiguration)** (internal Logos repo)

AgentConfiguration is a shared library of APM packages. Instead of every repository defining its own React skills or Playwright setup, teams publish reusable packages here.

Packages are organized by team or by technology:

- `common/web` — Playwright browser automation for web projects
- `common/dotnet` — .NET development skills
- `bible-study-tools/...` — team-specific packages

Each package has an `apm.yml` that lists its dependencies. For example, `common/web/apm.yml` depends on `microsoft/playwright-cli/skills/playwright-cli`. Installing the package installs everything it depends on.

## Problem 3: APM-managed repos need boilerplate

**Tool: [CodingGuidelines](https://github.com/Faithlife/CodingGuidelines)** (this repo)

Every repository that uses APM needs the same housekeeping: mark generated files in `.gitattributes`, ignore build artifacts in `.gitignore`, exclude generated files from Prettier. This repo publishes the `conventions/agentic-repo` convention that handles all of it.

`conventions/agentic-repo` does four things in order:

1. Adds `.gitattributes` entries marking `apm.lock.yaml` and `.agents/**` as generated.
2. Adds `.gitignore` entries for `apm_modules/` and `.apm-pin`.
3. Adds `.prettierignore` entries for `.agents/`, `apm.lock.yaml`, and `apm.yml`.
4. Runs `apm install --update` to download and install any APM packages. (This last step is the `conventions/apm-install` script — a PowerShell script that calls APM. It skips if no `apm.yml` exists and no packages are configured.)

AgentConfiguration packages apply `agentic-repo` automatically, so most repositories don't reference it directly.

## Problem 4: Rolling out changes across many repos

**Tool: [RepoConventions](https://github.com/Faithlife/RepoConventions)**

RepoConventions applies a set of conventions to a repository, commits the changes, and optionally opens a pull request. It reads `.github/conventions.yml` to know what conventions to apply.

A convention can be a YAML file that composes other conventions, or a PowerShell script that makes arbitrary changes. Conventions can live in any GitHub repository.

## How they chain together

Here is a concrete example. A repository's `.github/conventions.yml` says:

```yaml
conventions:
  - path: LogosBible/AgentConfiguration/common/web
```

When `repo-conventions apply` runs, it:

1. Clones `LogosBible/AgentConfiguration` and finds `common/web/convention.yml`.
2. That convention.yml applies three CodingGuidelines conventions in order:
   - `conventions/agentic-repo` — adds `.gitattributes`, `.gitignore`, and `.prettierignore` entries for APM files
   - `conventions/apm-install` with package `LogosBible/AgentConfiguration/common/web` — runs `apm install`, which reads the package's `apm.yml`, resolves `microsoft/playwright-cli/skills/playwright-cli`, and writes the skill files into `.agents/skills/`
   - `conventions/gitignore-section` — adds `.playwright-cli/` to `.gitignore` (Playwright's local cache)
3. RepoConventions commits the changes and can push a branch and open a PR.

The result: the repository has a working agent setup with Playwright skills, correct ignore rules, and a lockfile — from one line in a YAML file.

## How to adopt

### Prerequisites

Install these tools once:

- **[APM](https://microsoft.github.io/apm/getting-started/quick-start/)** — `curl -sSL https://aka.ms/apm-unix | sh` (macOS/Linux) or `irm https://aka.ms/apm-windows | iex` (Windows)
- **[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)** — includes `dnx`, which runs .NET tools without a local manifest

### Set up a repository

Apply the `agentic-repo` convention to get standard APM ignore rules and run `apm install`:

```sh
dnx repo-conventions add Faithlife/CodingGuidelines/conventions/agentic-repo --open-pr
```

To also get nightly convention updates via template-updater:

```sh
dnx repo-conventions add LogosBible/actions/conventions/auto-apply-conventions --open-pr
```

### Add an AgentConfiguration package

Pick a package from [AgentConfiguration](https://github.com/LogosBible/AgentConfiguration) based on your project:

| Project type | Package                                              | What it installs                             |
| ------------ | ---------------------------------------------------- | -------------------------------------------- |
| Web          | `LogosBible/AgentConfiguration/common/web`           | Playwright browser automation                |
| .NET         | `LogosBible/AgentConfiguration/common/dotnet`        | .NET inspection skills                       |
| .NET Aspire  | `LogosBible/AgentConfiguration/common/dotnet-aspire` | .NET skills + Playwright + Aspire MCP server |

```sh
dnx repo-conventions add LogosBible/AgentConfiguration/common/web --open-pr
```

This applies `agentic-repo` automatically (no need to add it separately), installs the package's APM dependencies, and adds any package-specific ignore rules.

### What to commit

| Commit                                            | Description                                       |
| ------------------------------------------------- | ------------------------------------------------- |
| `.github/conventions.yml`                         | Convention references for this repo               |
| `apm.yml`                                         | APM package manifest                              |
| `apm.lock.yaml`                                   | Pinned dependency versions and integrity hashes   |
| `.agents/`                                        | Generated skill and prompt files that agents read |
| `.gitattributes`, `.gitignore`, `.prettierignore` | Updated ignore/generated rules                    |

The `agentic-repo` convention configures these files to be ignored:

| Ignored        | Why                                       |
| -------------- | ----------------------------------------- |
| `apm_modules/` | APM download cache (like `node_modules/`) |
| `.apm-pin`     | Local APM override file                   |

## Where to put new skills

| Scope                                      | Location                                                 |
| ------------------------------------------ | -------------------------------------------------------- |
| Used only in one repository                | `/.github/skills/` in that repository                    |
| Ships with a source repo for its consumers | `/skills/` in that source repository                     |
| Shared across many Logos repos             | `LogosBible/AgentConfiguration/common/` or a team folder |

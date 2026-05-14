# Agentic Repository System

AI coding agents (GitHub Copilot, Claude Code, etc.) work better when a repository contains configuration: skills that teach the agent how to do specific tasks, prompts that set context, and MCP servers that give the agent new capabilities. These files live in the repository so every developer gets the same agent behavior.

Setting this up by hand in every repository is slow and inconsistent. This system automates it with four tools.

## Problem 1: Agent setup is manual

**Tool: [APM](https://github.com/microsoft/apm)** (Agent Package Manager, by Microsoft)

APM is like npm, but for agent configuration. You declare what your agents need in an `apm.yml` file, and `apm install` downloads and wires up everything: skills, prompts, MCP servers, and their transitive dependencies.

A repository's `apm.yml` might look like:

```yaml
name: my-project
dependencies:
  apm:
    - microsoft/playwright-cli/skills/playwright-cli
```

Running `apm install` reads that file, resolves dependencies, and writes:

- `apm.lock.yaml`: pinned versions and integrity hashes (like `package-lock.json`)
- `.agents/skills/`: the actual skill files agents read
- target files under `.github/`, e.g. `copilot-instructions.md`

Any developer who clones the repo and runs `apm install` gets the same agent setup.

## Problem 2: Teams rebuild the same skills

**Tool: [AgentConfiguration](https://github.com/LogosBible/AgentConfiguration)** (internal Logos repo)

AgentConfiguration is a shared library of APM packages. Instead of every repository defining its own React skills or Playwright setup, teams publish reusable packages here.

Packages are organized by team or by technology:

- `common/web`: Web development skills, e.g. Playwright browser automation
- `common/dotnet`: .NET development skills, e.g. `dotnet-inspect`
- `common/general-coding-instructions`: General coding guidelines for all languages
- `bible-study-tools/...`: team-specific packages

Each package has an `apm.yml` that lists its dependencies. For example, `common/web/apm.yml` depends on `microsoft/playwright-cli/skills/playwright-cli`. Installing the package installs everything it depends on.

There are packages for working with tools like Graylog and Slack, and packages for workflows like working across repositories.

## Problem 3: APM-managed repos need boilerplate

**Tool: [CodingGuidelines](https://github.com/Faithlife/CodingGuidelines)** (this repo)

Every repository that uses APM needs the same housekeeping: mark generated files in `.gitattributes`, ignore build artifacts in `.gitignore`, exclude generated files from Prettier. This repo publishes the `conventions/agentic-repo` convention that handles all of it.

`conventions/agentic-repo` does the following to prepare a repository for using APM:

1. Adds `.gitattributes` entries marking `apm.lock.yaml` and `.agents/**` as generated.
2. Adds `.gitignore` entries for `apm_modules/` and `.apm-pin`.
3. Adds `.prettierignore` entries for `.agents/`, `apm.lock.yaml`, and `apm.yml`.
4. Runs `apm install --update` on the existing `apm.yml` if present (via the `conventions/apm-install` convention).

Other conventions can also chain `apm-install` with explicit packages to install them as part of a convention run (e.g. `common/web` in AgentConfiguration).

## Problem 4: Rolling out changes across many repos

**Tool: [RepoConventions](https://github.com/Faithlife/RepoConventions)**

A convention is a script or set of scripts that enforces a standard in a repository, e.g. "this repo must have these `.gitignore` entries", "this repo must have this workflow file." The script checks the current state and makes whatever edits are needed.

RepoConventions runs the scripts listed in `.github/conventions.yml`, commits any changes, and optionally opens a PR. Because conventions are idempotent, running them again later picks up upstream changes.

[template-updater](https://github.com/LogosBible/template-updater) runs this nightly. Its "Apply ALL Repo Conventions" workflow runs daily on every repository whose `.github/conventions.yml` starts with the marker line `# applied automatically by https://github.com/LogosBible/template-updater (DO NOT REMOVE THIS LINE)`. That marker is added automatically by the `auto-apply-conventions` convention.

## How they chain together

Here is a concrete example. A repository's `.github/conventions.yml` says:

```yaml
conventions:
  - path: LogosBible/AgentConfiguration/common/web
```

When `repo-conventions apply` runs, it:

1. Clones `LogosBible/AgentConfiguration` and finds `common/web/convention.yml`.
2. That convention.yml applies three CodingGuidelines conventions in order:
   - `conventions/agentic-repo`: adds `.gitattributes`, `.gitignore`, and `.prettierignore` entries for APM files
   - `conventions/apm-install` with package `LogosBible/AgentConfiguration/common/web`: runs `apm install`, which reads the package's `apm.yml`, resolves `microsoft/playwright-cli/skills/playwright-cli`, and writes the skill files into `.agents/skills/`
   - `conventions/gitignore-section`: adds `.playwright-cli/` to `.gitignore` (Playwright's local cache)
3. RepoConventions commits the changes and can push a branch and open a PR.

The result: the repository has a working agent setup with Playwright skills, correct ignore rules, and a lockfile, all from one line in a YAML file.

## How to adopt

### Prerequisites

Install these tools once:

- **[APM](https://microsoft.github.io/apm/getting-started/quick-start/)**: run `curl -sSL https://aka.ms/apm-unix | sh` (macOS/Linux) or `irm https://aka.ms/apm-windows | iex` (Windows)
- **[.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)**: includes `dnx`, which runs .NET tools without a local manifest

The pattern for all project types is the same: `apm install` first (populates `apm.yml`), then `repo-conventions add`, one commit, then `repo-conventions apply` (which auto-commits the boilerplate changes it makes).

### Web project

```sh
apm install --update --target copilot LogosBible/AgentConfiguration/common/web-instructions
dnx repo-conventions add LogosBible/AgentConfiguration/common/web
dnx repo-conventions add LogosBible/actions/conventions/auto-apply-conventions
git add -A && git commit -m "Add agent configuration"
dnx repo-conventions apply
```

### .NET project

```sh
apm install --update --target copilot LogosBible/AgentConfiguration/common/dotnet-instructions
dnx repo-conventions add Faithlife/CodingGuidelines/conventions/agentic-repo
dnx repo-conventions add LogosBible/actions/conventions/auto-apply-conventions
git add -A && git commit -m "Add agent configuration"
dnx repo-conventions apply
```

### Web + .NET project

```sh
apm install --update --target copilot LogosBible/AgentConfiguration/common/web-instructions LogosBible/AgentConfiguration/common/dotnet-instructions
dnx repo-conventions add LogosBible/AgentConfiguration/common/web
dnx repo-conventions add LogosBible/actions/conventions/auto-apply-conventions
git add -A && git commit -m "Add agent configuration"
dnx repo-conventions apply
```

The `-instructions` packages pull in their dependencies (`web`, `dotnet`, `general-coding-instructions`) automatically.

### How it works

`repo-conventions add` applies **conventions** (directories with `convention.yml`) that handle repo setup. `apm install` installs **APM packages** (directories with `apm.yml`) that provide agent skills and prompts. `common/web` is both a convention and an APM package; most other packages are APM-only.

Other APM packages are available for [Graylog, Slack, OpsGenie, multi-repo workflows, and more](https://github.com/LogosBible/AgentConfiguration). Install with `apm install --update --target copilot LogosBible/AgentConfiguration/common/<package>`.

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

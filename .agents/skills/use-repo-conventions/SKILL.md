---
name: use-repo-conventions
description: Add or update convention references in a repository that uses repo-conventions.
---

# Use Repo Conventions

Use this skill when adding or updating `.github/conventions.yml` in a repository that consumes conventions via repo-conventions.

## Goal

Configure a repository to apply the right conventions in the right order with minimal, maintainable configuration.

## When To Use This Skill

- Use this skill when the task is to wire an existing repository up to one or more conventions.
- Use this skill when the task is to add or update convention references or settings in `.github/conventions.yml`.
- Use this skill when the task is to configure PR automation for convention-generated pull requests.
- Do not use this skill to author published conventions or edit `convention.ps1` / `convention.yml` inside convention directories. Use `create-repo-conventions` for that.

## Configuration Model

- The repository config file is `.github/conventions.yml`.
- The file must contain a `conventions` sequence.
- Each entry must include `path` and may include `settings` and `pull-request`.
- The file may also include top-level `pull-request` settings.
- Convention entries are resolved in declaration order.
- Local convention paths start with `./` or `../` or `/` and are resolved relative to the containing configuration file.
- Remote convention paths use `owner/repo/path@ref`.
- If `@ref` is omitted, repo-conventions uses the head of the remote repository's default branch.
- See `docs/configuration.md` for the full configuration surface.

Example:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-sdk
    settings:
      version: 10
  - path: Faithlife/CodingGuidelines/conventions/dotnet-slnx
```

## Usage Workflow

- Inspect the repository for an existing `.github/conventions.yml` file and any files or workflows that already assume conventions are present.
- Identify which conventions should be applied and whether they should be local or remote references.
- Keep the configuration minimal: add only the conventions and settings needed for the repository.
- Preserve the intended application order. Earlier conventions may affect later ones.
- Prefer `repo-conventions add <path>` when the task is simply to append a convention reference without changing other settings.
- If the repository uses `repo-conventions apply --open-pr`, configure `pull-request` metadata in `.github/conventions.yml` instead of editing published convention internals.
- Keep consumer documentation focused on how the repository uses conventions; link to shared authoring docs rather than duplicating convention implementation details.

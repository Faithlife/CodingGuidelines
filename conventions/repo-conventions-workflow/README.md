# repo-conventions-workflow

This [convention](https://github.com/Faithlife/RepoConventions) installs a GitHub Actions workflow at `.github/workflows/conventions.yml` that automatically applies repository conventions on a weekly schedule and opens a pull request when changes are needed.

## Usage

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/repo-conventions-workflow
```

After adding this convention and running `repo-conventions apply`, the workflow file will be created. The workflow:

- Runs every Monday at 6:00 AM UTC
- Can be triggered manually via `workflow_dispatch`
- Installs the `repo-conventions` tool and runs `repo-conventions apply --open-pr`
- Opens or updates a pull request when any convention changes are detected

## Permissions

The workflow requires `contents: write` and `pull-requests: write` permissions, which are set in the workflow file. No additional repository settings are needed when using the default `GITHUB_TOKEN`.

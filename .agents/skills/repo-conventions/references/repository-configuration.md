# Repository Configuration

RepoConventions reads `.github/conventions.yml` from the target repository root by default. The file declares the conventions to apply to the repository and optional pull request metadata for `--open-pr` runs.

## Top-Level Properties

| Property | Required | Description |
| --- | --- | --- |
| `conventions` | Yes | Sequence of convention references, applied in declaration order. |
| `pull-request` | No | Pull request settings for the generated pull request. |

Complete example:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-sdk
    settings:
      version: 10
  - path: ./conventions/local-policy
    commit:
      message: Update local policy files
    pull-request:
      labels:
        - dependencies
      auto-merge: false

pull-request:
  labels:
    - automation
  reviewers:
    - octocat
  merge-method: squash
```

## Convention References

Each item in `conventions` must contain a non-empty `path`. It may also contain `settings`, `commit`, and `pull-request`.

Use `settings` to pass JSON-compatible data to a convention: objects, arrays, strings, numbers, booleans, or null values. Top-level repository configuration uses literal settings values.

See [Convention Configuration](./convention-configuration.md) for reference path forms, settings behavior, commit settings, and reference-level pull request settings.

See [Convention Authoring](./convention-authoring.md) for composite conventions and child settings expressions.

## Pull Request Settings

Top-level `pull-request` settings apply to the generated pull request when the command runs with `--open-pr`. Convention references and convention directories can also contribute pull request settings when they create commits.

List values such as `labels`, `reviewers`, and `assignees` are appended and de-duplicated case-insensitively. Scalar values such as `draft`, `auto-merge`, and `merge-method` can be overridden by reference-level settings or CLI flags.

See [Convention Configuration](./convention-configuration.md#pull-request-settings) for the full pull request settings table and merge behavior.

## Validation

Run validation after editing repository configuration:

```pwsh
dnx repo-conventions validate
```

Validation loads the configuration file and resolves the complete convention plan without running convention scripts, creating commits, or changing the working tree.

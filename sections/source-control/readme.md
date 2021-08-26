# Source Control

## Commits

Each commit should be one logical change.

Write descriptive commit messages. Include the reason for the change, not just what changed. Include an issue identifier if one exists.
* [Commit Message Guidelines](commit-message-guidelines.md)
* [Describe Merge Commits Well](describe-merge-commits-well.md)

## Branches

Development should happen on the master branch.

Use branches for if releases cannot happen from master, e.g. beta and stable branches.

Avoid other long-lived branches.

## Merging

[Use Git Rebase](use-git-rebase.md)

Use pull requests for code that should be reviewed or tested in CI before being merged.

Prefer rebase or merge commits. Avoid squash-merge, though they may be useful if a PR contains many changes that should not be kept in history.

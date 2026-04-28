# repo-conventions-workflow

This convention ensures the repository contains `.github/workflows/repo-conventions.yml`.

The file is created or overwritten with a GitHub workflow called **Apply Repository Conventions**, which uses the [repo-conventions reusable workflow](../../.github/workflows/repo-conventions-call.yml) to apply repository conventions every weekday with [repo-conventions](https://github.com/Faithlife/RepoConventions). If an existing workflow is already up to date, the convention preserves the workflow's existing scheduled minute instead of rewriting it only because a new random minute would have been selected.

To bootstrap a new repository:

```pwsh
dnx repo-conventions add Faithlife/CodingGuidelines/conventions/repo-conventions-workflow
git add -A
git commit -m "Add repo-conventions-workflow convention"
dnx repo-conventions apply
```

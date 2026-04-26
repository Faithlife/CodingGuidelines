# repo-conventions-workflow

This convention ensures the repository contains `.github/workflows/repo-conventions.yml`.

If it does not, that file is created, installing a GitHub workflow called **Apply Repository Conventions**, which uses the [repo-conventions reusable workflow](../../.github/workflows/repo-conventions-call.yml) to apply repository conventions every weekday with [repo-conventions](https://github.com/Faithlife/RepoConventions).

To bootstrap a new repository:

```pwsh
dnx repo-conventions add Faithlife/CodingGuidelines/conventions/repo-conventions-workflow
git add -A
git commit -m "Add repo-conventions-workflow convention"
dnx repo-conventions apply
```

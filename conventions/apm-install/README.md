# apm-install

This convention runs `apm install --update [package ...]` in the target repository.

If the target repository has no `apm.yml` file and no packages are configured in the input settings, the convention exits successfully without invoking `apm`.

It is used to install and update APM-managed dependencies.

Install and update:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm-install
    settings:
      packages:
        - richlander/dotnet-inspect/skills/dotnet-inspect
        - microsoft/playwright-cli/skills/playwright-cli
```

Update only:

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/apm-install
```

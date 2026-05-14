# apm-install

This convention uses `apm` to install any specified packages and updating any existing packages.

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

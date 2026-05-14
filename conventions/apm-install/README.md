# apm-install

This convention uses `apm` to install any specified packages and update any existing packages.

`copilot` is the only target currently supported.

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

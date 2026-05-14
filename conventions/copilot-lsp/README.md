# copilot-lsp

Manages project-scoped GitHub Copilot CLI LSP server definitions in `.github/lsp.json`.

## Settings

- `servers`: JSON object whose properties match the `lspServers` entries from the GitHub Copilot CLI LSP configuration format.

The convention writes the configured servers to the `lspServers` property in `.github/lsp.json`. If a configured server name already exists, the convention replaces that server definition instead of merging properties. Other server definitions in the file are preserved. If every configured server already matches exactly, the convention leaves `.github/lsp.json` unchanged.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/copilot-lsp
    settings:
      servers:
        python:
          command: pyright-langserver
          args:
            - --stdio
          fileExtensions:
            .py: python
            .pyw: python
            .pyi: python
        typescript:
          command: typescript-language-server
          args:
            - --stdio
          fileExtensions:
            .ts: typescript
            .tsx: typescriptreact
            .js: javascript
            .jsx: javascriptreact
```

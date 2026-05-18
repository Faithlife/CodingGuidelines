# prettierignore-section

Manages a named section within the repository-root `.prettierignore` file when the repository appears to use [Prettier](https://prettier.io).

## Settings

- `name`: Required non-empty section name used in the managed marker.
- `text`: Required exact `.prettierignore` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.prettierignore` changes.

## Behavior

The convention leaves the repository unchanged when Prettier is not detected. Prettier is detected from an existing `.prettierignore`, a root Prettier configuration file, a root `package.json` `prettier` property, or a direct `prettier` dependency in `dependencies`, `devDependencies`, `peerDependencies`, or `optionalDependencies`.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/prettierignore-section
    commit:
      message: Update .prettierignore
    settings:
      name: build-output
      text: |
        coverage/
        dist/
```

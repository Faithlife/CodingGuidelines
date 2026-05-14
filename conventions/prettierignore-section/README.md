# prettierignore-section

This [convention](https://github.com/Faithlife/RepoConventions) manages a named section within the repository-root `.prettierignore` file when the repository appears to use [Prettier](https://prettier.io).

Settings:

- `name`: Non-empty section name used in the managed marker.
- `text`: Exact `.prettierignore` text to place inside the managed section.
- `agent`: Optional `config-text-section` agent settings to pass through, for example when callers want follow-up instructions after `.prettierignore` changes.

The convention leaves the repository unchanged when Prettier is not detected. Prettier is detected from an existing `.prettierignore`, a root Prettier configuration file, a root `package.json` `prettier` property, or a direct `prettier` dependency in `dependencies`, `devDependencies`, `peerDependencies`, or `optionalDependencies`.

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/prettierignore-section
    commit:
      message: Update .prettierignore.
    settings:
      name: build-output
      text: |
        coverage/
        dist/
```

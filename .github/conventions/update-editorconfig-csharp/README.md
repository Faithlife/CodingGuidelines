# update-editorconfig-csharp

Regenerates [conventions/editorconfig-csharp/files/.editorconfig](../../../conventions/editorconfig-csharp/files/.editorconfig) from the `editorconfig` code fences in [sections/csharp/editorconfig.md](../../../sections/csharp/editorconfig.md).

## Behavior

The generated file starts with a provenance comment, preserves any preamble lines before the first section, sorts indentation-related settings before other settings within each section, and writes LF line endings. The convention has pull request auto-merge enabled for changes it contributes.

## Example

```yaml
conventions:
  - path: .github/conventions/update-editorconfig-csharp
```

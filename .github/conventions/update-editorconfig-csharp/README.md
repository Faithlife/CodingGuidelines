# update-editorconfig-csharp

This local executable convention regenerates [conventions/editorconfig-csharp/.editorconfig](../../../conventions/editorconfig-csharp/.editorconfig) from the `editorconfig` code fences in [sections/csharp/editorconfig.md](../../../sections/csharp/editorconfig.md).

It mirrors the repository's previous `UpdateEditorConfig.ps1` behavior so the published `editorconfig-csharp` convention can consume a generated file that lives next to the convention instead of under `sections/csharp/files`.

Settings:

- None.

The script prepends a generated-from source comment, keeps the first four generated lines in document order, sorts the remaining non-empty lines for a stable output, and only rewrites the destination file when its content changes.
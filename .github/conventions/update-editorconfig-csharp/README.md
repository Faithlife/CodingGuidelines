# update-editorconfig-csharp

This local executable convention regenerates [conventions/editorconfig-csharp/files/.editorconfig](../../../conventions/editorconfig-csharp/files/.editorconfig) from the `editorconfig` code fences in [sections/csharp/editorconfig.md](../../../sections/csharp/editorconfig.md).

This convention does not support any settings.

The generated file starts with a provenance comment, preserves any preamble lines before the first section, sorts indentation-related settings before other settings within each section, and writes LF line endings. The convention has pull request auto-merge enabled for changes it contributes.

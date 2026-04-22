# Editorconfig Convention Design

## Goal

Add a published convention that manages a named section inside the repository root `.editorconfig`.

The convention should:

- Create `.editorconfig` when it is missing.
- Initialize a new file with `root = true` followed by a blank line.
- Add or replace one managed block identified by a required `name` setting.
- Preserve other content in `.editorconfig`, including other managed blocks with different names.
- Stay idempotent.

## Managed Block Format

Each managed block should use these markers:

```editorconfig
# DO NOT EDIT: <name> convention
<raw section text>
# END DO NOT EDIT
```

Example:

```editorconfig
root = true

# DO NOT EDIT: general-editorconfig convention
[*]
charset = utf-8
end_of_line = lf
indent_size = 2
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true
# END DO NOT EDIT
```

The `name` value is the block identity. Multiple conventions may target `.editorconfig` as long as each one uses a distinct name.

## Proposed Convention Shape

This should be an executable convention, not a composite one, because it needs targeted replacement semantics inside a single file.

Recommended published path:

```text
conventions/editorconfig-section
```

Expected files:

- `convention.ps1`
- `README.md`
- `convention.Tests.ps1`

## Settings

- `name`: required non-empty string. This identifies the managed block.
- `text`: optional string containing the exact block contents.
- `textFile`: optional string path to a file containing the block contents.

Exactly one of `text` or `textFile` must be supplied.

### Validation Rules

- `name` must not be blank.
- `name` must not contain carriage returns or line feeds.
- `text` may contain any content except the marker lines themselves.
- `textFile` must resolve to a file relative to the convention definition directory.
- If the target `.editorconfig` contains multiple blocks with the same `name`, the convention should fail instead of guessing.
- If the opening marker exists without a matching `# END DO NOT EDIT`, the convention should fail instead of guessing.

## YAML Syntax

### Inline Text

Use YAML block scalars for short or medium sections:

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/editorconfig-section
  settings:
    name: general-editorconfig
    text: |
      [*]
      charset = utf-8
      end_of_line = lf
      indent_size = 2
      indent_style = space
      insert_final_newline = true
      trim_trailing_whitespace = true
```

### File-Backed Text

For long sections, prefer a sibling file:

```yaml
conventions:
- path: Faithlife/CodingGuidelines/conventions/editorconfig-section
  settings:
    name: csharp-editorconfig
    textFile: csharp.editorconfig
```

Example convention directory:

```text
my-convention/
  convention.yml
  csharp.editorconfig
```

`textFile` should be resolved relative to the convention definition directory, not the target repository root. That keeps long editorconfig fragments close to the convention that owns them and avoids hard-coding repository-specific paths.

## RepoConventions Support Needed

Current convention settings in this repository only show `${{ settings.foo }}` propagation. There is no visible support for reading file content into a setting or for passing the convention directory to the script.

To support `textFile` cleanly, RepoConventions should do one of these:

1. Resolve `textFile` to raw text before serializing `settings` to the convention input JSON.
2. Include the current convention directory in the convention input JSON so `convention.ps1` can resolve `textFile` itself.

The first option is cleaner because it keeps the executable convention focused on `.editorconfig` rewriting instead of framework path resolution.

If RepoConventions is not being extended yet, the first version of this convention should ship with `text` only and add `textFile` later.

## File Update Semantics

The convention should:

1. Target `.editorconfig` at the repository root.
2. If the file is missing, create it as UTF-8 without BOM with this prefix:

   ```editorconfig
   root = true

   ```

3. If the named managed block exists, replace only that block.
4. If the named managed block does not exist, append a new block after a blank line.
5. Leave unrelated unmanaged content untouched.
6. Leave other managed blocks untouched.
7. Preserve the existing file's newline style when the file already exists.
8. Ensure the final file ends with a newline.

The block contents should be written exactly as provided, aside from normalizing line endings to the target file's newline style.

## Suggested Implementation Notes

- Reuse the UTF-8 no BOM write pattern from [conventions/line-based-config/convention.ps1](../conventions/line-based-config/convention.ps1).
- Reuse the existing line-ending detection approach from [conventions/line-based-config/convention.ps1](../conventions/line-based-config/convention.ps1).
- Use a marker-based parser rather than line-by-line append logic.
- Treat malformed or duplicated named blocks as errors.
- Keep output focused, for example `Updated 'general-editorconfig' section in '.editorconfig'.`

## Suggested Tests

- Creates `.editorconfig` with `root = true` and a managed block when the file is missing.
- Appends a managed block to an existing `.editorconfig` without changing unrelated content.
- Replaces an existing managed block with the same `name`.
- Preserves a different managed block with another `name`.
- Fails on duplicate blocks for the same `name`.
- Fails on an unterminated managed block.
- Supports multi-line `text` input.
- Supports `textFile` input once RepoConventions exposes convention-relative file resolution.
- Is idempotent on a second run.

## Recommendation

Start with a published executable convention named `editorconfig-section` using required `name` plus inline `text`.

Add `textFile` only when RepoConventions can resolve convention-relative file content cleanly. That keeps the first implementation small while preserving the YAML shape needed for long editorconfig fragments.

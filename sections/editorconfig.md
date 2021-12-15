# .editorconfig

All git repositories must have an `.editorconfig` file at the root.

As much as possible, we should use `.editorconfig` (rather than other configuration files) to specify our preferred coding styles.

The top of the `.editorconfig` file should look like this:

```editorconfig
root = true

[*]
charset = utf-8
end_of_line = lf
indent_size = 2
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true
```

These settings make good defaults. Extension-specific settings can follow in their own sections.

## C\#

See [.editorconfig for C#](csharp/editorconfig.md).

## JavaScript/TypeScript

See [.editorconfig for JavaScript/TypeScript](javascript/editorconfig.md).

## JSON

```editorconfig
[*.json]
resharper_comment_typo_highlighting = none
resharper_identifier_typo_highlighting = none
resharper_string_literal_typo_highlighting = none
```

Don't highlight "typos" (non-English words) in JSON.

## dotnet

```editorconfig
[dotnet-tools.json]
insert_final_newline = false
```

`dotnet tool install` removes the final newline.

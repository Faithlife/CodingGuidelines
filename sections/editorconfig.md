# .editorconfig

All git repositories must have an `.editorconfig` file at the root.

As much as possible, we should use `.editorconfig` (rather than other configuration files) to specify our preferred coding styles.

The top of the `.editorconfig` file should look like this:

```
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

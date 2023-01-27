# .editorconfig for Kotlin & Java

The standard settings for `charset`, `end_of_line`, `indent_style`, `insert_final_newline`, and `trim_trailing_whitespace` should be inherited from [the `[*]` section](../editorconfig.md).

```editorconfig
[*.{java, kt, kts}]
indent_size=4

[*.{kt, kts}]
max_line_length=100

[*.java]
max_line_length=120
```

## [Language Conventions](https://www.jetbrains.com/help/idea/editorconfig.html)

```editorconfig
[*.{kt, kts}]
ktlint_code_style=android
ij_kotlin_allow_trailing_comma=true
ij_kotlin_allow_trailing_comma_on_call_site=true
```

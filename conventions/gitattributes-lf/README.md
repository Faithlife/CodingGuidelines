# gitattributes-lf

Ensures the repository-root `.gitattributes` starts with `* text=auto eol=lf`.

If it does not, it updates `.gitattributes` and [converts CRLF to LF](../../sections/editorconfig.md).

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/gitattributes-lf
```

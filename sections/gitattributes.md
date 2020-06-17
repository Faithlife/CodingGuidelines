# .gitattributes

All git repositories must have a `.gitattributes` file at the root.

Using a `.gitattributes` file effectively overrides the global `core.autocrlf` git setting, ensuring that different environments don't exhibit different behavior with newlines.

This should be the first line of the `.gitattributes` file:

```
* text=auto eol=lf
```

This causes git to change newlines from CRLF to LF when files are committed, ensuring that files on all platforms use the same newlines, and preventing files with mixed newlines from being committed.

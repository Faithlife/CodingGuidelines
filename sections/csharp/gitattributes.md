# .gitattributes for C#

The first line of `.gitattributes` file should be [as indicated here](../gitattributes.md).

The `.gitattributes` file for a C# repository should also include this line, which improves git handling of C# files in some situations:

```text
*.cs text diff=csharp
```

Repository convention: [gitattributes-csharp](../../conventions/gitattributes-csharp/)

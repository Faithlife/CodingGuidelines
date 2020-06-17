# .gitattributes for C#

The first line of `.gitattributes` file should be [as indicated here](../gitattributes.md).

The `.gitattributes` file for a C# repository should also include these lines, which improve git handling of C# (and related) files in some situations:

```
*.cs text diff=csharp
*.csproj text merge=union
*.sln text merge=union
```

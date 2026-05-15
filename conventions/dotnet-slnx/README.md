# dotnet-slnx

Ensures the repository uses `.slnx` solutions rather than `.sln`.

## Behavior

It also renames `.sln.DotSettings` files to `.slnx.DotSettings` when the corresponding `.slnx` file exists.

## Example

```yaml
conventions:
  - path: Faithlife/CodingGuidelines/conventions/dotnet-slnx
```

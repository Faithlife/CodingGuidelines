# Instructions

- The `.editorconfig` rules for C# have been modified in this repository.

## Remove Obsolete Rules

- The new rules are in the `DO NOT EDIT` section for `csharp`.
- If the rules inside the `DO NOT EDIT` section for `csharp` have made any rules or sections outside any `DO NOT EDIT` section obsolete, remove the obsolete rules. Do not remove obsolete rules inside `DO NOT EDIT` sections.

## Fix Build If Necessary

- Make sure that the .NET code in this repository (if any) still builds successfully, e.g. by running `./build.ps1 build` or `dotnet build`.
- If the .NET code doesn't build successfully, read the error messages, read the affected files, and fix the issues by editing the code.
- DO NOT suppress warnings by adding `<NoWarn>` properties or `#pragma warning` directives.
- If you make changes, build the code again and keep fixing issues until it builds successfully.

## Leave Changes Unstaged

- DO NOT commit any changes to the git repository. Leave your changes unstaged, but don't leave any unintentional changes.

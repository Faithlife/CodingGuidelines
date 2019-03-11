
# C# Coding Guidelines

## Only Override ToString for Debugging Purposes

As a general rule, only override the `ToString` method for debugging purposes, and consider adding the `DebuggerDisplay` attribute instead of overriding `ToString`.

Only when a class has an obvious culture-invariant string rendering should you consider using `ToString` for that purpose.

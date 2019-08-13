# Typescript Coding Guidelines

## Compiler options
When possible, use the `strict` compiler setting to opt in to strict null checks and improved flow analysis. This setting significantly improves the capabilities of TypeScript's tooling. It's usually prohibitively costly to migrate existing projects to pass the stricter requirements, so enable it when the project is bootstrapped.

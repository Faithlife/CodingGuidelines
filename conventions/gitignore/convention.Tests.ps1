Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionYamlPath = Join-Path $PSScriptRoot 'convention.yml'
$readmePath = Join-Path $PSScriptRoot 'README.md'

Describe 'gitignore convention' {
	It 'wraps line-based-config for .gitignore' {
		$yaml = Get-Content -LiteralPath $conventionYamlPath -Raw

		$yaml | Should Match '(?ms)^conventions:\s*- path: \.\./line-based-config\s+settings:\s+path: \.gitignore\s+entries: \$\{\{ settings\.entries \}\}\s*$'
	}

	It 'documents the entries setting' {
		$readme = Get-Content -LiteralPath $readmePath -Raw

		$readme | Should Match '`entries`'
		$readme | Should Match '\.gitignore'
	}
}

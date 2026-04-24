Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionYamlPath = Join-Path $PSScriptRoot 'convention.yml'
$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'

Describe 'editorconfig-csharp convention' {
	It 'composes editorconfig with the C# section text from the shared file' {
		(Test-Path -LiteralPath $conventionYamlPath -PathType Leaf) | Should Be $true

		$actualContent = ((Get-Content -LiteralPath $conventionYamlPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")
		$expectedContent = (@(
			'conventions:',
			'- path: ../editorconfig',
			'  settings:',
			'    name: csharp-editorconfig',
			'    text: ${{ readText("/sections/csharp/files/.editorconfig") }}',
			'    agent: ${{ settings.agent }}'
		) -join "`n")

		$actualContent | Should Be $expectedContent
	}

	It 'does not include a convention script' {
		(Test-Path -LiteralPath $conventionScriptPath) | Should Be $false
	}
}
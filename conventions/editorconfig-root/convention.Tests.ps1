Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionYamlPath = Join-Path $PSScriptRoot 'convention.yml'
$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'

Describe 'editorconfig-root convention' {
	It 'composes editorconfig with the documented general section' {
		(Test-Path -LiteralPath $conventionYamlPath -PathType Leaf) | Should Be $true

		$actualContent = ((Get-Content -LiteralPath $conventionYamlPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")
		$expectedContent = (@(
			'conventions:',
			'- path: ../editorconfig',
			'  settings:',
			'    name: general-editorconfig',
			'    text: |',
			'      [*]',
			'      charset = utf-8',
			'      end_of_line = lf',
			'      trim_trailing_whitespace = true',
			'    agent: ${{ settings.agent }}'
		) -join "`n")

		$actualContent | Should Be $expectedContent
	}

	It 'does not include a convention script' {
		(Test-Path -LiteralPath $conventionScriptPath) | Should Be $false
	}
}
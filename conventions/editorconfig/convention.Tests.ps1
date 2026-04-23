Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionYamlPath = Join-Path $PSScriptRoot 'convention.yml'
$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'

Describe 'editorconfig convention' {
	It 'composes config-text with the expected root line and managed section settings' {
		(Test-Path -LiteralPath $conventionYamlPath -PathType Leaf) | Should Be $true

		$actualContent = ((Get-Content -LiteralPath $conventionYamlPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")
		$expectedContent = (@(
			'conventions:',
			'- path: ../config-text',
			'  settings:',
			'    path: .editorconfig',
			'    lines:',
			'    - root = true',
			'    section:',
			'      name: ${{ settings.name }}',
			'      text: ${{ settings.text }}',
			'      comment-prefix: ''#'''
		) -join "`n")

		$actualContent | Should Be $expectedContent
	}

	It 'does not include a convention script' {
		(Test-Path -LiteralPath $conventionScriptPath) | Should Be $false
	}
}

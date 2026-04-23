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
			'    new-file-text: root = true',
			'    section:',
			'      name: ${{ settings.name }}',
			'      text: ${{ settings.text }}',
			'      comment-prefix: ''#''',
			'    agent:',
			'      instructions: |',
			'        Make sure the code still builds successfully, e.g. by running `./build.ps1 build` or `dotnet build`.',
			'        If the code doesn''t build successfully, read the error messages, read the affected files, and fix the issues by editing the code.',
			'        DO NOT suppress warnings by adding `<NoWarn>` properties or `#pragma warning` directives.',
			'        If you make changes, build the code again and keep fixing issues until it builds successfully.',
			'        DO NOT commit any changes to the git repository. Leave your changes unstaged.'
		) -join "`n")

		$actualContent | Should Be $expectedContent
	}

	It 'does not include a convention script' {
		(Test-Path -LiteralPath $conventionScriptPath) | Should Be $false
	}
}

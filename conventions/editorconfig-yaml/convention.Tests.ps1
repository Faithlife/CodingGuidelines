Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'editorconfig-yaml convention' {
	It 'creates .editorconfig with the YAML indentation section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-yaml
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			$content | Should Match "(?m)^# DO NOT EDIT: yaml convention\r?$"
			$content | Should Match "(?m)^\[\*\.\{yml,yaml\}\]\r?$"
			$content | Should Match "(?m)^indent_style = space\r?$"
			$content | Should Match "(?m)^indent_size = 2\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed YAML section and preserves unrelated content' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-yaml
"@
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.editorconfig') -Content @"
root = true

# DO NOT EDIT: yaml convention
[*.{yml,yaml}]
indent_style = tab
indent_size = 8
# END DO NOT EDIT

[*.md]
trim_trailing_whitespace = false
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			$content | Should Match "(?m)^indent_style = space\r?$"
			$content | Should Match "(?m)^indent_size = 2\r?$"
			$content | Should Match "(?m)^\[\*\.md\]\r?$"
			$content | Should Match "(?m)^trim_trailing_whitespace = false\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
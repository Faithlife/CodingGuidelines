Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'editorconfig-ps1 convention' {
	It 'creates .editorconfig with the PowerShell indentation section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-ps1
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			$content | Should Match "(?m)^# DO NOT EDIT: ps1 convention\r?$"
			$content | Should Match "(?m)^\[\*\.ps1\]\r?$"
			$content | Should Match "(?m)^indent_style = space\r?$"
			$content | Should Match "(?m)^indent_size = 2\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed PowerShell section and preserves unrelated content' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-ps1
"@
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.editorconfig') -Content @"
root = true

# DO NOT EDIT: ps1 convention
[*.ps1]
indent_style = tab
indent_size = 8
# END DO NOT EDIT

[*.json]
indent_size = 4
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			$content | Should Match "(?m)^indent_style = space\r?$"
			$content | Should Match "(?m)^indent_size = 2\r?$"
			$content | Should Match "(?m)^\[\*\.json\]\r?$"
			$content | Should Match "(?m)^indent_size = 4\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
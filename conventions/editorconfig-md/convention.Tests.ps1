#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'editorconfig-md convention' {
	BeforeAll {
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the Markdown indentation section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with the Markdown editorconfig convention enabled.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-md
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the generated editorconfig and packaged section for comparison.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-md/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			# Assert the generated file contains the managed Markdown section.
			$content | Should -Match "(?m)^# DO NOT EDIT: md convention\r?$"
			$content | Should -Match "(?m)^\[\*\.md\]\r?$"
			$normalizedContent.Contains($expectedSection) | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed Markdown section and preserves unrelated content' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with stale managed Markdown settings and unrelated content.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-md
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
root = true

# DO NOT EDIT: md convention
[*.md]
indent_style = tab
indent_size = 8
# END DO NOT EDIT

[*.json]
indent_size = 4
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the updated editorconfig and packaged section for comparison.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-md/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			# Assert the managed section changed while unrelated settings remained.
			$normalizedContent.Contains($expectedSection) | Should -Be $true
			$content | Should -Match "(?m)^\[\*\.json\]\r?$"
			$content | Should -Match "(?m)^indent_size = 4\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

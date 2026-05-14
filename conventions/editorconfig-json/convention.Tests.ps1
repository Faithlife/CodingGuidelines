#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'editorconfig-json convention' {
	BeforeAll {
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the JSON indentation section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with the JSON editorconfig convention enabled.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-json
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the generated editorconfig and packaged section for comparison.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-json/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			# Assert the generated file contains the managed JSON section.
			$content | Should -Match "(?m)^# DO NOT EDIT: json convention\r?$"
			$content | Should -Match "(?m)^\[\*\.json\]\r?$"
			$normalizedContent.Contains($expectedSection) | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed JSON section and preserves unrelated content' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with stale managed JSON settings and unrelated content.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-json
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
root = true

# DO NOT EDIT: json convention
[*.json]
indent_style = tab
indent_size = 8
# END DO NOT EDIT

[*.ps1]
indent_size = 4
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the updated editorconfig and packaged section for comparison.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-json/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			# Assert the managed section changed while unrelated settings remained.
			$normalizedContent.Contains($expectedSection) | Should -Be $true
			$content | Should -Match "(?m)^\[\*\.ps1\]\r?$"
			$content | Should -Match "(?m)^indent_size = 4\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'runs Copilot with the packaged instructions when it changes .editorconfig' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository and capture the packaged Copilot instructions.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			$testCopilot = New-TestCopilotCommand -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-json
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory
			$expectedInstructions = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-json/agent-instructions.md') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			# Apply the convention with a test Copilot command directory.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory -CopilotCommandDirectory $testCopilot.CommandDirectory } | Should -Not -Throw

			# Assert Copilot received the packaged instructions exactly.
			(Test-Path -LiteralPath $testCopilot.InputPath) | Should -Be $true
			(((Get-Content -LiteralPath $testCopilot.InputPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")) | Should -Be $expectedInstructions
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

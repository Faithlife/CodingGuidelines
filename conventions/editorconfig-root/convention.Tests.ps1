#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'editorconfig-root convention' {
	BeforeAll {
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the default root section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with the root editorconfig convention enabled.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-root
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the generated editorconfig for assertions.
			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw

			# Assert the generated file contains the managed root section.
			(Test-Path -LiteralPath $editorConfigPath) | Should -Be $true
			$content | Should -Match "(?m)^root = true\r?$"
			$content | Should -Match "(?m)^# DO NOT EDIT: root convention\r?$"
			$content | Should -Match "(?m)^\[\*\]\r?$"
			$content | Should -Match "(?m)^charset = utf-8\r?$"
			$content | Should -Match "(?m)^end_of_line = lf\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = true\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed root section and preserves unrelated content' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with stale managed root settings and unrelated content.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-root
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
# DO NOT EDIT: root convention
root = true

[*]
charset = latin1
# END DO NOT EDIT

[*.md]
trim_trailing_whitespace = false
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the updated editorconfig for assertions.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			# Assert the root section changed while unrelated settings remained.
			$content | Should -Match "(?m)^charset = utf-8\r?$"
			$content | Should -Match "(?m)^end_of_line = lf\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = true\r?$"
			$content | Should -Match "(?m)^\[\*\.md\]\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = false\r?$"
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
- path: ../conventions/editorconfig-root
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory
			$expectedInstructions = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-root/agent-instructions.md') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

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

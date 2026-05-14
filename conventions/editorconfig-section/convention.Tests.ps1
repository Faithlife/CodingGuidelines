#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'editorconfig-section convention' {
	BeforeAll {
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the configured managed section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a configured editorconfig section.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: files
    text: |
      [*.txt]
      indent_style = space
      trim_trailing_whitespace = false
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the generated editorconfig for assertions.
			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw

			# Assert the configured managed section was written exactly.
			(Test-Path -LiteralPath $editorConfigPath) | Should -Be $true
			$content | Should -Match "(?m)^# DO NOT EDIT: files convention\r?$"
			$content | Should -Match "(?m)^\[\*\.txt\]\r?$"
			$content | Should -Match "(?m)^indent_style = space\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = false\r?$"
			$content | Should -Match "(?m)^# END DO NOT EDIT\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'forwards agent instructions when it changes .editorconfig' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with inline agent instructions.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			$testCopilot = New-TestCopilotCommand -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: files
    text: |
      [*.md]
      trim_trailing_whitespace = false
    agent:
      instructions: |
        Validate editorconfig changes.
        Leave fixes unstaged.
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention with a test Copilot command directory.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory -CopilotCommandDirectory $testCopilot.CommandDirectory } | Should -Not -Throw

			# Assert Copilot received the configured instructions exactly.
			(Test-Path -LiteralPath $testCopilot.InputPath) | Should -Be $true
			(((Get-Content -LiteralPath $testCopilot.InputPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")) | Should -Be "Validate editorconfig changes.`nLeave fixes unstaged."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses native commit settings when it changes .editorconfig' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a configured commit message.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), '{"conventions":[{"path":"../conventions/editorconfig-section","commit":{"message":"Add editorconfig"},"settings":{"name":"files","text":"[*.md]\ntrim_trailing_whitespace = false\n"}}]}', $utf8)
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and allow it to create the configured commit.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the configured commit message and clean working tree.
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Add editorconfig'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

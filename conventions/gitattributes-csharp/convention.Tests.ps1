#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'gitattributes-csharp convention' {
	BeforeAll {
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .gitattributes with the shared C# section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with the C# gitattributes convention enabled.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/gitattributes-csharp
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the generated gitattributes and packaged section for comparison.
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			$content = Get-Content -LiteralPath $gitattributesPath -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/gitattributes-csharp/files/.gitattributes') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			# Assert the generated file contains the managed C# section.
			(Test-Path -LiteralPath $gitattributesPath) | Should -Be $true
			$content | Should -Match "(?m)^# DO NOT EDIT: csharp convention\r?$"
			$content | Should -Match "(?m)^\*\.cs text diff=csharp\r?$"
			$content | Should -Match "(?m)^# END DO NOT EDIT\r?$"
			$normalizedContent.Contains($expectedSection) | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'commits .gitattributes changes with the packaged commit message' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with the C# gitattributes convention enabled.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/gitattributes-csharp
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and allow it to create its packaged commit.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the commit message and clean working tree match expectations.
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Update .gitattributes for C#'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

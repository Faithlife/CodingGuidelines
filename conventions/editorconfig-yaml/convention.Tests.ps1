#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'editorconfig-yaml convention' {
	BeforeAll {
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath
	}

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

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-yaml/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			$content | Should -Match "(?m)^# DO NOT EDIT: yaml convention\r?$"
			$content | Should -Match "(?m)^\[\*\.\{yml,yaml\}\]\r?$"
			$normalizedContent.Contains($expectedSection) | Should -Be $true
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

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-yaml/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			$normalizedContent.Contains($expectedSection) | Should -Be $true
			$content | Should -Match "(?m)^\[\*\.md\]\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = false\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'commits .editorconfig changes with the packaged commit message' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-yaml
"@
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Update YAML editorconfig settings.'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
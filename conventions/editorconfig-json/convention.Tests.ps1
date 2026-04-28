#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'editorconfig-json convention' {
	BeforeAll {
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the JSON indentation section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-json
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-json/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			$content | Should -Match "(?m)^# DO NOT EDIT: json convention\r?$"
			$content | Should -Match "(?m)^\[\*\.json\]\r?$"
			$normalizedContent.Contains($expectedSection) | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed JSON section and preserves unrelated content' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-json
"@
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.editorconfig') -Content @"
root = true

# DO NOT EDIT: json convention
[*.json]
indent_style = tab
indent_size = 8
# END DO NOT EDIT

[*.ps1]
indent_size = 4
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-json/files/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			$normalizedContent.Contains($expectedSection) | Should -Be $true
			$content | Should -Match "(?m)^\[\*\.ps1\]\r?$"
			$content | Should -Match "(?m)^indent_size = 4\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'runs Copilot with the packaged instructions when it changes .editorconfig' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			$testCopilot = New-TestCopilotCommand -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-json
"@
			Initialize-TestRepository -Path $testDirectory
			$expectedInstructions = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-json/agent-instructions.md') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory -CopilotCommandDirectory $testCopilot.CommandDirectory } | Should -Not -Throw

			(Test-Path -LiteralPath $testCopilot.InputPath) | Should -Be $true
			(((Get-Content -LiteralPath $testCopilot.InputPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")) | Should -Be $expectedInstructions
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
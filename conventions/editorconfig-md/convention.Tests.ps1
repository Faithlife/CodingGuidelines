Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'editorconfig-md convention' {
	It 'creates .editorconfig with the Markdown indentation section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-md
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-md/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			$content | Should Match "(?m)^# DO NOT EDIT: md convention\r?$"
			$content | Should Match "(?m)^\[\*\.md\]\r?$"
			$normalizedContent.Contains($expectedSection) | Should Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed Markdown section and preserves unrelated content' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-md
"@
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.editorconfig') -Content @"
root = true

# DO NOT EDIT: md convention
[*.md]
indent_style = tab
indent_size = 8
# END DO NOT EDIT

[*.json]
indent_size = 4
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-md/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			$normalizedContent.Contains($expectedSection) | Should Be $true
			$content | Should Match "(?m)^\[\*\.json\]\r?$"
			$content | Should Match "(?m)^indent_size = 4\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
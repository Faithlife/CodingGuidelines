Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'editorconfig-root convention' {
	It 'creates .editorconfig with the default root section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-root
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw

			(Test-Path -LiteralPath $editorConfigPath) | Should Be $true
			$content | Should Match "(?m)^root = true\r?$"
			$content | Should Match "(?m)^# DO NOT EDIT: root convention\r?$"
			$content | Should Match "(?m)^\[\*\]\r?$"
			$content | Should Match "(?m)^charset = utf-8\r?$"
			$content | Should Match "(?m)^end_of_line = lf\r?$"
			$content | Should Match "(?m)^trim_trailing_whitespace = true\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed root section and preserves unrelated content' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-root
"@
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.editorconfig') -Content @"
root = true

# DO NOT EDIT: root convention
[*]
charset = latin1
# END DO NOT EDIT

[*.md]
trim_trailing_whitespace = false
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			$content | Should Match "(?m)^charset = utf-8\r?$"
			$content | Should Match "(?m)^end_of_line = lf\r?$"
			$content | Should Match "(?m)^trim_trailing_whitespace = true\r?$"
			$content | Should Match "(?m)^\[\*\.md\]\r?$"
			$content | Should Match "(?m)^trim_trailing_whitespace = false\r?$"
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
- path: ../conventions/editorconfig-root
"@
			Initialize-TestRepository -Path $testDirectory
			$originalPath = $env:PATH
			$expectedInstructions = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-root/agent-instructions.md') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			try {
				$env:PATH = "$($testCopilot.CommandDirectory);$originalPath"
				{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw
			}
			finally {
				$env:PATH = $originalPath
			}

			(Test-Path -LiteralPath $testCopilot.InputPath) | Should Be $true
			(((Get-Content -LiteralPath $testCopilot.InputPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")) | Should Be $expectedInstructions
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
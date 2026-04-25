Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'editorconfig-csharp convention' {
	It 'creates .editorconfig with the shared C# section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			$testCopilot = New-TestCopilotCommand -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig-csharp
"@
			Initialize-TestRepository -Path $testDirectory
			$originalPath = $env:PATH

			try {
				$env:PATH = "$($testCopilot.CommandDirectory);$originalPath"
				{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw
			}
			finally {
				$env:PATH = $originalPath
			}

			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw
			$normalizedContent = ($content -replace "`r`n", "`n")
			$expectedSection = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-csharp/.editorconfig') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

			(Test-Path -LiteralPath $editorConfigPath) | Should Be $true
			$content | Should Match "(?m)^root = true\r?$"
			$content | Should Match "(?m)^# DO NOT EDIT: csharp convention\r?$"
			$content | Should Match "(?m)^# generated from https://github.com/Faithlife/CodingGuidelines/blob/master/sections/csharp/editorconfig\.md\r?$"
			$content | Should Match "(?m)^\[\*\.\{cs,cshtml,razor\}\]\r?$"
			$normalizedContent.Contains($expectedSection) | Should Be $true
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
- path: ../conventions/editorconfig-csharp
"@
			Initialize-TestRepository -Path $testDirectory
			$originalPath = $env:PATH
			$expectedInstructions = ((Get-Content -LiteralPath (Join-Path $testDirectory 'conventions/editorconfig-csharp/agent-instructions.md') -Raw) -replace "`r`n", "`n").TrimEnd("`n")

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
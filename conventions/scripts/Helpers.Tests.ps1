#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'convention script helpers' {
	BeforeAll {
		# Load shared test helpers once for all helper behavior tests.
		$script:testHelpersPath = Join-Path $PSScriptRoot 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'runs Copilot with COPILOT_HOME instead of deprecated config-dir' {
		$testDirectory = New-TemporaryDirectory
		$originalPath = $env:PATH
		$originalCopilotHome = Get-Item -LiteralPath Env:\COPILOT_HOME -ErrorAction SilentlyContinue
		$originalCopilotFunction = Get-Command -Name copilot -CommandType Function -ErrorAction SilentlyContinue

		try {
			Remove-Item -Path Function:\copilot -ErrorAction SilentlyContinue

			$testCopilot = New-TestCopilotCommand -TestDirectory $testDirectory
			$env:PATH = "$($testCopilot.CommandDirectory)$([System.IO.Path]::PathSeparator)$originalPath"
			$env:COPILOT_HOME = 'original-copilot-home'

			Invoke-CopilotWithIsolatedConfig -Instructions "Review these changes.`n"

			# Assert Copilot received the supported settings through args and environment.
			$capturedArguments = (Get-Content -LiteralPath $testCopilot.ArgumentsPath -Raw).Trim()
			$capturedCopilotHome = (Get-Content -LiteralPath $testCopilot.CopilotHomePath -Raw).Trim()

			$capturedArguments | Should -Be '--no-ask-user --allow-all-tools --allow-all-paths --model auto'
			$capturedCopilotHome | Should -Not -Be 'original-copilot-home'
			[System.String]::IsNullOrWhiteSpace($capturedCopilotHome) | Should -Be $false
			$env:COPILOT_HOME | Should -Be 'original-copilot-home'
		}
		finally {
			$env:PATH = $originalPath

			if ($null -eq $originalCopilotHome) {
				Remove-Item -LiteralPath Env:\COPILOT_HOME -ErrorAction SilentlyContinue
			}
			else {
				Set-Item -LiteralPath Env:\COPILOT_HOME -Value $originalCopilotHome.Value
			}

			if ($null -ne $originalCopilotFunction) {
				Set-Item -Path Function:\copilot -Value $originalCopilotFunction.ScriptBlock
			}

			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

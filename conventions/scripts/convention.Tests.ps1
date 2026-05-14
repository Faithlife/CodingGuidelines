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

	It 'sets console and native pipeline encodings to UTF-8 without BOM' {
		# Capture original encodings so the test can restore process state.
		$originalInputEncoding = [Console]::InputEncoding
		$originalOutputEncoding = [Console]::OutputEncoding
		$hadOriginalPipelineEncoding = Test-Path -LiteralPath variable:script:OutputEncoding
		$originalPipelineEncoding = if ($hadOriginalPipelineEncoding) { $script:OutputEncoding } else { $null }

		try {
			# Start from ASCII encodings to prove the helper updates each stream.
			[Console]::InputEncoding = [System.Text.Encoding]::ASCII
			[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
			$script:OutputEncoding = [System.Text.Encoding]::ASCII

			Set-Utf8NoBomConsoleEncoding

			# Assert all configured encodings are UTF-8 and omit byte order marks.
			[Console]::InputEncoding.WebName | Should -Be 'utf-8'
			[Console]::OutputEncoding.WebName | Should -Be 'utf-8'
			$script:OutputEncoding.WebName | Should -Be 'utf-8'
			[Console]::OutputEncoding.GetPreamble().Length | Should -Be 0
			$script:OutputEncoding.GetPreamble().Length | Should -Be 0
		}
		finally {
			# Restore console encodings and the script-scope pipeline variable.
			[Console]::InputEncoding = $originalInputEncoding
			[Console]::OutputEncoding = $originalOutputEncoding

			if ($hadOriginalPipelineEncoding) {
				$script:OutputEncoding = $originalPipelineEncoding
			}
			else {
				Remove-Variable -Name OutputEncoding -Scope Script -ErrorAction SilentlyContinue
			}
		}
	}

	It 'runs Copilot with COPILOT_HOME instead of deprecated config-dir' {
		$testDirectory = New-TestDirectory
		$originalPath = $env:PATH
		$originalCopilotHome = Get-Item -LiteralPath Env:\COPILOT_HOME -ErrorAction SilentlyContinue

		try {
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

			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

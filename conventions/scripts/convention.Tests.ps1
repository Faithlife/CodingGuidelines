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
}

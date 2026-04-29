#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'convention script helpers' {
	BeforeAll {
		$script:testHelpersPath = Join-Path $PSScriptRoot 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'sets console and native pipeline encodings to UTF-8 without BOM' {
		$originalInputEncoding = [Console]::InputEncoding
		$originalOutputEncoding = [Console]::OutputEncoding
		$originalPipelineEncoding = $script:OutputEncoding

		try {
			[Console]::InputEncoding = [System.Text.Encoding]::ASCII
			[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
			$script:OutputEncoding = [System.Text.Encoding]::ASCII

			Set-Utf8NoBomConsoleEncoding

			[Console]::InputEncoding.WebName | Should -Be 'utf-8'
			[Console]::OutputEncoding.WebName | Should -Be 'utf-8'
			$script:OutputEncoding.WebName | Should -Be 'utf-8'
			[Console]::OutputEncoding.GetPreamble().Length | Should -Be 0
			$script:OutputEncoding.GetPreamble().Length | Should -Be 0
		}
		finally {
			[Console]::InputEncoding = $originalInputEncoding
			[Console]::OutputEncoding = $originalOutputEncoding
			$script:OutputEncoding = $originalPipelineEncoding
		}
	}
}

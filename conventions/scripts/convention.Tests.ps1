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
		$originalPipelineEncodingVariable = Get-Variable -Name OutputEncoding -Scope Script -ErrorAction SilentlyContinue

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

			if ($null -ne $originalPipelineEncodingVariable) {
				$script:OutputEncoding = $originalPipelineEncodingVariable.Value
			}
			else {
				Remove-Variable -Name OutputEncoding -Scope Script -ErrorAction SilentlyContinue
			}
		}
	}

	It 'passes native Copilot output through as UTF-8' {
		$testDirectory = New-TestDirectory

		try {
			$copilot = New-TestCopilotCommand -TestDirectory $testDirectory -OutputText "$([char] 0x25CF) 23 files found`n$([char] 0x25E6) `"global.json`"`n"
			$copilotBootstrapDirectory = Join-Path $testDirectory '.test-copilot-bootstrap'
			[System.IO.Directory]::CreateDirectory($copilotBootstrapDirectory) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $copilotBootstrapDirectory 'copilot.ps1') -Content @'
Write-Output 'PowerShell bootstrapper should not be used.'
exit 87
'@
			$invokePath = Join-Path $testDirectory 'invoke-copilot.ps1'
			Write-Utf8NoBomFile -Path $invokePath -Content @'
param([string] $HelpersPath)
. $HelpersPath
Invoke-CopilotWithIsolatedConfig -Instructions 'check global.json'
'@

			$startInfo = [System.Diagnostics.ProcessStartInfo]::new('pwsh')
			$startInfo.ArgumentList.Add('-NoProfile')
			$startInfo.ArgumentList.Add('-File')
			$startInfo.ArgumentList.Add($invokePath)
			$startInfo.ArgumentList.Add((Join-Path $PSScriptRoot 'Helpers.ps1'))
			$startInfo.RedirectStandardOutput = $true
			$startInfo.RedirectStandardError = $true
			$startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
			$startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
			$startInfo.UseShellExecute = $false
			$startInfo.Environment['PATH'] = "$copilotBootstrapDirectory$([System.IO.Path]::PathSeparator)$($copilot.CommandDirectory)"

			$process = [System.Diagnostics.Process]::Start($startInfo)
			$output = $process.StandardOutput.ReadToEnd()
			$errorOutput = $process.StandardError.ReadToEnd()
			$process.WaitForExit()

			$process.ExitCode | Should -Be 0
			$output | Should -Match ([regex]::Escape("$([char] 0x25CF) 23 files found"))
			$output | Should -Match ([regex]::Escape("$([char] 0x25E6) `"global.json`""))
			$errorOutput | Should -Be ''
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

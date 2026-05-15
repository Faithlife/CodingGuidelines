#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'config text section module' {
	It 'exports only the commands used by convention clients' {
		# Import the module and inspect the public command surface.
		$modulePath = Join-Path $PSScriptRoot 'ConfigTextSection.psm1'
		$module = Import-Module $modulePath -Force -PassThru

		try {
			$exportedCommandNames = @($module.ExportedCommands.Keys | Sort-Object)
			($exportedCommandNames -join ',') | Should -Be 'Invoke-ConfigTextSection,Read-ConventionSettings'
		}
		finally {
			Remove-Module -Name $module.Name -Force -ErrorAction SilentlyContinue
		}
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load shared helper functions for deterministic file publishing.
$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

# Copy the published contributor guidance when the repository differs.
$sourcePath = Join-Path $PSScriptRoot 'files' 'CONTRIBUTING.md'
$destinationPath = Join-Path (Get-Location) 'CONTRIBUTING.md'
$result = Copy-FileIfDifferent -SourcePath $sourcePath -DestinationPath $destinationPath

if ($result.Changed) {
	Write-Host "Updated 'CONTRIBUTING.md'."
}

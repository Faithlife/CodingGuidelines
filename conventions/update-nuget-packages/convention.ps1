#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Validate settings early so convention failures are reported before the .NET app runs.
$conventionInput = Get-Content -Raw $args[0] | ConvertFrom-Json -AsHashtable
$settings = if ($conventionInput.ContainsKey('settings') -and $null -ne $conventionInput.settings) { $conventionInput.settings } else { @{} }

if ($settings.ContainsKey('rules') -and $settings.rules -isnot [object[]]) {
	throw "The 'rules' setting must be an array."
}

# Run the checked-in .NET 10 file-based app from the target repository root.
$appPath = Join-Path $PSScriptRoot 'convention.cs'
& dotnet $appPath $args[0]

if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

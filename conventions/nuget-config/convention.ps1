#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

# Resolve the published and target NuGet config paths.
$sourceNuGetConfigPath = Join-Path $PSScriptRoot 'files' 'nuget.config'
$targetNuGetConfigPath = Join-Path (Get-Location) 'nuget.config'
$existingNuGetConfigItem = Get-Item -LiteralPath $targetNuGetConfigPath -ErrorAction SilentlyContinue

# Detect case-insensitive NuGet config files that need normalization.
if ($null -eq $existingNuGetConfigItem) {
	$nonLowercaseNuGetConfigItems = @(
		Get-ChildItem -LiteralPath (Get-Location) -File |
			Where-Object { $_.Name -ieq 'nuget.config' -and $_.Name -cne 'nuget.config' }
	)

	if ($nonLowercaseNuGetConfigItems.Count -gt 1) {
		$matchingNuGetConfigNames = ($nonLowercaseNuGetConfigItems | Select-Object -ExpandProperty Name) -join "', '"
		throw "Found multiple non-lowercase NuGet config files: '$matchingNuGetConfigNames'."
	}

	if ($nonLowercaseNuGetConfigItems.Count -eq 1) {
		$existingNuGetConfigItem = $nonLowercaseNuGetConfigItems[0]
	}
}

# Create nuget.config from the published template when none exists.
if ($null -eq $existingNuGetConfigItem) {
	$copyResult = Copy-FileIfDifferent -SourcePath $sourceNuGetConfigPath -DestinationPath $targetNuGetConfigPath

	if (-not $copyResult.Created) {
		throw "Expected '$targetNuGetConfigPath' to be created."
	}

	Write-Host "Created '$targetNuGetConfigPath' from the published NuGet config."
	return
}

# Rename a differently-cased NuGet config file to the canonical name.
if ($existingNuGetConfigItem.Name -cne 'nuget.config') {
	$existingNuGetConfigPath = Join-Path (Get-Location) $existingNuGetConfigItem.Name
	& git mv -f -- $existingNuGetConfigItem.Name 'nuget.config'

	if ($LASTEXITCODE -ne 0) {
		throw "Failed to rename '$existingNuGetConfigPath' to '$targetNuGetConfigPath'."
	}

	$existingNuGetConfigItem = Get-Item -LiteralPath $targetNuGetConfigPath
}

# Exit when the target already matches the published template.
if (Test-FileContentMatches -ExpectedPath $sourceNuGetConfigPath -ActualPath $targetNuGetConfigPath) {
	return
}

# Replace stale NuGet config content with the published template.
$copyResult = Copy-FileIfDifferent -SourcePath $sourceNuGetConfigPath -DestinationPath $targetNuGetConfigPath

if (-not $copyResult.Updated) {
	throw "Expected '$targetNuGetConfigPath' to be replaced."
}

Write-Host "Replaced '$targetNuGetConfigPath' with the published NuGet config."

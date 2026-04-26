#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

$sourceNuGetConfigPath = Join-Path $PSScriptRoot 'files\nuget.config'
$targetNuGetConfigPath = Join-Path (Get-Location) 'nuget.config'
$existingNuGetConfigItem = Get-Item -LiteralPath $targetNuGetConfigPath -ErrorAction SilentlyContinue

if ($null -eq $existingNuGetConfigItem) {
	$copyResult = Copy-FileIfDifferent -SourcePath $sourceNuGetConfigPath -DestinationPath $targetNuGetConfigPath

	if (-not $copyResult.Created) {
		throw "Expected '$targetNuGetConfigPath' to be created."
	}

	Write-Host "Created '$targetNuGetConfigPath' from the published NuGet config."
	return
}

if ($existingNuGetConfigItem.Name -cne 'nuget.config') {
	$existingNuGetConfigPath = Join-Path (Get-Location) $existingNuGetConfigItem.Name
	& git mv -f -- $existingNuGetConfigItem.Name 'nuget.config'

	if ($LASTEXITCODE -ne 0) {
		throw "Failed to rename '$existingNuGetConfigPath' to '$targetNuGetConfigPath'."
	}

	$existingNuGetConfigItem = Get-Item -LiteralPath $targetNuGetConfigPath
}

if (Test-FileContentMatches -ExpectedPath $sourceNuGetConfigPath -ActualPath $targetNuGetConfigPath) {
	Write-Host "'$targetNuGetConfigPath' already matches the published NuGet config."
	return
}

Write-Warning "Existing '$targetNuGetConfigPath' does not match the published NuGet config; leaving it unchanged."

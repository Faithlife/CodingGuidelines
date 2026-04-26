#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

$sourceNuGetConfigPath = Join-Path $PSScriptRoot 'files\nuget.config'
$targetNuGetConfigPath = Join-Path (Get-Location) 'nuget.config'

if (-not (Test-Path -LiteralPath $targetNuGetConfigPath -PathType Leaf)) {
	$copyResult = Copy-FileIfDifferent -SourcePath $sourceNuGetConfigPath -DestinationPath $targetNuGetConfigPath

	if (-not $copyResult.Created) {
		throw "Expected '$targetNuGetConfigPath' to be created."
	}

	Write-Host "Created '$targetNuGetConfigPath' from the published NuGet config."
	return
}

if (Test-FileContentMatches -ExpectedPath $sourceNuGetConfigPath -ActualPath $targetNuGetConfigPath) {
	Write-Host "'$targetNuGetConfigPath' already matches the published NuGet config."
	return
}

Write-Warning "Existing '$targetNuGetConfigPath' does not match the published NuGet config; leaving it unchanged."

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

$templateLicensePath = Join-Path $PSScriptRoot 'LICENSE'
$targetLicensePath = Join-Path (Get-Location) 'LICENSE'
$currentUtcYear = [DateTime]::UtcNow.Year.ToString([System.Globalization.CultureInfo]::InvariantCulture)
$templateContent = Get-Content -LiteralPath $templateLicensePath -Raw
$renderedLicenseContent = $templateContent.Replace('<YEAR>', $currentUtcYear)

if (-not (Test-Path -LiteralPath $targetLicensePath -PathType Leaf)) {
	Write-Utf8NoBomFile -Path $targetLicensePath -Content $renderedLicenseContent
	Write-Host "Created '$targetLicensePath' from the published MIT license."
	return
}

$existingContent = Get-Content -LiteralPath $targetLicensePath -Raw

if ($existingContent -eq $renderedLicenseContent) {
	Write-Host "'$targetLicensePath' already matches the published MIT license."
	return
}

Write-Utf8NoBomFile -Path $targetLicensePath -Content $renderedLicenseContent
Write-Host "Replaced '$targetLicensePath' with the published MIT license."

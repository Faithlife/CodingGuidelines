#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

# Require and read the convention input settings.
if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$settings = Read-ConventionSettings -InputPath $args[0]

if ($null -eq $settings -or -not $settings.ContainsKey('copyright-holder')) {
	throw "The 'copyright-holder' setting is required."
}

# Validate the configured copyright holder.
$copyrightHolder = $settings['copyright-holder']

if ($copyrightHolder -isnot [string] -or [string]::IsNullOrWhiteSpace($copyrightHolder)) {
	throw "The 'copyright-holder' setting must be a non-empty string."
}

# Render the MIT license template for the current year.
$templateLicensePath = Join-Path $PSScriptRoot 'files' 'LICENSE'
$targetLicensePath = Join-Path (Get-Location) 'LICENSE'
$currentUtcYear = [DateTime]::UtcNow.Year.ToString([System.Globalization.CultureInfo]::InvariantCulture)
$templateContent = Get-Content -LiteralPath $templateLicensePath -Raw
$renderedLicenseContent = $templateContent.Replace('<YEAR>', $currentUtcYear).Replace('<COPYRIGHT-HOLDER>', $copyrightHolder)

# Create the license file when it is missing.
if (-not (Test-Path -LiteralPath $targetLicensePath -PathType Leaf)) {
	Write-Utf8NoBomFile -Path $targetLicensePath -Content $renderedLicenseContent
	Write-Host "Created '$targetLicensePath' from the published MIT license."
	return
}

$existingContent = Get-Content -LiteralPath $targetLicensePath -Raw

# Exit when the existing license already matches the rendered template.
if ($existingContent -eq $renderedLicenseContent) {
	Write-Host "'$targetLicensePath' already matches the published MIT license."
	return
}

# Replace stale license content with the rendered template.
Write-Utf8NoBomFile -Path $targetLicensePath -Content $renderedLicenseContent
Write-Host "Replaced '$targetLicensePath' with the published MIT license."

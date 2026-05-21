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

# Load the published package sources and the existing NuGet config as XML documents.
$sourceDoc = [System.Xml.XmlDocument]::new()
$sourceDoc.Load($sourceNuGetConfigPath)
$sourcePackageSources = $sourceDoc.DocumentElement.SelectSingleNode('packageSources')

$targetContent = [System.IO.File]::ReadAllText($targetNuGetConfigPath)
$targetDoc = [System.Xml.XmlDocument]::new()

try {
	$targetDoc.LoadXml($targetContent)
}
catch {
	throw "Cannot update '$targetNuGetConfigPath' because it is not valid XML: $_"
}

$targetPackageSources = $targetDoc.DocumentElement.SelectSingleNode('packageSources')

if ($null -eq $targetPackageSources) {
	throw "Cannot update '$targetNuGetConfigPath' because it does not contain a <packageSources> element."
}

# Serialize a packageSources node to a canonical string for comparison.
function ConvertPackageSourcesToString {
	param(
		[Parameter(Mandatory = $true)]
		[System.Xml.XmlNode] $Node
	)

	$stringWriter = [System.IO.StringWriter]::new()
	$settings = [System.Xml.XmlWriterSettings]::new()
	$settings.Indent = $true
	$settings.IndentChars = '  '
	$settings.OmitXmlDeclaration = $true
	$settings.NewLineChars = "`n"
	$settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

	$writer = [System.Xml.XmlWriter]::Create($stringWriter, $settings)
	$Node.WriteTo($writer)
	$writer.Flush()
	return $stringWriter.ToString()
}

# Exit when the existing packageSources already matches the published template.
$sourcePackageSourcesText = ConvertPackageSourcesToString -Node $sourcePackageSources
$targetPackageSourcesText = ConvertPackageSourcesToString -Node $targetPackageSources

if ($sourcePackageSourcesText -ceq $targetPackageSourcesText) {
	return
}

# Replace only the packageSources element, preserving all other sections.
$importedPackageSources = $targetDoc.ImportNode($sourcePackageSources, $true)
$targetDoc.DocumentElement.ReplaceChild($importedPackageSources, $targetPackageSources) | Out-Null

$xmlSettings = [System.Xml.XmlWriterSettings]::new()
$xmlSettings.Indent = $true
$xmlSettings.IndentChars = '  '
$xmlSettings.Encoding = $utf8
$xmlSettings.NewLineChars = "`n"
$xmlSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

# Write the updated document.
$stream = [System.IO.MemoryStream]::new()
$xmlWriter = [System.Xml.XmlWriter]::Create($stream, $xmlSettings)
$targetDoc.Save($xmlWriter)
$xmlWriter.Flush()
$newContent = $utf8.GetString($stream.ToArray())

if ($newContent -ceq $targetContent) {
	return
}

[System.IO.File]::WriteAllText($targetNuGetConfigPath, $newContent, $utf8)
Write-Host "Updated package sources in '$targetNuGetConfigPath'."

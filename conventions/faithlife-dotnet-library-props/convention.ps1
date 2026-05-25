#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load shared helpers and the managed section writer.
$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath
$configTextSectionPath = Join-Path $PSScriptRoot '..' 'scripts' 'ConfigTextSection.psm1'
Import-Module $configTextSectionPath

function GetSettingValue {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings,

		[Parameter(Mandatory = $true)]
		[string] $Name
	)

	# Return an explicitly configured setting when present.
	if ($Settings.ContainsKey($Name)) {
		return $Settings[$Name]
	}

	return $null
}

function GetExistingPropertyValue {
	param(
		[AllowNull()]
		[xml] $Document,

		[Parameter(Mandatory = $true)]
		[string] $Name
	)

	# Missing documents have no existing property values to reuse.
	if ($null -eq $Document) {
		return $null
	}

	# Read the first matching property independent of XML namespace usage.
	$node = $Document.SelectSingleNode("/*[local-name()='Project']/*[local-name()='PropertyGroup']/*[local-name()='$Name']")
	if ($null -eq $node) {
		return $null
	}

	return $node.InnerText
}

function GetConfiguredPropertyValue {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings,

		[AllowNull()]
		[xml] $Document,

		[Parameter(Mandatory = $true)]
		[string] $SettingName,

		[Parameter(Mandatory = $true)]
		[string] $PropertyName,

		[AllowNull()]
		[string] $DefaultValue
	)

	# Prefer explicit convention settings, then existing repository values, then defaults.
	$settingValue = GetSettingValue -Settings $Settings -Name $SettingName
	if ($null -ne $settingValue) {
		return [string] $settingValue
	}

	$existingValue = GetExistingPropertyValue -Document $Document -Name $PropertyName
	if (-not [string]::IsNullOrWhiteSpace($existingValue)) {
		return $existingValue
	}

	return $DefaultValue
}

function GetConfiguredBooleanValue {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings,

		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[bool] $DefaultValue
	)

	# Preserve boolean setting values and accept string booleans from YAML.
	$settingValue = GetSettingValue -Settings $Settings -Name $Name
	if ($null -eq $settingValue) {
		return $DefaultValue
	}

	if ($settingValue -is [bool]) {
		return $settingValue
	}

	if ($settingValue -is [string]) {
		if ($settingValue -eq 'true') {
			return $true
		}

		if ($settingValue -eq 'false') {
			return $false
		}
	}

	throw "The '$Name' setting must be a boolean."
}

function AddXmlPropertyLine {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.Generic.List[string]] $Lines,

		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[string] $Value,

		[string] $Attributes = ''
	)

	# Append one escaped property line to the generated property group.
	$escapedValue = [System.Security.SecurityElement]::Escape($Value)
	$attributeText = if ([string]::IsNullOrWhiteSpace($Attributes)) { '' } else { " $Attributes" }
	$Lines.Add("  <$Name$attributeText>$escapedValue</$Name>")
}

# Read settings and existing props values before generating the managed group.
$settings = Read-ConventionSettings -InputPath $args[0]
if ($null -eq $settings) {
	$settings = @{}
}

$targetPath = Join-Path (Get-Location) 'Directory.Build.props'
$document = $null
if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
	$document = [xml] ([System.IO.File]::ReadAllText($targetPath))
}

# Resolve repository-specific settings and validate required values.
$versionPrefix = GetConfiguredPropertyValue -Settings $settings -Document $document -SettingName 'version-prefix' -PropertyName 'VersionPrefix' -DefaultValue $null
if ([string]::IsNullOrWhiteSpace($versionPrefix)) {
	throw "The 'version-prefix' setting is required when Directory.Build.props does not contain VersionPrefix."
}

$packageValidation = GetConfiguredBooleanValue -Settings $settings -Name 'package-validation' -DefaultValue $true
$packageValidationBaselineVersion = GetConfiguredPropertyValue -Settings $settings -Document $document -SettingName 'package-validation-baseline-version' -PropertyName 'PackageValidationBaselineVersion' -DefaultValue $versionPrefix
$nullable = GetConfiguredPropertyValue -Settings $settings -Document $document -SettingName 'nullable' -PropertyName 'Nullable' -DefaultValue 'enable'
$noWarn = GetConfiguredPropertyValue -Settings $settings -Document $document -SettingName 'no-warn' -PropertyName 'NoWarn' -DefaultValue $null

if ($nullable -notin @('enable', 'disable', 'annotations', 'warnings')) {
	throw "The 'nullable' setting must be 'enable', 'disable', 'annotations', or 'warnings'."
}

# Generate the managed property group in a stable order.
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('<PropertyGroup>')
AddXmlPropertyLine -Lines $lines -Name 'VersionPrefix' -Value $versionPrefix
if ($packageValidation) {
	AddXmlPropertyLine -Lines $lines -Name 'PackageValidationBaselineVersion' -Value $packageValidationBaselineVersion
}

AddXmlPropertyLine -Lines $lines -Name 'LangVersion' -Value '14.0'
AddXmlPropertyLine -Lines $lines -Name 'Nullable' -Value $nullable
AddXmlPropertyLine -Lines $lines -Name 'ImplicitUsings' -Value 'enable'
AddXmlPropertyLine -Lines $lines -Name 'TreatWarningsAsErrors' -Value 'true'
if (-not [string]::IsNullOrWhiteSpace($noWarn)) {
	AddXmlPropertyLine -Lines $lines -Name 'NoWarn' -Value $noWarn
}

AddXmlPropertyLine -Lines $lines -Name 'NeutralLanguage' -Value 'en-US'
AddXmlPropertyLine -Lines $lines -Name 'DebugType' -Value 'embedded'
AddXmlPropertyLine -Lines $lines -Name 'PackageLicenseExpression' -Value 'MIT'
AddXmlPropertyLine -Lines $lines -Name 'PackageProjectUrl' -Value 'https://github.com/$(GitHubOrganization)/$(RepositoryName)'
AddXmlPropertyLine -Lines $lines -Name 'PackageReleaseNotes' -Value 'https://github.com/$(GitHubOrganization)/$(RepositoryName)/blob/master/ReleaseNotes.md'
AddXmlPropertyLine -Lines $lines -Name 'RepositoryUrl' -Value 'https://github.com/$(GitHubOrganization)/$(RepositoryName)'
AddXmlPropertyLine -Lines $lines -Name 'Authors' -Value 'Faithlife'
AddXmlPropertyLine -Lines $lines -Name 'Copyright' -Value 'Copyright $(Authors)'
AddXmlPropertyLine -Lines $lines -Name 'EnableNETAnalyzers' -Value 'true'
AddXmlPropertyLine -Lines $lines -Name 'AnalysisLevel' -Value 'latest-all'
AddXmlPropertyLine -Lines $lines -Name 'EnforceCodeStyleInBuild' -Value 'true'
AddXmlPropertyLine -Lines $lines -Name 'GenerateDocumentationFile' -Value 'true'
AddXmlPropertyLine -Lines $lines -Name 'IsPackable' -Value 'false'
AddXmlPropertyLine -Lines $lines -Name 'IsTestProject' -Value 'false'
AddXmlPropertyLine -Lines $lines -Name 'SelfContained' -Value 'false'
AddXmlPropertyLine -Lines $lines -Name 'UseArtifactsOutput' -Value 'true'
if ($packageValidation) {
	AddXmlPropertyLine -Lines $lines -Name 'EnableStrictModeForCompatibleFrameworksInPackageValidation' -Value 'true'
	AddXmlPropertyLine -Lines $lines -Name 'EnableStrictModeForCompatibleTfms' -Value 'true'
	AddXmlPropertyLine -Lines $lines -Name 'DisablePackageBaselineValidation' -Value 'true' -Attributes 'Condition=" $(PackageValidationBaselineVersion) == $(VersionPrefix) or $(PackageValidationBaselineVersion) == ''0.0.0'' "'
}

AddXmlPropertyLine -Lines $lines -Name 'NuGetAudit' -Value 'true'
AddXmlPropertyLine -Lines $lines -Name 'NuGetAuditMode' -Value 'all'
AddXmlPropertyLine -Lines $lines -Name 'NuGetAuditLevel' -Value 'low'
$lines.Add('</PropertyGroup>')

# Write or update the managed XML section.
Invoke-ConfigTextSection -Settings @{
	path = '/Directory.Build.props'
	name = 'faithlife-dotnet-library-props'
	text = $lines -join "`n"
	'comment-prefix' = '<!--'
	'comment-suffix' = '-->'
	mode = 'xml'
}

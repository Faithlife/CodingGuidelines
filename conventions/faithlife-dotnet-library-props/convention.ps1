#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load the managed section writer.
$configTextSectionPath = Join-Path $PSScriptRoot '..' 'scripts' 'ConfigTextSection.psm1'
Import-Module $configTextSectionPath

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

# Generate the managed property group in a stable order.
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('<PropertyGroup>')
AddXmlPropertyLine -Lines $lines -Name 'LangVersion' -Value '14.0'
AddXmlPropertyLine -Lines $lines -Name 'Nullable' -Value 'enable'
AddXmlPropertyLine -Lines $lines -Name 'ImplicitUsings' -Value 'enable'
AddXmlPropertyLine -Lines $lines -Name 'TreatWarningsAsErrors' -Value 'true'
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
AddXmlPropertyLine -Lines $lines -Name 'EnableStrictModeForCompatibleFrameworksInPackageValidation' -Value 'true'
AddXmlPropertyLine -Lines $lines -Name 'EnableStrictModeForCompatibleTfms' -Value 'true'
AddXmlPropertyLine -Lines $lines -Name 'DisablePackageBaselineValidation' -Value 'true' -Attributes 'Condition=" $(PackageValidationBaselineVersion) == $(VersionPrefix) or $(PackageValidationBaselineVersion) == ''0.0.0'' "'
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
}

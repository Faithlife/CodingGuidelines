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

# Evaluate whether global.json satisfies the requested SDK major version.
function GetGlobalJsonSdkStatus {
	param(
		[string] $GlobalJsonPath,
		[int] $MajorVersion
	)

	# Treat a missing global.json as nonconforming.
	if (-not (Test-Path -LiteralPath $GlobalJsonPath -PathType Leaf)) {
		return [pscustomobject]@{
			Conforms = $false
			Message = 'global.json is missing.'
		}
	}

	# Read sdk.version and report malformed JSON as nonconforming.
	try {
		$sdkVersion = (Get-Content -LiteralPath $GlobalJsonPath -Raw | ConvertFrom-Json -AsHashtable).sdk.version
	}
	catch {
		return [pscustomobject]@{
			Conforms = $false
			Message = 'global.json does not contain valid JSON with an sdk.version value.'
		}
	}

	# Require sdk.version to be a string before parsing it.
	if ($sdkVersion -isnot [string]) {
		return [pscustomobject]@{
			Conforms = $false
			Message = 'global.json sdk.version is missing or is not a string.'
		}
	}

	# Parse the major version from a three-part SDK version.
	$versionMatch = [System.Text.RegularExpressions.Regex]::Match($sdkVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')

	if (-not $versionMatch.Success) {
		return [pscustomobject]@{
			Conforms = $false
			Message = "global.json sdk.version '$sdkVersion' is not a three-part SDK version."
		}
	}

	$currentMajorVersion = [int] $versionMatch.Groups['major'].Value

	# Accept any SDK major version that meets or exceeds the requirement.
	if ($currentMajorVersion -lt $MajorVersion) {
		return [pscustomobject]@{
			Conforms = $false
			Message = "global.json sdk.version '$sdkVersion' is lower than required major version $MajorVersion."
		}
	}

	return [pscustomobject]@{
		Conforms = $true
		Message = "global.json already requires SDK major version $currentMajorVersion, which satisfies required major version $MajorVersion."
	}
}

# Create or update global.json with the required SDK settings.
function SetGlobalJsonSdkVersion {
	param(
		[Parameter(Mandatory = $true)]
		[string] $GlobalJsonPath,

		[Parameter(Mandatory = $true)]
		[int] $MajorVersion
	)

	# Preserve the existing JSON object when possible so unrelated properties keep their relative order.
	$globalJson = $null

	if (Test-Path -LiteralPath $GlobalJsonPath -PathType Leaf) {
		try {
			$globalJson = [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content -LiteralPath $GlobalJsonPath -Raw))
		}
		catch {
			$globalJson = $null
		}
	}

	# Replace malformed or non-object JSON with the minimal object shape this convention owns.
	if ($globalJson -isnot [System.Text.Json.Nodes.JsonObject]) {
		$globalJson = [System.Text.Json.Nodes.JsonObject]::new()
	}

	# Ensure the SDK section is an object before updating its required properties.
	$sdkNode = $globalJson['sdk']

	if ($sdkNode -isnot [System.Text.Json.Nodes.JsonObject]) {
		$sdkNode = [System.Text.Json.Nodes.JsonObject]::new()
		$globalJson['sdk'] = $sdkNode
	}

	# Set the deterministic SDK version and roll-forward policy.
	$sdkNode['version'] = [System.Text.Json.Nodes.JsonValue]::Create("$MajorVersion.0.100")
	$sdkNode['rollForward'] = [System.Text.Json.Nodes.JsonValue]::Create('latestFeature')

	# Write System.Text.Json output using its stable two-space indented formatting.
	$jsonOptions = [System.Text.Json.JsonSerializerOptions]::new()
	$jsonOptions.WriteIndented = $true
	[System.IO.File]::WriteAllText($GlobalJsonPath, ($globalJson.ToJsonString($jsonOptions) + "`n"), $utf8)
}

# Read the convention input settings.
$settings = Read-ConventionSettings -InputPath $args[0]

if ($null -eq $settings -or -not $settings.ContainsKey('version')) {
	throw "The 'version' setting is required."
}

$versionSetting = $settings.version

# Parse the required SDK major version from the convention settings.
if ($versionSetting -is [byte] -or
	$versionSetting -is [short] -or
	$versionSetting -is [int] -or
	$versionSetting -is [long]) {
	$majorVersion = [int] $versionSetting
}
elseif ($versionSetting -is [string]) {
	$majorVersion = 0

	if (-not [int]::TryParse($versionSetting, [ref] $majorVersion)) {
		throw "The 'version' setting must be an integer or a string that parses to an integer."
	}
}
else {
	throw "The 'version' setting must be an integer or a string that parses to an integer."
}

# Validate the resolved major version before inspecting global.json.
if ($majorVersion -le 0) {
	throw "The 'version' setting must be a positive integer."
}

$globalJsonPath = Join-Path -Path (Get-Location) -ChildPath 'global.json'
$globalJsonDisplayPath = Format-RepositoryRelativePath -Path $globalJsonPath

# Check the current global.json status and exit when compliant.
$globalJsonStatus = GetGlobalJsonSdkStatus -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion

if ($globalJsonStatus.Conforms) {
	return
}

Write-Host "Checking $globalJsonDisplayPath for .NET SDK major version $majorVersion."
Write-Host $globalJsonStatus.Message
Write-Host 'global.json does not conform; updating it.'
SetGlobalJsonSdkVersion -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion

# Verify the deterministic update produced a conforming global.json.
$globalJsonStatus = GetGlobalJsonSdkStatus -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion
Write-Host $globalJsonStatus.Message

if (-not $globalJsonStatus.Conforms) {
	throw 'Failed to update global.json to the required .NET SDK configuration.'
}

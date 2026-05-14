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

# Read a JSON file and require an object root.
function ReadJsonObjectFile {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path,

		[Parameter(Mandatory = $true)]
		[string] $Description
	)

	try {
		$node = [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content -LiteralPath $Path -Raw))
	}
	catch {
		throw "$Description does not contain valid JSON. $($_.Exception.Message)"
	}

	if ($null -eq $node) {
		throw "$Description does not contain a JSON value."
	}

	$jsonObject = $node -as [System.Text.Json.Nodes.JsonObject]

	if ($null -eq $jsonObject) {
		throw "$Description must contain a JSON object at the root."
	}

	return , $jsonObject
}

# Return a required object-valued property from a JSON object.
function GetRequiredJsonObjectProperty {
	param(
		[Parameter(Mandatory = $true)]
		[object] $Object,

		[Parameter(Mandatory = $true)]
		[string] $PropertyName,

		[Parameter(Mandatory = $true)]
		[string] $Description
	)

	$jsonObject = $Object -as [System.Text.Json.Nodes.JsonObject]

	if ($null -eq $jsonObject) {
		throw "$Description must be a JSON object."
	}

	[System.Text.Json.Nodes.JsonNode] $propertyValue = $null
	$hasProperty = $jsonObject.TryGetPropertyValue($PropertyName, [ref] $propertyValue)

	if (-not $hasProperty -or $null -eq $propertyValue) {
		throw "$Description is required."
	}

	$jsonObject = $propertyValue -as [System.Text.Json.Nodes.JsonObject]

	if ($null -eq $jsonObject) {
		throw "$Description must be a JSON object."
	}

	return , $jsonObject
}

# Validate server names before writing them into lsp.json.
function TestValidServerName {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ServerName
	)

	return $ServerName -cmatch '^[A-Za-z0-9_-]+$'
}

# Validate the desired server map and each server definition.
function ValidateDesiredServers {
	param(
		[Parameter(Mandatory = $true)]
		[object] $Servers
	)

	$serversObject = $Servers -as [System.Text.Json.Nodes.JsonObject]

	if ($null -eq $serversObject) {
		throw "The 'servers' setting must be a JSON object."
	}

	foreach ($serverEntry in $serversObject) {
		if (-not (TestValidServerName -ServerName $serverEntry.Key)) {
			throw "The server name '$($serverEntry.Key)' must contain only alphanumeric characters, underscores, and hyphens."
		}

		$serverDefinition = $serverEntry.Value -as [System.Text.Json.Nodes.JsonObject]

		if ($null -eq $serverDefinition) {
			throw "The server definition for '$($serverEntry.Key)' must be a JSON object."
		}
	}
}

# Merge configured servers into the LSP configuration object.
function EnsureLspServers {
	param(
		[Parameter(Mandatory = $true)]
		[object] $RootObject,

		[Parameter(Mandatory = $true)]
		[object] $DesiredServers
	)

	$rootJsonObject = $RootObject -as [System.Text.Json.Nodes.JsonObject]
	$desiredServersObject = $DesiredServers -as [System.Text.Json.Nodes.JsonObject]

	if ($null -eq $rootJsonObject) {
		throw 'The LSP configuration root must be a JSON object.'
	}

	if ($null -eq $desiredServersObject) {
		throw "The 'servers' setting must be a JSON object."
	}

	$changed = $false
	[System.Text.Json.Nodes.JsonNode] $lspServersNode = $null
	$null = $rootJsonObject.TryGetPropertyValue('lspServers', [ref] $lspServersNode)
	$lspServers = $lspServersNode -as [System.Text.Json.Nodes.JsonObject]

	# Create the lspServers container when the config does not have one.
	if ($null -eq $lspServers) {
		$lspServers = [System.Text.Json.Nodes.JsonObject]::new()
		$rootJsonObject['lspServers'] = $lspServers
		$changed = $true
	}

	# Add or replace configured server definitions when they differ.
	foreach ($serverEntry in $desiredServersObject) {
		$serverName = $serverEntry.Key
		$desiredDefinition = $serverEntry.Value
		[System.Text.Json.Nodes.JsonNode] $existingDefinition = $null
		$hasExistingDefinition = $lspServers.TryGetPropertyValue($serverName, [ref] $existingDefinition)

		if (-not $hasExistingDefinition -or $null -eq $existingDefinition -or -not [System.Text.Json.Nodes.JsonNode]::DeepEquals($existingDefinition, $desiredDefinition)) {
			$lspServers[$serverName] = $desiredDefinition.DeepClone()
			$changed = $true
		}
	}

	return $changed
}

# Serialize JSON with indentation for stable file output.
function ConvertToIndentedJson {
	param(
		[Parameter(Mandatory = $true)]
		[object] $JsonObject
	)

	$rootJsonObject = $JsonObject -as [System.Text.Json.Nodes.JsonObject]

	if ($null -eq $rootJsonObject) {
		throw 'The JSON value to write must be an object.'
	}

	$options = [System.Text.Json.JsonSerializerOptions]::new()
	$options.WriteIndented = $true

	return $rootJsonObject.ToJsonString($options)
}

# Require the convention input path before reading settings.
if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

# Read and validate the desired server configuration.
$inputPath = $args[0]
$inputRoot = ReadJsonObjectFile -Path $inputPath -Description 'The convention input file'
$settings = GetRequiredJsonObjectProperty -Object $inputRoot -PropertyName 'settings' -Description "The 'settings' property"
$desiredServers = GetRequiredJsonObjectProperty -Object $settings -PropertyName 'servers' -Description "The 'servers' setting"

ValidateDesiredServers -Servers $desiredServers

# Locate the repository's Copilot LSP configuration file.
$lspConfigPath = Get-RepositoryPath -PathSetting '/.github/lsp.json'
$lspConfigDisplayPath = Format-RepositoryRelativePath -Path $lspConfigPath
$fileExisted = Test-Path -LiteralPath $lspConfigPath -PathType Leaf

# Read the existing configuration or start with an empty object.
$rootObject = if ($fileExisted) {
	ReadJsonObjectFile -Path $lspConfigPath -Description "'$lspConfigDisplayPath'"
}
else {
	, [System.Text.Json.Nodes.JsonObject]::new()
}

$changed = EnsureLspServers -RootObject $rootObject -DesiredServers $desiredServers

# Stop when the file already contains the configured servers.
if (-not $changed) {
	Write-Host "'$lspConfigDisplayPath' already contains the configured Copilot LSP servers."
	return
}

# Ensure the destination directory exists before writing lsp.json.
$lspConfigDirectory = Split-Path -Parent $lspConfigPath

if (-not [string]::IsNullOrWhiteSpace($lspConfigDirectory)) {
	[System.IO.Directory]::CreateDirectory($lspConfigDirectory) | Out-Null
}

# Write the updated configuration and report whether it was created.
$content = (ConvertToIndentedJson -JsonObject $rootObject) + "`n"
Write-Utf8NoBomFile -Path $lspConfigPath -Content $content

if ($fileExisted) {
	Write-Host "Updated '$lspConfigDisplayPath' with the configured Copilot LSP servers."
	return
}

Write-Host "Created '$lspConfigDisplayPath' with the configured Copilot LSP servers."

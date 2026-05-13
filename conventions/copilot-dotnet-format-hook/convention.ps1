#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

$hookScriptSourcePath = Join-Path $PSScriptRoot 'dotnet-format.ps1'
$hookScriptDestPath = Get-RepositoryPath -PathSetting '/.github/hooks/scripts/dotnet-format.ps1'
$hookScriptDisplayPath = Format-RepositoryRelativePath -Path $hookScriptDestPath

$scriptResult = Copy-FileIfDifferent -SourcePath $hookScriptSourcePath -DestinationPath $hookScriptDestPath

if ($scriptResult.Created) {
	Write-Host "Created '$hookScriptDisplayPath'."
}
elseif ($scriptResult.Updated) {
	Write-Host "Updated '$hookScriptDisplayPath'."
}
else {
	Write-Host "'$hookScriptDisplayPath' is already up to date."
}

$hooksJsonPath = Get-RepositoryPath -PathSetting '/.github/hooks/hooks.json'
$hooksJsonDisplayPath = Format-RepositoryRelativePath -Path $hooksJsonPath

$desiredHookEntry = [System.Text.Json.Nodes.JsonObject]::new()
$desiredHookEntry['type'] = [System.Text.Json.Nodes.JsonValue]::Create('command')
$desiredHookEntry['bash'] = [System.Text.Json.Nodes.JsonValue]::Create('pwsh .github/hooks/scripts/dotnet-format.ps1')
$desiredHookEntry['powershell'] = [System.Text.Json.Nodes.JsonValue]::Create('.github/hooks/scripts/dotnet-format.ps1')
$desiredHookEntry['cwd'] = [System.Text.Json.Nodes.JsonValue]::Create('.')
$desiredHookEntry['timeoutSec'] = [System.Text.Json.Nodes.JsonValue]::Create(30)

$hooksJsonFileExisted = Test-Path -LiteralPath $hooksJsonPath -PathType Leaf

[System.Text.Json.Nodes.JsonObject] $rootObject = if ($hooksJsonFileExisted) {
	try {
		$parsed = [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content -LiteralPath $hooksJsonPath -Raw))
	}
	catch {
		throw "'$hooksJsonDisplayPath' does not contain valid JSON. $($_.Exception.Message)"
	}

	$asObject = $parsed -as [System.Text.Json.Nodes.JsonObject]
	if ($null -eq $asObject) {
		throw "'$hooksJsonDisplayPath' must contain a JSON object at the root."
	}

	, $asObject
}
else {
	$newRoot = [System.Text.Json.Nodes.JsonObject]::new()
	$newRoot['version'] = [System.Text.Json.Nodes.JsonValue]::Create(1)
	$newRoot['hooks'] = [System.Text.Json.Nodes.JsonObject]::new()
	, $newRoot
}

[System.Text.Json.Nodes.JsonNode] $hooksNode = $null
$null = $rootObject.TryGetPropertyValue('hooks', [ref] $hooksNode)
$hooksObject = $hooksNode -as [System.Text.Json.Nodes.JsonObject]

if ($null -eq $hooksObject) {
	$hooksObject = [System.Text.Json.Nodes.JsonObject]::new()
	$rootObject['hooks'] = $hooksObject
}

[System.Text.Json.Nodes.JsonNode] $postToolUseNode = $null
$null = $hooksObject.TryGetPropertyValue('postToolUse', [ref] $postToolUseNode)
$postToolUseArray = $postToolUseNode -as [System.Text.Json.Nodes.JsonArray]

if ($null -eq $postToolUseArray) {
	$postToolUseArray = [System.Text.Json.Nodes.JsonArray]::new()
	$hooksObject['postToolUse'] = $postToolUseArray
}

$alreadyPresent = $false
foreach ($entry in $postToolUseArray) {
	$entryObject = $entry -as [System.Text.Json.Nodes.JsonObject]
	if ($null -eq $entryObject) {
		continue
	}

	[System.Text.Json.Nodes.JsonNode] $powershellNode = $null
	$null = $entryObject.TryGetPropertyValue('powershell', [ref] $powershellNode)

	if ($powershellNode -is [System.Text.Json.Nodes.JsonValue] -and
		$powershellNode.GetValue[string]() -eq '.github/hooks/scripts/dotnet-format.ps1') {
		$alreadyPresent = $true
		break
	}
}

if ($alreadyPresent) {
	Write-Host "'$hooksJsonDisplayPath' already contains the dotnet-format hook."
	return
}

$null = $postToolUseArray.Add($desiredHookEntry)

$hooksJsonDirectory = Split-Path -Parent $hooksJsonPath
if (-not [string]::IsNullOrWhiteSpace($hooksJsonDirectory)) {
	[System.IO.Directory]::CreateDirectory($hooksJsonDirectory) | Out-Null
}

$jsonOptions = [System.Text.Json.JsonSerializerOptions]::new()
$jsonOptions.WriteIndented = $true
$content = $rootObject.ToJsonString($jsonOptions) + "`n"
Write-Utf8NoBomFile -Path $hooksJsonPath -Content $content

if ($hooksJsonFileExisted) {
	Write-Host "Updated '$hooksJsonDisplayPath' with the dotnet-format hook."
}
else {
	Write-Host "Created '$hooksJsonDisplayPath' with the dotnet-format hook."
}

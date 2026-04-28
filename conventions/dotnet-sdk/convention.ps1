#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'Starting dotnet-sdk convention.'

$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

function GetGlobalJsonSdkStatus {
	param(
		[string] $GlobalJsonPath,
		[int] $MajorVersion
	)

	if (-not (Test-Path -LiteralPath $GlobalJsonPath -PathType Leaf)) {
		return [pscustomobject]@{
			Conforms = $false
			Message = 'global.json is missing.'
		}
	}

	try {
		$sdkVersion = (Get-Content -LiteralPath $GlobalJsonPath -Raw | ConvertFrom-Json -AsHashtable).sdk.version
	}
	catch {
		return [pscustomobject]@{
			Conforms = $false
			Message = 'global.json does not contain valid JSON with an sdk.version value.'
		}
	}

	if ($sdkVersion -isnot [string]) {
		return [pscustomobject]@{
			Conforms = $false
			Message = 'global.json sdk.version is missing or is not a string.'
		}
	}

	$versionMatch = [System.Text.RegularExpressions.Regex]::Match($sdkVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')

	if (-not $versionMatch.Success) {
		return [pscustomobject]@{
			Conforms = $false
			Message = "global.json sdk.version '$sdkVersion' is not a three-part SDK version."
		}
	}

	$currentMajorVersion = [int] $versionMatch.Groups['major'].Value

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

if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$inputPath = $args[0]
$settings = Read-ConventionSettings -InputPath $inputPath

if ($null -eq $settings -or -not $settings.ContainsKey('version')) {
	throw "The 'version' setting is required."
}

$versionSetting = $settings.version

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

if ($majorVersion -le 0) {
	throw "The 'version' setting must be a positive integer."
}

$globalJsonPath = Join-Path -Path (Get-Location) -ChildPath 'global.json'
$globalJsonDisplayPath = Format-RepositoryRelativePath -Path $globalJsonPath

Write-Host "Checking $globalJsonDisplayPath for .NET SDK major version $majorVersion."

$globalJsonStatus = GetGlobalJsonSdkStatus -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion
Write-Host $globalJsonStatus.Message

if ($globalJsonStatus.Conforms) {
	Write-Host 'dotnet-sdk convention has nothing to do.'
	return
}

$sdkVersion = "$majorVersion.0.100"
$copilotInstructions = @"
Update the repository in the current directory so that `global.json` conforms to the required .NET SDK configuration.

Use this `global.json` when the file does not exist:

```
{
  "sdk": {
    "version": "$sdkVersion",
    "rollForward": "latestFeature"
  }
}
```

If `global.json` already exists, change its properties to match those above.
Preserve any properties in `global.json` that do not need to change.
Do not modify any files other than `global.json`.

When you're done, make sure the code still builds successfully, e.g. by running `./build.ps1 build` or `dotnet build`.
If the code doesn't build successfully, read the error messages, read the affected files, and fix the issues by editing the code.
DO NOT suppress warnings by adding `<NoWarn>` properties or `#pragma warning` directives.
If you make changes, build the code again and keep fixing issues until it builds successfully.
DO NOT commit any changes to the git repository. Leave your changes unstaged.
"@

Write-Host 'global.json does not conform; starting Copilot to update it.'
Invoke-CopilotWithIsolatedConfig -Instructions $copilotInstructions

$globalJsonStatus = GetGlobalJsonSdkStatus -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion
Write-Host $globalJsonStatus.Message

if (-not $globalJsonStatus.Conforms) {
	throw 'Copilot failed to update global.json to the required .NET SDK configuration.'
}

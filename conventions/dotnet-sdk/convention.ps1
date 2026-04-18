param(
	[Parameter(Mandatory = $true)]
	[string] $PayloadPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-RequiredMajorVersion {
	param(
		[string] $Path
	)

	$payload = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
	$settings = $payload.settings

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

	return $majorVersion
}

function Assert-ConformingGlobalJson {
	param(
		[string] $Path,
		[int] $RequiredMajorVersion
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		return $false
	}

	try {
		$sdkVersion = (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable).sdk.version
	}
	catch {
		return $false
	}

	if ($sdkVersion -isnot [string]) {
		return $false
	}

	$versionMatch = [System.Text.RegularExpressions.Regex]::Match($sdkVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')

	if (-not $versionMatch.Success) {
		return $false
	}

	return [int] $versionMatch.Groups['major'].Value -ge $RequiredMajorVersion
}

$requiredMajorVersion = Get-RequiredMajorVersion -Path $PayloadPath
$globalJsonPath = Join-Path -Path (Get-Location) -ChildPath 'global.json'

if (Assert-ConformingGlobalJson -Path $globalJsonPath -RequiredMajorVersion $requiredMajorVersion) {
	return
}

$requiredSdkVersion = "$requiredMajorVersion.0.100"
$copilotInstructions = @"
Update the repository in the current directory so that `global.json` conforms to the required .NET SDK configuration.

Use this `global.json` when the file does not exist:

```
{
  "sdk": {
    "version": "$requiredSdkVersion",
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
"@

Get-Command -Name copilot -ErrorAction Stop | Out-Null

Write-Host 'global.json does not conform; starting Copilot to update it.'
$copilotInstructions | & copilot --no-ask-user --allow-all-tools --allow-all-paths --model auto

if (-not (Assert-ConformingGlobalJson -Path $globalJsonPath -RequiredMajorVersion $requiredMajorVersion)) {
	throw 'Copilot failed to update global.json to the required .NET SDK configuration.'
}

return

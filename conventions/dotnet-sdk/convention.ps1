Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function TestConformingGlobalJson {
	param(
		[string] $GlobalJsonPath,
		[int] $MajorVersion
	)

	if (-not (Test-Path -LiteralPath $GlobalJsonPath -PathType Leaf)) {
		return $false
	}

	try {
		$sdkVersion = (Get-Content -LiteralPath $GlobalJsonPath -Raw | ConvertFrom-Json -AsHashtable).sdk.version
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

	return [int] $versionMatch.Groups['major'].Value -ge $MajorVersion
}

if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$inputPath = $args[0]
$conventionInput = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json -AsHashtable
$settings = $conventionInput.settings

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

if (TestConformingGlobalJson -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion) {
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

Get-Command -Name copilot -ErrorAction Stop | Out-Null

# use a temporary directory for Copilot config to avoid personal instructions
$copilotConfigDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $copilotConfigDirectory | Out-Null

try {
	Write-Host 'global.json does not conform; starting Copilot to update it.'
	$copilotInstructions | & copilot --config-dir $copilotConfigDirectory --no-ask-user --allow-all-tools --allow-all-paths --model auto
}
finally {
	Remove-Item -LiteralPath $copilotConfigDirectory -Recurse -Force
}

if (-not (TestConformingGlobalJson -GlobalJsonPath $globalJsonPath -MajorVersion $majorVersion)) {
	throw 'Copilot failed to update global.json to the required .NET SDK configuration.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert-ConformingGlobalJson {
	param(
		[string] $Path
	)

	$invalidSdkVersionMessage = 'global.json must contain a parseable sdk.version that uses the .NET 10 SDK or later.'

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw 'Repository must have a global.json that uses the .NET 10 SDK or later.'
	}

	try {
		$sdkVersion = (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable).sdk.version
	}
	catch {
		throw $invalidSdkVersionMessage
	}

	if ($sdkVersion -isnot [string]) {
		throw $invalidSdkVersionMessage
	}

	$versionMatch = [System.Text.RegularExpressions.Regex]::Match($sdkVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')

	if (-not $versionMatch.Success) {
		throw $invalidSdkVersionMessage
	}

	if ([int] $versionMatch.Groups['major'].Value -lt 10) {
		throw 'global.json must use the .NET 10 SDK or later.'
	}

	return
}

$globalJsonPath = Join-Path -Path (Get-Location) -ChildPath 'global.json'

try {
	Assert-ConformingGlobalJson -Path $globalJsonPath
	return
}
catch {
	Write-Host $_.Exception.Message
}

$copilotInstructions = @"
Update the repository in the current directory so that `global.json` conforms to the required .NET SDK configuration.

Use this `global.json` when the file does not exist:

```
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "latestFeature"
  }
}
```

If `global.json` already exists, change its properties to match those above.
Preserve any properties in `global.json` that do not need to change.
Do not modify any files other than `global.json`.

When you're done, make sure the code still builds successfully, e.g. by running `./build.ps1 build` or `dotnet build`.
If the code doesn't build successfully, read the error messages, raed the affected files, and fix the issues by editing the code.
DO NOT suppress warnings by adding `<NoWarn>` properties or `#pragma warning` directives.
If you make changes, build the code again and keep fixing issues until it builds successfully.
"@

Get-Command -Name copilot -ErrorAction Stop | Out-Null

$copilotInstructions | & copilot --no-ask-user --allow-all-tools --add-dir (Get-Location).Path

Assert-ConformingGlobalJson -Path $globalJsonPath

return

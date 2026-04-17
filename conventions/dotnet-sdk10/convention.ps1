Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert-ConformingGlobalJson {
	param(
		[string] $Path
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

	return [int] $versionMatch.Groups['major'].Value -ge 10
}

$globalJsonPath = Join-Path -Path (Get-Location) -ChildPath 'global.json'

if (Assert-ConformingGlobalJson -Path $globalJsonPath) {
	return
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

Write-Host 'global.json does not conform; starting Copilot to update it.'
$copilotInstructions | & copilot --no-ask-user --allow-all-tools --add-dir (Get-Location).Path

if (-not (Assert-ConformingGlobalJson -Path $globalJsonPath)) {
	throw 'Copilot failed to update global.json to the required .NET SDK configuration.'
}

return

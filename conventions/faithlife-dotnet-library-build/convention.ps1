#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Write a published support file when the target is missing or differs.
function WriteConventionFile {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[string] $DestinationPath
	)

	# Leave the file untouched when it already matches the published content.
	if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
		if ((Get-Content -LiteralPath $DestinationPath -Raw) -ceq $Content) {
			return $false
		}

		[System.IO.File]::WriteAllText($DestinationPath, $Content, $utf8)
		Write-Host "Updated '$DestinationPath'."
		return $true
	}

	# Create parent directories before writing a missing managed file.
	$destinationDirectory = Split-Path -Parent $DestinationPath
	New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	[System.IO.File]::WriteAllText($DestinationPath, $Content, $utf8)
	Write-Host "Created '$DestinationPath'."
	return $true
}

# Return the published Build.csproj content, optionally retargeted from global.json.
function GetBuildCsprojContent {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TemplatePath,

		[Parameter(Mandatory = $true)]
		[string] $RepositoryRoot
	)

	# Read the published template first so the default output stays in sync with source control.
	$templateContent = Get-Content -LiteralPath $TemplatePath -Raw
	$globalJsonPath = Join-Path $RepositoryRoot 'global.json'

	# Use the template unchanged when the repository does not pin an SDK.
	if (-not (Test-Path -LiteralPath $globalJsonPath -PathType Leaf)) {
		return $templateContent
	}

	# Read sdk.version when global.json is valid JSON with the expected shape.
	try {
		$sdkVersion = (Get-Content -LiteralPath $globalJsonPath -Raw | ConvertFrom-Json -AsHashtable).sdk.version
	}
	catch {
		return $templateContent
	}

	# Preserve the template default when sdk.version is absent or malformed.
	if ($sdkVersion -isnot [string]) {
		return $templateContent
	}

	$versionMatch = [System.Text.RegularExpressions.Regex]::Match($sdkVersion, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')

	if (-not $versionMatch.Success) {
		return $templateContent
	}

	# Retarget the template using the SDK major/minor without parsing XML.
	$targetFramework = "net$($versionMatch.Groups['major'].Value).$($versionMatch.Groups['minor'].Value)"
	return ($templateContent -replace '<TargetFramework>[^<]+</TargetFramework>', "<TargetFramework>$targetFramework</TargetFramework>")
}

# Return solution files located at the repository root.
function GetRootSolutionPaths {
	return @(
		Get-ChildItem -LiteralPath (Get-Location) -File |
			Where-Object { $_.Extension -in '.sln', '.slnx' } |
			Sort-Object -Property Name
	)
}

# Create a root solution when the repository does not already have one.
function EnsureRootSolutionExists {
	$rootSolutions = @(GetRootSolutionPaths)

	if ($rootSolutions.Count -gt 0) {
		return $false
	}

	Write-Host 'Creating a root solution with dotnet new sln.'
	& dotnet new sln | Out-Null

	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to create a root solution with dotnet new sln.'
	}

	$rootSolutions = @(GetRootSolutionPaths)

	if ($rootSolutions.Count -eq 0) {
		throw 'dotnet new sln did not create a root solution file.'
	}

	return $true
}

# Resolve published source files and their tools/Build targets.
$conventionBuildCsPath = Join-Path $PSScriptRoot 'files' 'Build.cs'
$conventionBuildCsprojPath = Join-Path $PSScriptRoot 'files' 'Build.csproj.xml'
$targetDirectoryPath = Join-Path (Get-Location) 'tools/Build'
$targetBuildCsPath = Join-Path $targetDirectoryPath 'Build.cs'
$targetBuildCsprojPath = Join-Path $targetDirectoryPath 'Build.csproj'

# Read the desired managed file content before writing anything.
$buildCsContent = Get-Content -LiteralPath $conventionBuildCsPath -Raw
$buildCsprojContent = GetBuildCsprojContent -TemplatePath $conventionBuildCsprojPath -RepositoryRoot (Get-Location)
$hadBuildCsproj = Test-Path -LiteralPath $targetBuildCsprojPath -PathType Leaf

# Write the managed build project files when they differ from the published sources.
$wroteBuildCs = WriteConventionFile -Content $buildCsContent -DestinationPath $targetBuildCsPath
$wroteBuildCsproj = WriteConventionFile -Content $buildCsprojContent -DestinationPath $targetBuildCsprojPath

# Add the build project to the root solution when the project file was newly created.
if ($wroteBuildCsproj -and -not $hadBuildCsproj) {
	$createdRootSolution = EnsureRootSolutionExists

	if ($createdRootSolution) {
		# EnsureRootSolutionExists already emitted the creation message.
	}

	Write-Host "Adding './tools/Build' to the root solution."
	& dotnet sln add ./tools/Build --in-root | Out-Null

	if ($LASTEXITCODE -ne 0) {
		throw "Failed to add './tools/Build' to the root solution."
	}
}

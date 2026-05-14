#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Copy a published support file only when the target is missing.
function CopyMissingConventionFile {
	param(
		[Parameter(Mandatory = $true)]
		[string] $SourcePath,

		[Parameter(Mandatory = $true)]
		[string] $DestinationPath
	)

	if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
		return $false
	}

	$destinationDirectory = Split-Path -Parent $DestinationPath
	New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
	Write-Host "Created '$DestinationPath'."
	return $true
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

# Copy the build project files that are missing from the repository.
$copiedBuildCs = CopyMissingConventionFile -SourcePath $conventionBuildCsPath -DestinationPath $targetBuildCsPath
$copiedBuildCsproj = CopyMissingConventionFile -SourcePath $conventionBuildCsprojPath -DestinationPath $targetBuildCsprojPath

# Add the build project to the root solution when the project file was created.
if ($copiedBuildCsproj) {
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

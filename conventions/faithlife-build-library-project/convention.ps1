Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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

function TestRootSolutionExists {
	$rootSolutions = @(
		Get-ChildItem -LiteralPath (Get-Location) -File -Filter '*.sln'
		Get-ChildItem -LiteralPath (Get-Location) -File -Filter '*.slnx'
	)

	return $rootSolutions.Count -gt 0
}

$conventionBuildCsPath = Join-Path $PSScriptRoot 'Build.cs'
$conventionBuildCsprojPath = Join-Path $PSScriptRoot 'Build.csproj'
$targetDirectoryPath = Join-Path (Get-Location) 'tools/Build'
$targetBuildCsPath = Join-Path $targetDirectoryPath 'Build.cs'
$targetBuildCsprojPath = Join-Path $targetDirectoryPath 'Build.csproj'

$copiedBuildCs = CopyMissingConventionFile -SourcePath $conventionBuildCsPath -DestinationPath $targetBuildCsPath
$copiedBuildCsproj = CopyMissingConventionFile -SourcePath $conventionBuildCsprojPath -DestinationPath $targetBuildCsprojPath

if ($copiedBuildCsproj -and (TestRootSolutionExists)) {
	Write-Host "Adding './tools/Build' to the root solution."
	& dotnet sln add ./tools/Build --in-root | Out-Null

	if ($LASTEXITCODE -ne 0) {
		throw "Failed to add './tools/Build' to the root solution."
	}
}

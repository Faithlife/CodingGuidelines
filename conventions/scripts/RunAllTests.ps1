#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot 'Helpers.ps1'
. $helpersPath

function GetConventionsRoot {
	return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function GetTestScriptPaths {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ConventionsRoot
	)

	return @(Get-ChildItem -Path $ConventionsRoot -Filter 'convention.Tests.ps1' -File -Recurse |
		Where-Object { $_.DirectoryName -ne $PSScriptRoot } |
		Sort-Object FullName)
}

function GetRelativeDisplayPath {
	param(
		[Parameter(Mandatory = $true)]
		[string] $RootPath,

		[Parameter(Mandatory = $true)]
		[string] $ChildPath
	)

	return [System.IO.Path]::GetRelativePath($RootPath, $ChildPath)
}

Set-Utf8NoBomConsoleEncoding
Import-Module Pester -MinimumVersion 5.0.0

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$conventionsRoot = GetConventionsRoot
$testScriptPaths = GetTestScriptPaths -ConventionsRoot $conventionsRoot

if ($testScriptPaths.Count -eq 0) {
	throw "No convention test scripts were found under '$conventionsRoot'."
}

$failedScriptPaths = [System.Collections.Generic.List[string]]::new()

foreach ($testScriptPath in $testScriptPaths) {
	$displayPath = GetRelativeDisplayPath -RootPath $repositoryRoot -ChildPath $testScriptPath.FullName
	Write-Host "Running $displayPath"

	$testResult = Invoke-Pester -Path $testScriptPath.FullName -PassThru

	if ($testResult.FailedCount -gt 0) {
		$failedScriptPaths.Add($displayPath)
	}
}

if ($failedScriptPaths.Count -gt 0) {
	Write-Host ''
	Write-Host 'Failing test scripts:'

	foreach ($failedScriptPath in $failedScriptPaths) {
		Write-Host "- $failedScriptPath"
	}

	exit 1
}

Write-Host ''
Write-Host "All $($testScriptPaths.Count) convention test scripts passed."
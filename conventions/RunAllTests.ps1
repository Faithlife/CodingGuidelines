#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

if ((Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1).Version -lt [version]'5.0.0') {
	throw "Pester 5 is required to run these tests. Currently using $((Get-Module Pester).Version)."
}

# Return the conventions directory used as the primary test root.
function GetConventionsRoot {
	return [System.IO.Path]::GetFullPath($PSScriptRoot)
}

# Discover convention test scripts in published and GitHub-local convention roots.
function GetTestScriptPaths {
	param(
		[Parameter(Mandatory = $true)]
		[string] $RepositoryRoot,

		[Parameter(Mandatory = $true)]
		[string] $ConventionsRoot
	)

	$testRoots = [System.Collections.Generic.List[string]]::new()
	$testRoots.Add($ConventionsRoot)

	$githubConventionsRoot = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $RepositoryRoot '.github') 'conventions'))

	if (Test-Path -LiteralPath $githubConventionsRoot -PathType Container) {
		$testRoots.Add($githubConventionsRoot)
	}

	return @($testRoots | ForEach-Object { Get-ChildItem -Path $_ -Filter '*.Tests.ps1' -File -Recurse } |
		Where-Object { $_.DirectoryName -ne $PSScriptRoot } |
		Sort-Object FullName)
}

# Return paths relative to the repository root for concise output.
function GetRelativeDisplayPath {
	param(
		[Parameter(Mandatory = $true)]
		[string] $RootPath,

		[Parameter(Mandatory = $true)]
		[string] $ChildPath
	)

	return [System.IO.Path]::GetRelativePath($RootPath, $ChildPath)
}

# Resolve the repository and discover test scripts before running them.
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$conventionsRoot = GetConventionsRoot
$testScriptPaths = @(GetTestScriptPaths -RepositoryRoot $repositoryRoot -ConventionsRoot $conventionsRoot)

# Fail clearly when no convention tests were discovered.
if ($testScriptPaths.Count -eq 0) {
	throw "No convention test scripts were found under '$conventionsRoot'."
}

# Track failing scripts so the final output summarizes all failures.
$failedScriptPaths = [System.Collections.Generic.List[string]]::new()

# Suppress GitHub step-summary output during test execution and restore it afterward.
$hadGitHubStepSummary = Test-Path Env:GITHUB_STEP_SUMMARY
$gitHubStepSummary = $env:GITHUB_STEP_SUMMARY
$exitCode = 0
Remove-Item Env:GITHUB_STEP_SUMMARY -ErrorAction Ignore

try {
	# Run each Pester script independently and record failures.
	foreach ($testScriptPath in $testScriptPaths) {
		$displayPath = GetRelativeDisplayPath -RootPath $repositoryRoot -ChildPath $testScriptPath.FullName
		Write-Host "Running $displayPath"

		$testResult = Invoke-Pester -Path $testScriptPath.FullName -PassThru

		if ($testResult.FailedCount -gt 0) {
			$failedScriptPaths.Add($displayPath)
		}
	}

	# Emit the failing scripts and fail the aggregate run.
	if ($failedScriptPaths.Count -gt 0) {
		Write-Host ''
		Write-Host 'Failing test scripts:'

		foreach ($failedScriptPath in $failedScriptPaths) {
			Write-Host "- $failedScriptPath"
		}

		$exitCode = 1
	}
	else {
		# Report aggregate success after every script passes.
		Write-Host ''
		Write-Host "All $($testScriptPaths.Count) convention test scripts passed."
	}
}
finally {
	# Restore the GitHub step-summary environment variable for the parent step.
	if ($hadGitHubStepSummary) {
		$env:GITHUB_STEP_SUMMARY = $gitHubStepSummary
	}
	else {
		Remove-Item Env:GITHUB_STEP_SUMMARY -ErrorAction Ignore
	}
}

# Exit with the aggregate test status after cleanup finishes.
if ($exitCode -ne 0) {
	exit $exitCode
}

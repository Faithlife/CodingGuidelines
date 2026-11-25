#requires -PSEdition Core
#requires -Version 7.0
param(
	[string] $WorkerScriptPath
)

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

	$githubConventionsRoot = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot '.github' 'conventions'))

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

# Order test scripts so heavier suites start first and minimize parallel tail latency.
function SortTestScriptPaths {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $TestScriptPaths,

		[Parameter(Mandatory = $true)]
		[string] $RepositoryRoot
	)

	$priorityOrder = @(
		'conventions/dotnet-common-props/convention.Tests.ps1',
		'conventions/update-nuget-packages/convention.Tests.ps1',
		'conventions/faithlife-dotnet-library-build/convention.Tests.ps1',
		'conventions/editorconfig-root/convention.Tests.ps1',
		'conventions/editorconfig-yaml/convention.Tests.ps1',
		'conventions/editorconfig-json/convention.Tests.ps1',
		'conventions/editorconfig-md/convention.Tests.ps1',
		'conventions/editorconfig-ps1/convention.Tests.ps1',
		'conventions/gitattributes-lf/convention.Tests.ps1',
		'conventions/apm/convention.Tests.ps1',
		'conventions/editorconfig-section/convention.Tests.ps1',
		'conventions/editorconfig-csharp/convention.Tests.ps1',
		'conventions/gitattributes-csharp/convention.Tests.ps1'
	)

	return @($TestScriptPaths | Sort-Object {
		$relativePath = (GetRelativeDisplayPath -RootPath $RepositoryRoot -ChildPath $_.FullName).Replace('\', '/')
		$index = [Array]::IndexOf($priorityOrder, $relativePath)
		if ($index -ge 0) { $index } else { $priorityOrder.Count }
	}, FullName)
}

# Resolve the repository root used for display paths and worker execution.
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

# Execute a single test script when invoked as an isolated worker process.
if (-not [string]::IsNullOrWhiteSpace($WorkerScriptPath)) {
	$displayPath = GetRelativeDisplayPath -RootPath $repositoryRoot -ChildPath $WorkerScriptPath
	Write-Host "Running $displayPath"

	$testResult = Invoke-Pester -Path $WorkerScriptPath -PassThru

	if ($testResult.FailedCount -gt 0) {
		exit 1
	}

	exit 0
}

# Discover convention test scripts before running them.
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
$hadRepoConventionsExe = Test-Path Env:REPO_CONVENTIONS_EXE
$previousRepoConventionsExe = $env:REPO_CONVENTIONS_EXE
$repoConventionsToolDir = $null
$exitCode = 0
Remove-Item Env:GITHUB_STEP_SUMMARY -ErrorAction Ignore

try {
	# Install repo-conventions once for the entire test run when no binary is already available.
	if ([string]::IsNullOrWhiteSpace($env:REPO_CONVENTIONS_EXE) -and $null -eq (Get-Command 'repo-conventions' -ErrorAction SilentlyContinue)) {
		$repoConventionsToolDir = Join-Path ([System.IO.Path]::GetTempPath()) ('repo-conventions-tool-' + [System.Guid]::NewGuid().ToString('N'))
		& dotnet tool install repo-conventions --tool-path $repoConventionsToolDir | Out-Null
		if ($LASTEXITCODE -eq 0) {
			$toolBinaryName = if ($IsWindows) { 'repo-conventions.exe' } else { 'repo-conventions' }
			$installedExe = Join-Path $repoConventionsToolDir $toolBinaryName
			if (Test-Path -LiteralPath $installedExe) {
				$env:REPO_CONVENTIONS_EXE = $installedExe
			}
		}
	}

	# Run each test script in an isolated parallel PowerShell process, starting heaviest suites first.
	$workerCount = [Math]::Min($testScriptPaths.Count, [Math]::Max(2, [Math]::Min([Environment]::ProcessorCount, 8)))
	$orderedScriptPaths = SortTestScriptPaths -TestScriptPaths $testScriptPaths -RepositoryRoot $repositoryRoot
	$pwshPath = (Get-Process -Id $PID).Path
	$runnerScriptPath = $PSCommandPath
	$workerOutputs = @($orderedScriptPaths | ForEach-Object -Parallel {
		$scriptFullPath = $_.FullName
		$displayPath = [System.IO.Path]::GetRelativePath($using:repositoryRoot, $scriptFullPath)
		$lines = @(& $using:pwshPath -NoProfile -NonInteractive -File $using:runnerScriptPath -WorkerScriptPath $scriptFullPath 2>&1)
		[pscustomobject]@{
			DisplayPath = $displayPath
			ExitCode = $LASTEXITCODE
			Lines = $lines
		}
	} -ThrottleLimit $workerCount)

	# Print each script's buffered output cleanly and record any failed scripts.
	foreach ($workerOutput in $workerOutputs) {
		foreach ($line in $workerOutput.Lines) {
			Write-Host $line
		}

		if ($workerOutput.ExitCode -ne 0) {
			$failedScriptPaths.Add($workerOutput.DisplayPath)
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
	# Clean up the temporary tool directory.
	if (-not [string]::IsNullOrWhiteSpace($repoConventionsToolDir) -and (Test-Path -LiteralPath $repoConventionsToolDir)) {
		Remove-Item -LiteralPath $repoConventionsToolDir -Recurse -Force -ErrorAction Ignore
	}

	# Restore environment variables for the parent step.
	if ($hadRepoConventionsExe) {
		$env:REPO_CONVENTIONS_EXE = $previousRepoConventionsExe
	}
	else {
		Remove-Item Env:REPO_CONVENTIONS_EXE -ErrorAction Ignore
	}

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

#requires -PSEdition Core
#requires -Version 7.0
param(
	[string] $WorkerScriptListPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Ensure Pester 5+ is available without re-scanning module paths when already loaded.
$pesterModule = Get-Module Pester | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $pesterModule) {
	$pesterModule = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
}
if ($null -eq $pesterModule -or $pesterModule.Version -lt [version]'5.0.0') {
	throw "Pester 5 is required to run these tests. Currently using $(if ($null -ne $pesterModule) { $pesterModule.Version } else { 'none' })."
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

# Partition test scripts across workers using greedy load balancing by estimated runtime.
function SplitTestScriptBuckets {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $TestScriptPaths,

		[Parameter(Mandatory = $true)]
		[string] $RepositoryRoot,

		[Parameter(Mandatory = $true)]
		[int] $WorkerCount
	)

	$scriptWeights = @{
		'conventions/update-nuget-packages/convention.Tests.ps1' = 45
		'conventions/faithlife-dotnet-library-build/convention.Tests.ps1' = 35
		'conventions/dotnet-common-props/convention.Tests.ps1' = 24
		'conventions/gitattributes-lf/convention.Tests.ps1' = 18
		'conventions/apm/convention.Tests.ps1' = 14
		'conventions/editorconfig-root/convention.Tests.ps1' = 11
		'conventions/build-script/convention.Tests.ps1' = 10
		'conventions/editorconfig-yaml/convention.Tests.ps1' = 8
		'conventions/editorconfig-json/convention.Tests.ps1' = 8
		'conventions/editorconfig-md/convention.Tests.ps1' = 8
		'conventions/editorconfig-ps1/convention.Tests.ps1' = 8
		'conventions/editorconfig-section/convention.Tests.ps1' = 5
		'conventions/editorconfig-csharp/convention.Tests.ps1' = 5
		'conventions/gitattributes-csharp/convention.Tests.ps1' = 5
		'conventions/faithlife-auto-apply-conventions/convention.Tests.ps1' = 5
		'conventions/license-mit/convention.Tests.ps1' = 5
	}

	$weightedScripts = @($TestScriptPaths | ForEach-Object {
		$relativePath = (GetRelativeDisplayPath -RootPath $RepositoryRoot -ChildPath $_.FullName).Replace('\', '/')
		$weight = if ($scriptWeights.ContainsKey($relativePath)) { $scriptWeights[$relativePath] } else { 3 }
		[pscustomobject]@{
			FullName = $_.FullName
			Weight = $weight
		}
	} | Sort-Object @{ Expression = { $_.Weight }; Descending = $true }, FullName)

	$buckets = @()
	$bucketWeights = @()
	for ($i = 0; $i -lt $WorkerCount; $i++) {
		$buckets += ,([System.Collections.Generic.List[string]]::new())
		$bucketWeights += 0
	}

	# Assign each script to the lightest worker bucket so parallel workers finish together.
	foreach ($item in $weightedScripts) {
		$lightestIndex = 0
		for ($i = 1; $i -lt $WorkerCount; $i++) {
			if ($bucketWeights[$i] -lt $bucketWeights[$lightestIndex]) {
				$lightestIndex = $i
			}
		}

		$buckets[$lightestIndex].Add($item.FullName)
		$bucketWeights[$lightestIndex] += $item.Weight
	}

	return ,$buckets
}

# Resolve the repository root used for display paths and worker execution.
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

# Execute assigned scripts sequentially when invoked as an isolated worker process.
if (-not [string]::IsNullOrWhiteSpace($WorkerScriptListPath)) {
	Import-Module Pester -MinimumVersion 5.0.0 | Out-Null
	$workerPayload = Get-Content -LiteralPath $WorkerScriptListPath -Raw | ConvertFrom-Json -AsHashtable
	$workerFailedPaths = [System.Collections.Generic.List[string]]::new()

	foreach ($scriptFullPath in @($workerPayload.scripts)) {
		$displayPath = GetRelativeDisplayPath -RootPath $repositoryRoot -ChildPath $scriptFullPath
		Write-Host "Running $displayPath"

		$testResult = Invoke-Pester -Path $scriptFullPath -PassThru

		if ($testResult.FailedCount -gt 0) {
			$workerFailedPaths.Add($displayPath)
		}
	}

	# Record failing scripts for the parent runner and exit with the worker status.
	[System.IO.File]::WriteAllText($workerPayload.resultPath, (@{ failed = @($workerFailedPaths) } | ConvertTo-Json -Compress), $utf8)
	if ($workerFailedPaths.Count -gt 0) {
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
$workerTempDir = $null
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

	# Partition test scripts across isolated parallel PowerShell worker processes.
	$workerCount = [Math]::Min($testScriptPaths.Count, [Math]::Max(2, [Math]::Min([Environment]::ProcessorCount, 8)))
	$buckets = SplitTestScriptBuckets -TestScriptPaths $testScriptPaths -RepositoryRoot $repositoryRoot -WorkerCount $workerCount
	$workerTempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pester-workers-' + [System.Guid]::NewGuid().ToString('N'))
	[System.IO.Directory]::CreateDirectory($workerTempDir) | Out-Null
	$pwshPath = (Get-Process -Id $PID).Path
	$workerJobs = [System.Collections.Generic.List[hashtable]]::new()

	for ($i = 0; $i -lt $buckets.Count; $i++) {
		if ($buckets[$i].Count -eq 0) {
			continue
		}

		$listPath = Join-Path $workerTempDir "worker-$i.json"
		$resultPath = Join-Path $workerTempDir "worker-$i-result.json"
		$payload = @{
			scripts = @($buckets[$i])
			resultPath = $resultPath
		} | ConvertTo-Json -Depth 5 -Compress
		[System.IO.File]::WriteAllText($listPath, $payload, $utf8)
		$workerJobs.Add(@{
			listPath = $listPath
			resultPath = $resultPath
		})
	}

	# Run each worker process in parallel and collect its buffered output and exit status.
	$runnerScriptPath = $PSCommandPath
	$workerOutputs = @($workerJobs | ForEach-Object -Parallel {
		$job = $_
		$lines = @(& $using:pwshPath -NoProfile -NonInteractive -File $using:runnerScriptPath -WorkerScriptListPath $job.listPath 2>&1)
		[pscustomobject]@{
			ExitCode = $LASTEXITCODE
			Lines = $lines
			ResultPath = $job.resultPath
		}
	} -ThrottleLimit $workerJobs.Count)

	# Print each worker's buffered output cleanly and aggregate any failed scripts.
	foreach ($workerOutput in $workerOutputs) {
		foreach ($line in $workerOutput.Lines) {
			Write-Host $line
		}

		if (Test-Path -LiteralPath $workerOutput.ResultPath) {
			$resultData = Get-Content -LiteralPath $workerOutput.ResultPath -Raw | ConvertFrom-Json -AsHashtable
			foreach ($failedPath in @($resultData.failed)) {
				$failedScriptPaths.Add($failedPath)
			}
		}
		elseif ($workerOutput.ExitCode -ne 0) {
			$failedScriptPaths.Add('Worker process exited unexpectedly')
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
	# Clean up temporary worker and tool directories.
	if (-not [string]::IsNullOrWhiteSpace($workerTempDir) -and (Test-Path -LiteralPath $workerTempDir)) {
		Remove-Item -LiteralPath $workerTempDir -Recurse -Force -ErrorAction Ignore
	}

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

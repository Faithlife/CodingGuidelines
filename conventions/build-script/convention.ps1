#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

Get-Command -Name git -ErrorAction Stop | Out-Null

# Run git with consistent failure handling and optional output capture.
function InvokeGitCommand {
	param(
		[Parameter(Mandatory = $true)]
		[string[]] $Arguments,

		[switch] $CaptureOutput,

		[string] $FailureMessage = 'Git command failed.'
	)

	if ($CaptureOutput) {
		[string[]] $output = @(& git @Arguments)
	}
	else {
		& git @Arguments | Out-Null
	}

	if ($LASTEXITCODE -ne 0) {
		throw $FailureMessage
	}

	if ($CaptureOutput) {
		return $output
	}
}

# Return the current Git index mode for a repository-relative path.
function GetGitIndexMode {
	param(
		[Parameter(Mandatory = $true)]
		[string] $RepositoryRelativePath
	)

	[string[]] $indexLines = @(InvokeGitCommand -Arguments @('ls-files', '--stage', '--', $RepositoryRelativePath) -CaptureOutput -FailureMessage "Failed to read the Git index entry for '$RepositoryRelativePath'.")

	if ($indexLines.Count -eq 0) {
		return $null
	}

	return ($indexLines[0] -split '\s+', 2)[0]
}

# Mark a copied build script executable in the worktree where Git can observe file modes.
function SetBuildScriptExecutable {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	# Windows Git does not derive the executable bit from the filesystem.
	if ($IsWindows) {
		return
	}

	# Use the platform chmod so later broad git-add operations preserve 100755.
	$chmodCommand = Get-Command -Name chmod -ErrorAction Stop
	& $chmodCommand '+x' $Path

	if ($LASTEXITCODE -ne 0) {
		throw "Failed to mark '$Path' as executable in the worktree."
	}
}

# Copy the published build script into the repository root.
$sourceBuildScriptPath = Join-Path $PSScriptRoot 'files' 'build.ps1'
$targetBuildScriptPath = Join-Path (Get-Location) 'build.ps1'
$copyResult = Copy-FileIfDifferent -SourcePath $sourceBuildScriptPath -DestinationPath $targetBuildScriptPath
$modeBefore = GetGitIndexMode -RepositoryRelativePath 'build.ps1'

# Report file content changes before enforcing executable mode.
if ($copyResult.Updated) {
	Write-Host "Updated '$targetBuildScriptPath' from the published Faithlife build script."
}
elseif ($copyResult.Created) {
	Write-Host "Created '$targetBuildScriptPath' from the published Faithlife build script."
}

# Stage the build script and mark it executable in both the worktree and Git.
SetBuildScriptExecutable -Path $targetBuildScriptPath
InvokeGitCommand -Arguments @('add', '--', 'build.ps1') -FailureMessage "Failed to stage 'build.ps1'."
InvokeGitCommand -Arguments @('update-index', '--chmod=+x', '--', 'build.ps1') -FailureMessage "Failed to mark 'build.ps1' as executable in Git."

$modeAfter = GetGitIndexMode -RepositoryRelativePath 'build.ps1'

# Verify the staged executable bit was applied.
if ($modeAfter -ne '100755') {
	throw "Expected 'build.ps1' to have Git mode 100755, but found '$modeAfter'."
}

# Report permission-only outcomes.
if ($modeBefore -ne '100755') {
	Write-Host "Marked 'build.ps1' as executable in Git."
}

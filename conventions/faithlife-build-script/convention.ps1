#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding
Get-Command -Name git -ErrorAction Stop | Out-Null

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

$sourceBuildScriptPath = Join-Path $PSScriptRoot 'files\build.ps1'
$targetBuildScriptPath = Join-Path (Get-Location) 'build.ps1'
$copyResult = Copy-FileIfDifferent -SourcePath $sourceBuildScriptPath -DestinationPath $targetBuildScriptPath
$modeBefore = GetGitIndexMode -RepositoryRelativePath 'build.ps1'

if ($copyResult.Updated) {
	Write-Host "Updated '$targetBuildScriptPath' from the published Faithlife build script."
}
elseif ($copyResult.Created) {
	Write-Host "Created '$targetBuildScriptPath' from the published Faithlife build script."
}

InvokeGitCommand -Arguments @('add', '--', 'build.ps1') -FailureMessage "Failed to stage 'build.ps1'."
InvokeGitCommand -Arguments @('update-index', '--chmod=+x', '--', 'build.ps1') -FailureMessage "Failed to mark 'build.ps1' as executable in Git."

$modeAfter = GetGitIndexMode -RepositoryRelativePath 'build.ps1'

if ($modeAfter -ne '100755') {
	throw "Expected 'build.ps1' to have Git mode 100755, but found '$modeAfter'."
}

if (-not $copyResult.Changed -and $modeBefore -eq '100755') {
	Write-Host "'build.ps1' already matches the published Faithlife build script and is executable in Git."
}
elseif ($modeBefore -ne '100755') {
	Write-Host "Marked 'build.ps1' as executable in Git."
}


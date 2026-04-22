Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

$requiredRule = '* text=auto eol=lf'
$gitattributesPath = Join-Path -Path (Get-Location) -ChildPath '.gitattributes'

function InvokeGit {
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

function TestGitHasStagedChanges {
	[string[]] $stagedLines = @(InvokeGit -Arguments @('diff', '--cached', '--name-only') -CaptureOutput -FailureMessage 'Failed to inspect staged git changes.')
	return $stagedLines.Count -gt 0
}

function NewCommitFromStagedChanges {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Message
	)

	# This convention creates a few small commits; skip the commit entirely when the stage is empty.
	if (-not (TestGitHasStagedChanges)) {
		return $null
	}

	InvokeGit -Arguments @('commit', '-m', $Message) -FailureMessage "Failed to create commit '$Message'."
	[string[]] $headLines = @(InvokeGit -Arguments @('rev-parse', 'HEAD') -CaptureOutput -FailureMessage 'Failed to read the current commit ID.')
	return $headLines[0]
}

function ResetWorkingTreeAfterAttributeChange {
	Write-Host 'Refreshing the working tree after line-ending normalization.'
	InvokeGit -Arguments @('rm', '--cached', '-r', '.') -FailureMessage 'Failed to clear the Git index after renormalization.'
	InvokeGit -Arguments @('reset', '--hard') -FailureMessage 'Failed to restore the working tree after renormalization.'
}

function TestConformingGitattributes {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		return $false
	}

	[string[]] $lines = @(Get-Content -LiteralPath $Path)
	return $lines.Count -gt 0 -and $lines[0] -eq $requiredRule
}

function InvokeCopilotForGitattributesRepair {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	Get-Command -Name copilot -ErrorAction Stop | Out-Null

	$copilotInstructions = @"
Update `.gitattributes` in the current repository so it satisfies all of these requirements:

- The first line must be exactly `* text=auto eol=lf`.
- If that line already exists later in the file, move it to the first line.
- Remove every other `.gitattributes` rule that contains `eol=`.
- Remove redundant repository-wide newline rules made obsolete by the required first line, such as `* text=auto` and `* -text`.
- Preserve rules that are not about line endings.
- Do not modify any file other than `.gitattributes`.
- Leave the working tree unstaged.

When you are done, make sure `.gitattributes` exists and starts with `* text=auto eol=lf`.
"@

	# Use an isolated Copilot config directory so the repair step does not depend on or mutate the user's setup.
	$copilotConfigDirectory = New-TemporaryDirectory

	try {
		Write-Host ".gitattributes is not compliant; starting Copilot to update '$Path'."
		$copilotInstructions | & copilot --config-dir $copilotConfigDirectory --no-ask-user --allow-all-tools --allow-all-paths --model auto
	}
	finally {
		Remove-Item -LiteralPath $copilotConfigDirectory -Recurse -Force
	}
}

function SetCompliantGitattributes {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		Write-Host "Creating '$Path' with LF normalization enabled."
		Write-Utf8NoBomFile -Path $Path -Content ($requiredRule + "`n")
		return
	}

	if (TestConformingGitattributes -Path $Path) {
		Write-Host "'$Path' already starts with '$requiredRule'."
		return
	}

	InvokeCopilotForGitattributesRepair -Path $Path

	if (-not (TestConformingGitattributes -Path $Path)) {
		throw "Copilot failed to update '$Path' to the required LF configuration."
	}
}

Get-Command -Name git -ErrorAction Stop | Out-Null

SetCompliantGitattributes -Path $gitattributesPath

# Commit the attribute change first so the later renormalization commit contains only file content rewrites.
InvokeGit -Arguments @('add', '.gitattributes') -FailureMessage "Failed to stage '$gitattributesPath'."
$useLfCommitId = NewCommitFromStagedChanges -Message 'Use LF.'

if ($null -eq $useLfCommitId) {
	return
}

# Refresh before renormalizing so Git re-reads the index under the new attributes.
ResetWorkingTreeAfterAttributeChange

Write-Host 'Staging line-ending renormalization for tracked files.'
InvokeGit -Arguments @('add', '--renormalize', '.') -FailureMessage 'Failed to stage line-ending renormalization.'

$renormalizeCommitId = NewCommitFromStagedChanges -Message 'Convert CRLF to LF.'

if ($null -eq $renormalizeCommitId) {
	return
}

$gitBlameIgnoreRevsPath = Join-Path -Path (Get-Location) -ChildPath '.git-blame-ignore-revs'
$ignoreRevsLines = @()

if (Test-Path -LiteralPath $gitBlameIgnoreRevsPath -PathType Leaf) {
	$ignoreRevsLines = @(Get-Content -LiteralPath $gitBlameIgnoreRevsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if (-not ($ignoreRevsLines -contains $renormalizeCommitId)) {
	$ignoreRevsLines += $renormalizeCommitId
}

Write-Utf8NoBomFile -Path $gitBlameIgnoreRevsPath -Content (($ignoreRevsLines -join "`n") + "`n")
InvokeGit -Arguments @('add', '.git-blame-ignore-revs') -FailureMessage "Failed to stage '$gitBlameIgnoreRevsPath'."
$ignoreRevsCommitId = NewCommitFromStagedChanges -Message 'Ignore CRLF to LF for git blame.'

if ($null -eq $ignoreRevsCommitId) {
	throw 'Expected a git blame ignore commit after renormalizing line endings.'
}

ResetWorkingTreeAfterAttributeChange

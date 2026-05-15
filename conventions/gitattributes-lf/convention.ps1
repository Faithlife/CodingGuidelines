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

$requiredRule = '* text=auto eol=lf'
$gitattributesPath = Join-Path -Path (Get-Location) -ChildPath '.gitattributes'
$gitattributesDisplayPath = Format-RepositoryRelativePath -Path $gitattributesPath

# Run git with consistent failure handling and optional output capture.
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

# Detect whether the Git index currently contains staged changes.
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

# Refresh the index and working tree after attributes change.
function ResetWorkingTreeAfterAttributeChange {
	Write-Host 'Refreshing the working tree after line-ending normalization.'
	InvokeGit -Arguments @('rm', '--cached', '-r', '.') -FailureMessage 'Failed to clear the Git index after renormalization.'
	InvokeGit -Arguments @('reset', '--hard') -FailureMessage 'Failed to restore the working tree after renormalization.'
}

# Split a .gitattributes rule into tokens while ignoring comments and blank lines.
function GetGitattributesRuleTokens {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Line
	)

	# Comments and blank lines do not declare attributes.
	$trimmedLine = $Line.Trim()

	if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#', [System.StringComparison]::Ordinal)) {
		return @()
	}

	# Git attributes are whitespace-delimited after the pattern token.
	return @($trimmedLine -split '\s+')
}

# Detect whether a .gitattributes rule declares an eol attribute.
function TestGitattributesRuleHasEolAttribute {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Line
	)

	# The first token is the path pattern, so only later tokens can be attributes.
	[string[]] $tokens = @(GetGitattributesRuleTokens -Line $Line)

	for ($index = 1; $index -lt $tokens.Count; $index++) {
		if ($tokens[$index].StartsWith('eol=', [System.StringComparison]::Ordinal)) {
			return $true
		}
	}

	return $false
}

# Remove eol attributes from a .gitattributes rule, dropping empty rules.
function RemoveGitattributesEolAttribute {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Line
	)

	# Leave comments, blank lines, and pattern-only lines unchanged.
	[string[]] $tokens = @(GetGitattributesRuleTokens -Line $Line)

	if ($tokens.Count -le 1) {
		return $Line
	}

	# Remove only eol attributes and preserve every other attribute token.
	[string[]] $remainingAttributes = @()

	for ($index = 1; $index -lt $tokens.Count; $index++) {
		if (-not $tokens[$index].StartsWith('eol=', [System.StringComparison]::Ordinal)) {
			$remainingAttributes += $tokens[$index]
		}
	}

	# A rule with no attributes left no longer does anything useful.
	if ($remainingAttributes.Count -eq 0) {
		return $null
	}

	return (@($tokens[0]) + $remainingAttributes) -join ' '
}

# Detect repository-wide rules made redundant by the required LF rule.
function TestObsoleteRepositoryWideNewlineRule {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Line
	)

	# Compare trimmed lines so harmless surrounding whitespace does not preserve obsolete rules.
	$trimmedLine = $Line.Trim()
	return $trimmedLine -eq '* text=auto' -or $trimmedLine -eq '* -text'
}

# Check whether .gitattributes starts with the required LF rule.
function TestConformingGitattributes {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		return $false
	}

	[string[]] $lines = @(Get-Content -LiteralPath $Path)

	if ($lines.Count -eq 0 -or $lines[0] -ne $requiredRule) {
		return $false
	}

	# Later rules must not reintroduce line-ending overrides or redundant repository-wide rules.
	for ($index = 1; $index -lt $lines.Count; $index++) {
		if ($lines[$index].Trim() -eq $requiredRule -or
			(TestGitattributesRuleHasEolAttribute -Line $lines[$index]) -or
			(TestObsoleteRepositoryWideNewlineRule -Line $lines[$index])) {
			return $false
		}
	}

	return $true
}

# Repair a nonconforming .gitattributes file deterministically.
function RepairGitattributesLfRules {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	# Start with the required repository-wide LF rule.
	$displayPath = Format-RepositoryRelativePath -Path $Path
	Write-Host ".gitattributes is not compliant; updating '$displayPath'."
	$updatedLines = [System.Collections.Generic.List[string]]::new()
	$updatedLines.Add($requiredRule)

	# Preserve useful existing rules while removing duplicate and conflicting line-ending policy.
	foreach ($line in @(Get-Content -LiteralPath $Path)) {
		if ($line.Trim() -eq $requiredRule -or (TestObsoleteRepositoryWideNewlineRule -Line $line)) {
			continue
		}

		$updatedLine = RemoveGitattributesEolAttribute -Line $line

		if ($null -ne $updatedLine) {
			$updatedLines.Add($updatedLine)
		}
	}

	# Write the repaired attributes file with a final LF newline.
	[System.IO.File]::WriteAllText($Path, (($updatedLines -join "`n") + "`n"), $utf8)
}

# Create or repair .gitattributes so the required rule is first.
function SetCompliantGitattributes {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	$displayPath = Format-RepositoryRelativePath -Path $Path

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		Write-Host "Creating '$displayPath' with LF normalization enabled."
		[System.IO.File]::WriteAllText($Path, ($requiredRule + "`n"), $utf8)
		return
	}

	if (TestConformingGitattributes -Path $Path) {
		Write-Host "'$displayPath' already starts with '$requiredRule'."
		return
	}

	RepairGitattributesLfRules -Path $Path

	if (-not (TestConformingGitattributes -Path $Path)) {
		throw "Failed to update '$displayPath' to the required LF configuration."
	}
}

# Ensure git is available before making attribute commits.
Get-Command -Name git -ErrorAction Stop | Out-Null

# Bring .gitattributes into compliance before renormalizing files.
SetCompliantGitattributes -Path $gitattributesPath

# Commit the attribute change first so the later renormalization commit contains only file content rewrites.
InvokeGit -Arguments @('add', '.gitattributes') -FailureMessage "Failed to stage '$gitattributesDisplayPath'."
$useLfCommitId = NewCommitFromStagedChanges -Message 'Use LF'

if ($null -eq $useLfCommitId) {
	return
}

# Refresh before renormalizing so Git re-reads the index under the new attributes.
ResetWorkingTreeAfterAttributeChange

Write-Host 'Staging line-ending renormalization for tracked files.'
InvokeGit -Arguments @('add', '--renormalize', '.') -FailureMessage 'Failed to stage line-ending renormalization.'

$renormalizeCommitId = NewCommitFromStagedChanges -Message 'Convert CRLF to LF'

if ($null -eq $renormalizeCommitId) {
	return
}

# Record the renormalization commit so future blame can ignore it.
$gitBlameIgnoreRevsPath = Join-Path -Path (Get-Location) -ChildPath '.git-blame-ignore-revs'
$ignoreRevsLines = @()

# Preserve any existing ignore-revs entries.
if (Test-Path -LiteralPath $gitBlameIgnoreRevsPath -PathType Leaf) {
	$ignoreRevsLines = @(Get-Content -LiteralPath $gitBlameIgnoreRevsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

# Add the new renormalization commit when it is not already listed.
if (-not ($ignoreRevsLines -contains $renormalizeCommitId)) {
	$ignoreRevsLines += $renormalizeCommitId
}

# Write and commit the updated blame-ignore list.
[System.IO.File]::WriteAllText($gitBlameIgnoreRevsPath, (($ignoreRevsLines -join "`n") + "`n"), $utf8)
InvokeGit -Arguments @('add', '.git-blame-ignore-revs') -FailureMessage "Failed to stage '$(Format-RepositoryRelativePath -Path $gitBlameIgnoreRevsPath)'."
$ignoreRevsCommitId = NewCommitFromStagedChanges -Message 'Ignore CRLF to LF for git blame'

if ($null -eq $ignoreRevsCommitId) {
	throw 'Expected a git blame ignore commit after renormalizing line endings.'
}

# Restore the working tree after the final convention-created commit.
ResetWorkingTreeAfterAttributeChange

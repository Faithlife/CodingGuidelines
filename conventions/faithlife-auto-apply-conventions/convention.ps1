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

# Locate the managed conventions file and marker text.
$targetRelativePath = '.github/conventions.yml'
$targetPath = Join-Path (Get-Location) '.github' 'conventions.yml'
$requiredFirstLine = '# applied automatically by https://github.com/Faithlife/RepoConventionsApplier (DO NOT REMOVE THIS LINE)'

if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
	throw "Expected '$targetRelativePath' to exist."
}

# Split the first line from the remaining content while preserving line endings.
$content = [System.IO.File]::ReadAllText($targetPath)
$lineEnding = Get-LineEnding -Content $content
$firstLineEndIndex = $content.IndexOf("`n", [System.StringComparison]::Ordinal)

if ($firstLineEndIndex -eq -1) {
	$firstLine = $content
	$remainingContent = ''
	$hasLineEndingAfterFirstLine = $false
}
else {
	$firstLine = $content.Substring(0, $firstLineEndIndex)
	if ($firstLine.EndsWith("`r", [System.StringComparison]::Ordinal)) {
		$firstLine = $firstLine.Substring(0, $firstLine.Length - 1)
	}

	$remainingContent = $content.Substring($firstLineEndIndex + 1)
	$hasLineEndingAfterFirstLine = $true
}

# Leave the file unchanged when the current marker is already present.
if ($firstLine -ceq $requiredFirstLine) {
	Write-Host "'$targetRelativePath' already starts with the RepoConventionsApplier marker."
	return
}

# Replace an older automation marker instead of inserting a second marker line.
if ($firstLine.Contains('DO NOT REMOVE', [System.StringComparison]::Ordinal)) {
	$newContent = if ($hasLineEndingAfterFirstLine) {
		$requiredFirstLine + $lineEnding + $remainingContent
	}
	else {
		$requiredFirstLine
	}

	[System.IO.File]::WriteAllText($targetPath, $newContent, $utf8)
	Write-Host "Updated existing auto-apply marker in '$targetRelativePath'."
	return
}

# Insert the marker at the top of normal conventions content.
$newContent = if ([string]::IsNullOrEmpty($content)) {
	$requiredFirstLine + $lineEnding
}
else {
	$requiredFirstLine + $lineEnding + $content
}

[System.IO.File]::WriteAllText($targetPath, $newContent, $utf8)
Write-Host "Added RepoConventionsApplier marker to '$targetRelativePath'."

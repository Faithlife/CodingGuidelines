Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

function GetConfiguredEntries {
	param(
		[Parameter(Mandatory = $true)]
		[object] $EntriesSetting
	)

	if ($EntriesSetting -is [string]) {
		throw "The 'entries' setting must be an array of strings."
	}

	if ($EntriesSetting -isnot [System.Collections.IEnumerable]) {
		throw "The 'entries' setting must be an array of strings."
	}

	$entries = [System.Collections.Generic.List[string]]::new()

	foreach ($entry in $EntriesSetting) {
		if ($entry -isnot [string]) {
			throw "Each entry in 'entries' must be a string."
		}

		if ($entry.Contains("`r") -or $entry.Contains("`n")) {
			throw "Each entry in 'entries' must be a single line."
		}

		$entries.Add($entry)
	}

	return (, $entries)
}

if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$inputPath = $args[0]
$settings = Read-ConventionSettings -InputPath $inputPath

if ($null -eq $settings -or -not $settings.ContainsKey('path')) {
	throw "The 'path' setting is required."
}

if (-not $settings.ContainsKey('entries')) {
	throw "The 'entries' setting is required."
}

$targetPath = Get-RepositoryPath -PathSetting $settings.path
$configuredEntries = GetConfiguredEntries -EntriesSetting $settings.entries

if ($configuredEntries.Count -eq 0) {
	Write-Host "No configured entries to add for '$targetPath'."
	return
}

if (Test-Path -LiteralPath $targetPath -PathType Container) {
	throw "The target path '$targetPath' is a directory."
}

$existingContent = ''
$existingEntries = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
	$existingContent = [System.IO.File]::ReadAllText($targetPath)

	foreach ($line in Get-Content -LiteralPath $targetPath) {
		$null = $existingEntries.Add($line)
	}
}

$seenEntries = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

foreach ($existingEntry in $existingEntries) {
	$null = $seenEntries.Add($existingEntry)
}

$entriesToAdd = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $configuredEntries) {
	if ($seenEntries.Add($entry)) {
		$entriesToAdd.Add($entry)
	}
}

if ($entriesToAdd.Count -eq 0) {
	Write-Host "'$targetPath' already contains all configured entries."
	return
}

$targetDirectory = [System.IO.Path]::GetDirectoryName($targetPath)

if (-not [string]::IsNullOrEmpty($targetDirectory)) {
	[System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
}

$lineEnding = Get-LineEnding -Content $existingContent
$prefix = ''

if ($existingContent.Length -gt 0 -and -not ($existingContent.EndsWith("`r`n", [System.StringComparison]::Ordinal) -or $existingContent.EndsWith("`n", [System.StringComparison]::Ordinal))) {
	$prefix = $lineEnding
}

$newContent = $existingContent + $prefix + ($entriesToAdd -join $lineEnding) + $lineEnding
Write-Utf8NoBomFile -Path $targetPath -Content $newContent

Write-Host "Added $($entriesToAdd.Count) entries to '$targetPath'."

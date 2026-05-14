#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load shared helper functions for writing generated files.
$helpersPath = Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'scripts' 'Helpers.ps1'
. $helpersPath

# Resolve the markdown source, generated output, and provenance comment.
$sourcePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' '..' 'sections' 'csharp' 'editorconfig.md'))
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'editorconfig-csharp' 'files' '.editorconfig'))
$generatedFromComment = '# generated from https://github.com/Faithlife/CodingGuidelines/blob/master/sections/csharp/editorconfig.md'

# Extract editorconfig code fences from the markdown source.
$markdown = Get-Content -LiteralPath $sourcePath -Raw
$codeFenceCollection = [System.Text.RegularExpressions.Regex]::Matches($markdown, '```editorconfig\s*(.*?)```', [System.Text.RegularExpressions.RegexOptions]::Singleline)

# Return a stable sort rank for indentation-related settings.
function GetLineSortRank {
	param([string] $line)

	# Put whitespace settings before other settings, in a consistent order.
	switch -Regex ($line) {
		'^indent_size\s*=' { return 0 }
		'^indent_style\s*=' { return 1 }
		'^tab_width\s*=' { return 2 }
		'^insert_final_newline\s*=' { return 3 }
		'^trim_trailing_whitespace\s*=' { return 4 }
		default { return 5 }
	}
}

# Fail fast when the source markdown has no editorconfig content.
if ($codeFenceCollection.Count -eq 0) {
	throw "No editorconfig code fences were found in '$sourcePath'."
}

# Flatten the captured fence contents into individual candidate lines.
[string[]] $lines = [System.Text.RegularExpressions.Regex]::Split((-join ($codeFenceCollection | ForEach-Object { $_.Groups[1].Value })), '\r?\n')

# Prepare collections for preamble lines and parsed sections.
$contentLines = @($lines | Where-Object { $_ -ne '' })
$preambleLines = [System.Collections.Generic.List[string]]::new()
$sections = [System.Collections.Generic.List[object]]::new()
$currentSectionHeader = $null
$currentSectionLines = [System.Collections.Generic.List[string]]::new()

# Split the source lines into an optional preamble and named sections.
foreach ($line in $contentLines) {
	if ($line -match '^\[.+\]$') {
		# Save the previous section before starting a new one.
		if ($null -ne $currentSectionHeader) {
			$sections.Add([pscustomobject]@{
				Header = $currentSectionHeader
				Lines = @($currentSectionLines)
			})
		}

		# Start collecting lines for the newly discovered section.
		$currentSectionHeader = $line
		$currentSectionLines = [System.Collections.Generic.List[string]]::new()
		continue
	}

	# Preserve lines before the first section as generated-file preamble.
	if ($null -eq $currentSectionHeader) {
		$preambleLines.Add($line)
		continue
	}

	# Add non-header lines to the active section.
	$currentSectionLines.Add($line)
}

# Save the final section after the parsing loop completes.
if ($null -ne $currentSectionHeader) {
	$sections.Add([pscustomobject]@{
		Header = $currentSectionHeader
		Lines = @($currentSectionLines)
	})
}

# Fail fast when the markdown did not define any editorconfig sections.
if ($sections.Count -eq 0) {
	throw "No editorconfig sections were found in '$sourcePath'."
}

# Start the generated content with its provenance comment.
$newLines = [System.Collections.Generic.List[string]]::new()
$newLines.Add($generatedFromComment)

# Copy any preamble lines before the first generated section.
foreach ($preambleLine in $preambleLines) {
	$newLines.Add($preambleLine)
}

# Separate the preamble from the generated sections when needed.
if ($preambleLines.Count -gt 0) {
	$newLines.Add('')
}

# Add each section with indentation settings sorted before other settings.
for ($sectionIndex = 0; $sectionIndex -lt $sections.Count; $sectionIndex++) {
	# Keep a blank line between generated sections.
	if ($sectionIndex -gt 0) {
		$newLines.Add('')
	}

	# Write the section header before its sorted settings.
	$section = $sections[$sectionIndex]
	$newLines.Add($section.Header)

	# Sort section lines with special indentation settings first.
	foreach ($sectionLine in ($section.Lines | Sort-Object @{ Expression = { GetLineSortRank $_ } }, @{ Expression = { $_ } })) {
		$newLines.Add($sectionLine)
	}
}

# Join generated lines with LF endings and a final newline.
$newContent = ($newLines -join "`n") + "`n"

# Exit quietly when the generated file is already up to date.
if ((Test-Path -LiteralPath $destinationPath -PathType Leaf) -and (Get-Content -LiteralPath $destinationPath -Raw) -eq $newContent) {
	return
}

# Ensure the output directory exists before writing the generated file.
$destinationDirectory = Split-Path -Parent $destinationPath
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
Write-Utf8NoBomFile -Path $destinationPath -Content $newContent
Write-Host "Updated conventions/editorconfig-csharp/files/.editorconfig."

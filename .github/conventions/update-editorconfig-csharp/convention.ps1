#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'scripts' 'Helpers.ps1'
. $helpersPath

$sourcePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' '..' 'sections' 'csharp' 'editorconfig.md'))
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'editorconfig-csharp' 'files' '.editorconfig'))
$generatedFromComment = '# generated from https://github.com/Faithlife/CodingGuidelines/blob/master/sections/csharp/editorconfig.md'

$markdown = Get-Content -LiteralPath $sourcePath -Raw
$codeFenceCollection = [System.Text.RegularExpressions.Regex]::Matches($markdown, '```editorconfig\s*(.*?)```', [System.Text.RegularExpressions.RegexOptions]::Singleline)

function GetLineSortRank {
	param([string] $line)

	switch -Regex ($line) {
		'^indent_size\s*=' { return 0 }
		'^indent_style\s*=' { return 1 }
		'^tab_width\s*=' { return 2 }
		default { return 3 }
	}
}

if ($codeFenceCollection.Count -eq 0) {
	throw "No editorconfig code fences were found in '$sourcePath'."
}

[string[]] $lines = [System.Text.RegularExpressions.Regex]::Split((-join ($codeFenceCollection | ForEach-Object { $_.Groups[1].Value })), '\r?\n')

$contentLines = @($lines | Where-Object { $_ -ne '' })
$preambleLines = [System.Collections.Generic.List[string]]::new()
$sections = [System.Collections.Generic.List[object]]::new()
$currentSectionHeader = $null
$currentSectionLines = [System.Collections.Generic.List[string]]::new()

foreach ($line in $contentLines) {
	if ($line -match '^\[.+\]$') {
		if ($null -ne $currentSectionHeader) {
			$sections.Add([pscustomobject]@{
				Header = $currentSectionHeader
				Lines = @($currentSectionLines)
			})
		}

		$currentSectionHeader = $line
		$currentSectionLines = [System.Collections.Generic.List[string]]::new()
		continue
	}

	if ($null -eq $currentSectionHeader) {
		$preambleLines.Add($line)
		continue
	}

	$currentSectionLines.Add($line)
}

if ($null -ne $currentSectionHeader) {
	$sections.Add([pscustomobject]@{
		Header = $currentSectionHeader
		Lines = @($currentSectionLines)
	})
}

if ($sections.Count -eq 0) {
	throw "No editorconfig sections were found in '$sourcePath'."
}

$newLines = [System.Collections.Generic.List[string]]::new()
$newLines.Add($generatedFromComment)

foreach ($preambleLine in $preambleLines) {
	$newLines.Add($preambleLine)
}

if ($preambleLines.Count -gt 0) {
	$newLines.Add('')
}

for ($sectionIndex = 0; $sectionIndex -lt $sections.Count; $sectionIndex++) {
	if ($sectionIndex -gt 0) {
		$newLines.Add('')
	}

	$section = $sections[$sectionIndex]
	$newLines.Add($section.Header)

	foreach ($sectionLine in ($section.Lines | Sort-Object @{ Expression = { GetLineSortRank $_ } }, @{ Expression = { $_ } })) {
		$newLines.Add($sectionLine)
	}
}

$newContent = ($newLines -join "`n") + "`n"

if ((Test-Path -LiteralPath $destinationPath -PathType Leaf) -and (Get-Content -LiteralPath $destinationPath -Raw) -eq $newContent) {
	return
}

$destinationDirectory = Split-Path -Parent $destinationPath
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
Write-Utf8NoBomFile -Path $destinationPath -Content $newContent
Write-Host "Updated conventions/editorconfig-csharp/files/.editorconfig."
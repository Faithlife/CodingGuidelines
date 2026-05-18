#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load shared helpers for settings, paths, and line-ending detection.
$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

function GetGitIgnoreSectionName {
	param(
		[Parameter(Mandatory = $true)]
		[object] $NameSetting
	)

	# Match the validation used by config-text-section before reading markers.
	if ($NameSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($NameSetting)) {
		throw "The 'name' setting must be a non-empty string."
	}

	# Keep marker names on one line so managed blocks stay parseable.
	if ($NameSetting.Contains("`r") -or $NameSetting.Contains("`n")) {
		throw "The 'name' setting must be a single line."
	}

	return $NameSetting
}

function GetGitIgnoreSectionText {
	param(
		[Parameter(Mandatory = $true)]
		[object] $TextSetting
	)

	# Managed .gitignore text must be a literal string body.
	if ($TextSetting -isnot [string]) {
		throw "The 'text' setting must be a string."
	}

	# Reject embedded managed markers so cleanup never sees nested blocks.
	$textLines = ($TextSetting -replace "`r`n", "`n" -replace "`r", "`n") -split "`n", 0, 'SimpleMatch'
	foreach ($line in $textLines) {
		if ($line -eq '# END DO NOT EDIT' -or $line -match '^# DO NOT EDIT: .+ convention$') {
			throw "The 'text' setting must not contain managed section marker lines."
		}
	}

	return $TextSetting
}

function TestGitIgnorePatternLine {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

	# Only non-empty, non-comment lines represent patterns worth deduplicating.
	return $Text.Trim().Length -ne 0 -and -not $Text.StartsWith('#', [System.StringComparison]::Ordinal)
}

function GetManagedGitIgnorePatterns {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

	# Collect exact configured pattern lines so cleanup stays conservative.
	$patterns = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
	$textLines = ($Text -replace "`r`n", "`n" -replace "`r", "`n") -split "`n", 0, 'SimpleMatch'

	foreach ($line in $textLines) {
		if (TestGitIgnorePatternLine -Text $line) {
			$patterns.Add($line) | Out-Null
		}
	}

	return ,$patterns
}

function GetGitIgnoreLineObjects {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	# Convert file content into mutable line objects while preserving endings.
	$lines = [System.Collections.Generic.List[object]]::new()
	$position = 0

	while ($position -lt $Content.Length) {
		$lineStart = $position
		$lineBreakLength = 0

		while ($position -lt $Content.Length -and $Content[$position] -ne "`r" -and $Content[$position] -ne "`n") {
			$position++
		}

		$lineText = $Content.Substring($lineStart, $position - $lineStart)

		if ($position -lt $Content.Length) {
			if ($Content[$position] -eq "`r" -and ($position + 1) -lt $Content.Length -and $Content[$position + 1] -eq "`n") {
				$lineBreakLength = 2
			}
			else {
				$lineBreakLength = 1
			}

			$position += $lineBreakLength
		}

		$fullText = $Content.Substring($lineStart, $position - $lineStart)
		$lines.Add([pscustomobject]@{
			Text = $lineText
			Ending = $fullText.Substring($lineText.Length)
			Remove = $false
			IsManaged = $false
		})
	}

	return $lines
}

function SetGitIgnoreLineMetadata {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines
	)

	# Mark all lines enclosed by any managed section marker pair.
	$inManagedBlock = $false
	foreach ($line in $Lines) {
		if ($inManagedBlock) {
			$line.IsManaged = $true

			if ($line.Text -eq '# END DO NOT EDIT') {
				$inManagedBlock = $false
			}

			continue
		}

		if ($line.Text -match '^# DO NOT EDIT: .+ convention$') {
			$line.IsManaged = $true
			$inManagedBlock = $true
		}
	}
}

function SetRedundantGitIgnorePatternRemoval {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines,

		[Parameter(Mandatory = $true)]
		[System.Collections.Generic.HashSet[string]] $ManagedPatterns
	)

	# Remove exact unmanaged duplicates of patterns now owned by the managed section.
	$changed = $false
	foreach ($line in $Lines) {
		if (-not $line.IsManaged -and (TestGitIgnorePatternLine -Text $line.Text) -and $ManagedPatterns.Contains($line.Text)) {
			$line.Remove = $true
			$changed = $true
		}
	}

	return $changed
}

function JoinGitIgnoreLines {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines
	)

	# Rebuild content without lines marked for cleanup.
	$builder = [System.Text.StringBuilder]::new()
	foreach ($line in $Lines) {
		if (-not $line.Remove) {
			$builder.Append($line.Text) | Out-Null
			$builder.Append($line.Ending) | Out-Null
		}
	}

	return $builder.ToString()
}

function InvokeGitIgnoreSectionCleanup {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings
	)

	# Require the same top-level settings consumed by the composed section writer.
	if ($null -eq $Settings -or -not $Settings.Contains('name')) {
		throw "The 'name' setting is required."
	}

	if (-not $Settings.Contains('text')) {
		throw "The 'text' setting is required."
	}

	# Normalize configured values and locate the repository .gitignore.
	$name = GetGitIgnoreSectionName -NameSetting $Settings.name
	$text = GetGitIgnoreSectionText -TextSetting $Settings.text
	$gitIgnorePath = Get-RepositoryPath -PathSetting '.gitignore'
	$gitIgnoreDisplayPath = Format-RepositoryRelativePath -Path $gitIgnorePath

	# Skip cleanup when no target file exists after the composed convention runs.
	if (-not (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf)) {
		return
	}

	# Mark redundant unmanaged pattern lines while leaving managed blocks intact.
	$content = [System.IO.File]::ReadAllText($gitIgnorePath)
	$managedPatterns = GetManagedGitIgnorePatterns -Text $text
	$lines = @(GetGitIgnoreLineObjects -Content $content)
	SetGitIgnoreLineMetadata -Lines $lines
	$changed = SetRedundantGitIgnorePatternRemoval -Lines $lines -ManagedPatterns $managedPatterns
	$newContent = JoinGitIgnoreLines -Lines $lines

	# Write only when cleanup changed the gitignore text.
	if ($changed -and $newContent -cne $content) {
		[System.IO.File]::WriteAllText($gitIgnorePath, $newContent, $utf8)
		Write-Host "Cleaned redundant patterns for '$name' section in '$gitIgnoreDisplayPath'."
	}
}

# Clean up unmanaged .gitignore patterns after the composed section writer runs.
$settings = Read-ConventionSettings -InputPath $args[0]
InvokeGitIgnoreSectionCleanup -Settings $settings

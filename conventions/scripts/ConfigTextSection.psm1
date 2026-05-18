#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$helpersPath = Join-Path $PSScriptRoot 'Helpers.ps1'
. $helpersPath

<#
.SYNOPSIS
Validates and returns a managed config text section name.

.DESCRIPTION
Normalizes the shared `name` setting contract for conventions that create or inspect managed config text sections. A section name must be a non-empty single-line string because it is embedded in marker comments and later used to find matching managed blocks.

.PARAMETER NameSetting
The raw `name` setting value from convention settings.

.OUTPUTS
System.String. The validated section name.
#>
function Get-ConfigTextSectionName {
	param(
		[Parameter(Mandatory = $true)]
		[object] $NameSetting
	)

	# Require a non-empty section name for marker matching and messages.
	if ($NameSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($NameSetting)) {
		throw "The 'name' setting must be a non-empty string."
	}

	# Keep marker names on one line so section boundaries stay parseable.
	if ($NameSetting.Contains("`r") -or $NameSetting.Contains("`n")) {
		throw "The 'name' setting must be a single line."
	}

	return $NameSetting
}

function Get-ConfigTextSectionCommentPrefix {
	param(
		[Parameter(Mandatory = $true)]
		[object] $CommentPrefixSetting
	)

	# Require a usable prefix for both opening and closing marker comments.
	if ($CommentPrefixSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($CommentPrefixSetting)) {
		throw "The 'comment-prefix' setting must be a non-empty string."
	}

	# Keep the prefix single-line so generated marker comments are unambiguous.
	if ($CommentPrefixSetting.Contains("`r") -or $CommentPrefixSetting.Contains("`n")) {
		throw "The 'comment-prefix' setting must be a single line."
	}

	return $CommentPrefixSetting
}

function Get-ConfigTextSectionCommentSuffix {
	param(
		[AllowNull()]
		[object] $CommentSuffixSetting
	)

	# Default to no suffix when the convention does not configure one.
	if ($null -eq $CommentSuffixSetting) {
		return ''
	}

	# Reject non-string suffix values before validating marker shape.
	if ($CommentSuffixSetting -isnot [string]) {
		throw "The 'comment-suffix' setting must be a string."
	}

	# Keep the suffix single-line so generated marker comments are unambiguous.
	if ($CommentSuffixSetting.Contains("`r") -or $CommentSuffixSetting.Contains("`n")) {
		throw "The 'comment-suffix' setting must be a single line."
	}

	return $CommentSuffixSetting
}

function Get-ConfigTextSectionMarkerCommentSuffixText {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $CommentSuffix
	)

	# Leave marker text unchanged when no suffix was configured.
	if ([string]::IsNullOrEmpty($CommentSuffix)) {
		return ''
	}

	# Separate a configured suffix from marker words with exactly one space.
	return ' ' + $CommentSuffix.TrimStart()
}

<#
.SYNOPSIS
Validates and returns managed config text section content.

.DESCRIPTION
Checks that a convention-provided `text` setting is a string and does not contain nested managed section marker lines for the configured comment syntax. Callers that inspect or write managed sections should use the same comment prefix and suffix that will appear in the target file.

.PARAMETER TextSetting
The raw `text` setting value from convention settings.

.PARAMETER CommentPrefix
The line comment prefix used for opening and closing managed section markers.

.PARAMETER CommentSuffix
The optional marker comment suffix text, including any leading separator expected in generated marker lines.

.OUTPUTS
System.String. The validated section text.
#>
function Get-ConfigTextSectionText {
	param(
		[Parameter(Mandatory = $true)]
		[object] $TextSetting,

		[Parameter(Mandatory = $true)]
		[string] $CommentPrefix,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $CommentSuffix
	)

	# Managed section text must be a literal string body.
	if ($TextSetting -isnot [string]) {
		throw "The 'text' setting must be a string."
	}

	# Build marker patterns using the configured comment delimiters.
	$openingPattern = '^' + [System.Text.RegularExpressions.Regex]::Escape($CommentPrefix) + ' DO NOT EDIT: .+ convention' + [System.Text.RegularExpressions.Regex]::Escape($CommentSuffix) + '$'
	$closingLine = "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	$textLines = ($TextSetting -replace "`r`n", "`n" -replace "`r", "`n") -split "`n", 0, 'SimpleMatch'

	# Reject embedded managed markers so generated sections cannot nest.
	foreach ($line in $textLines) {
		if ($line -eq $closingLine -or $line -match $openingPattern) {
			throw "The 'text' setting must not contain managed section marker lines."
		}
	}

	return $TextSetting
}

function Get-ConfigTextSection {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings
	)

	# Require the settings that define marker identity, content, and syntax.
	if (-not $Settings.Contains('name')) {
		throw "The 'name' setting is required."
	}

	if (-not $Settings.Contains('text')) {
		throw "The 'text' setting is required."
	}

	if (-not $Settings.Contains('comment-prefix')) {
		throw "The 'comment-prefix' setting is required."
	}

	# Normalize and validate each configured section field before use.
	$commentPrefix = Get-ConfigTextSectionCommentPrefix -CommentPrefixSetting $Settings['comment-prefix']
	$commentSuffix = Get-ConfigTextSectionMarkerCommentSuffixText -CommentSuffix (Get-ConfigTextSectionCommentSuffix -CommentSuffixSetting $Settings['comment-suffix'])
	$name = Get-ConfigTextSectionName -NameSetting $Settings.name
	$text = Get-ConfigTextSectionText -TextSetting $Settings.text -CommentPrefix $commentPrefix -CommentSuffix $commentSuffix

	# Return only normalized values that downstream writers need.
	return [pscustomobject]@{
		Name = $name
		Text = $text
		CommentPrefix = $commentPrefix
		CommentSuffix = $commentSuffix
	}
}

<#
.SYNOPSIS
Splits config text into line records with source indexes.

.DESCRIPTION
Parses text without discarding line-ending details. Each returned record contains the line text without its line ending plus the start and end indexes of the full line span in the original content. This lets convention cleanup logic preserve exact surrounding bytes while replacing or removing sections.

.PARAMETER Content
The full text content to parse. Empty content is allowed and returns no records.

.OUTPUTS
System.Object[]. Objects with `Text`, `StartIndex`, and `EndIndex` properties.
#>
function Get-ConfigTextSectionLineRecords {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	# Track text spans so section replacements can preserve surrounding content.
	$lineRecords = [System.Collections.Generic.List[object]]::new()
	$position = 0

	# Walk the content manually to preserve exact line-break lengths and indexes.
	while ($position -lt $Content.Length) {
		$lineStart = $position
		$lineBreakLength = 0

		# Advance to the next CR or LF without allocating intermediate lines.
		while ($position -lt $Content.Length -and $Content[$position] -ne "`r" -and $Content[$position] -ne "`n") {
			$position++
		}

		$lineText = $Content.Substring($lineStart, $position - $lineStart)

		# Include the original CRLF, CR, or LF bytes in the recorded span.
		if ($position -lt $Content.Length) {
			if ($Content[$position] -eq "`r" -and ($position + 1) -lt $Content.Length -and $Content[$position + 1] -eq "`n") {
				$lineBreakLength = 2
			}
			else {
				$lineBreakLength = 1
			}

			$position += $lineBreakLength
		}

		# Store the line text and absolute replacement indexes for later parsing.
		$lineRecords.Add([pscustomobject]@{
			Text = $lineText
			StartIndex = $lineStart
			EndIndex = $position
		})
	}

	return $lineRecords.ToArray()
}

<#
.SYNOPSIS
Finds managed config text section blocks in file content.

.DESCRIPTION
Scans content for `DO NOT EDIT` managed section marker pairs using the supplied comment syntax. The function returns named block spans and throws when markers are nested, unexpected, or unterminated so callers do not update ambiguous files.

.PARAMETER Content
The full target file content to inspect.

.PARAMETER CommentPrefix
The line comment prefix used for opening and closing managed section markers.

.PARAMETER CommentSuffix
The optional marker comment suffix text, including any leading separator expected in marker lines.

.PARAMETER TargetPath
The target path used in error messages when marker state is invalid.

.OUTPUTS
System.Object[]. Objects with `Name`, `StartIndex`, and `EndIndex` properties.
#>
function Get-ConfigTextSectionRecords {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[string] $CommentPrefix,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $CommentSuffix,

		[Parameter(Mandatory = $true)]
		[string] $TargetPath
	)

	# Match markers for the configured comment syntax in the target file.
	$openingPattern = '^' + [System.Text.RegularExpressions.Regex]::Escape($CommentPrefix) + ' DO NOT EDIT: (?<Name>.+) convention' + [System.Text.RegularExpressions.Regex]::Escape($CommentSuffix) + '$'
	$closingLine = "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	$blocks = [System.Collections.Generic.List[object]]::new()
	$currentBlock = $null

	# Walk line records so each discovered block keeps exact content indexes.
	foreach ($line in Get-ConfigTextSectionLineRecords -Content $Content) {
		if ($null -ne $currentBlock) {
			# A new opening marker before a close means the previous section is broken.
			if ($line.Text -match $openingPattern) {
				throw "Found an unterminated managed section before '$($line.Text)' in '$TargetPath'."
			}

			# Close the active block at the end of the closing marker line.
			if ($line.Text -eq $closingLine) {
				$blocks.Add([pscustomobject]@{
					Name = $currentBlock.Name
					StartIndex = $currentBlock.StartIndex
					EndIndex = $line.EndIndex
				})
				$currentBlock = $null
				continue
			}

			continue
		}

		# A closing marker without an active block cannot be reconciled safely.
		if ($line.Text -eq $closingLine) {
			throw "Found an unexpected '$closingLine' marker in '$TargetPath'."
		}

		$match = [System.Text.RegularExpressions.Regex]::Match($line.Text, $openingPattern)

		# Start tracking a managed block when an opening marker is found.
		if ($match.Success) {
			$currentBlock = [pscustomobject]@{
				Name = $match.Groups['Name'].Value
				StartIndex = $line.StartIndex
			}
		}
	}

	# Refuse to update files with an opening marker that was never closed.
	if ($null -ne $currentBlock) {
		throw "Found an unterminated managed section for '$($currentBlock.Name)' in '$TargetPath'."
	}

	return $blocks.ToArray()
}

function ConvertTo-ConfigTextSectionLineEndings {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	# Normalize all input newline forms to the target file's line ending.
	return ($Text -replace "`r`n", "`n" -replace "`r", "`n").Replace("`n", $LineEnding)
}

function Get-ConfigTextSectionTrailingLineEndingText {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

	# Preserve the exact trailing newline sequence from an existing block.
	if ($Text.EndsWith("`r`n", [System.StringComparison]::Ordinal)) {
		return "`r`n"
	}

	if ($Text.EndsWith("`n", [System.StringComparison]::Ordinal)) {
		return "`n"
	}

	if ($Text.EndsWith("`r", [System.StringComparison]::Ordinal)) {
		return "`r"
	}

	return ''
}

function New-ConfigTextSectionText {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text,

		[Parameter(Mandatory = $true)]
		[string] $CommentPrefix,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $CommentSuffix,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	# Normalize the body before wrapping it in managed section markers.
	$normalizedText = ConvertTo-ConfigTextSectionLineEndings -Text $Text -LineEnding $LineEnding
	$blockText = "$CommentPrefix DO NOT EDIT: $Name convention$CommentSuffix$LineEnding$normalizedText"

	# Ensure the closing marker starts on its own line.
	if (-not $normalizedText.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$blockText += $LineEnding
	}

	# Append the closing marker without forcing an extra newline.
	$blockText += "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	return $blockText
}

function Add-ConfigTextSectionSeparator {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	# Empty files need no spacer before the managed section.
	if ([string]::IsNullOrEmpty($Content)) {
		return $Content
	}

	# Keep an existing blank line before appending a new managed section.
	if ($Content.EndsWith($LineEnding + $LineEnding, [System.StringComparison]::Ordinal)) {
		return $Content
	}

	# Add one extra newline when the file already ends with a single newline.
	if ($Content.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		return $Content + $LineEnding
	}

	# Add a blank-line separator when existing content lacks a trailing newline.
	return $Content + $LineEnding + $LineEnding
}

function Set-ConfigTextSectionText {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[pscustomobject] $Section,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding,

		[Parameter(Mandatory = $true)]
		[string] $TargetPath
	)

	# Build the desired managed block and locate matching blocks in current content.
	$managedSection = New-ConfigTextSectionText -Name $Section.Name -Text $Section.Text -CommentPrefix $Section.CommentPrefix -CommentSuffix $Section.CommentSuffix -LineEnding $LineEnding
	$blocks = Get-ConfigTextSectionRecords -Content $Content -CommentPrefix $Section.CommentPrefix -CommentSuffix $Section.CommentSuffix -TargetPath $TargetPath
	$namedBlocks = @($blocks | Where-Object { $_.Name -eq $Section.Name })

	# Refuse ambiguous updates when more than one block has the same name.
	if ($namedBlocks.Count -gt 1) {
		throw "Found multiple managed sections named '$($Section.Name)' in '$TargetPath'."
	}

	# Replace an existing block while preserving its trailing newline style.
	if ($namedBlocks.Count -eq 1) {
		$block = $namedBlocks[0]
		$currentBlockText = $Content.Substring($block.StartIndex, $block.EndIndex - $block.StartIndex)
		$replacementBlockText = $managedSection + (Get-ConfigTextSectionTrailingLineEndingText -Text $currentBlockText)

		# Report no update when the managed block already matches exactly.
		if ($replacementBlockText -ceq $currentBlockText) {
			return [pscustomobject]@{
				Content = $Content
				Updated = $false
			}
		}

		# Splice the replacement into the original content using recorded indexes.
		$newContent = $Content.Substring(0, $block.StartIndex) + $replacementBlockText + $Content.Substring($block.EndIndex)

		return [pscustomobject]@{
			Content = $newContent
			Updated = ($newContent -cne $Content)
		}
	}

	# Append a new managed block when no existing block with this name exists.
	$newContent = Add-ConfigTextSectionSeparator -Content $Content -LineEnding $LineEnding
	$newContent += $managedSection

	# End newly written files with the selected line ending.
	if (-not $newContent.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$newContent += $LineEnding
	}

	return [pscustomobject]@{
		Content = $newContent
		Updated = $true
	}
}

function Invoke-ConfigTextSection {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings
	)

	# Require a target path before resolving any other configured behavior.
	if ($null -eq $Settings -or -not $Settings.ContainsKey('path')) {
		throw "The 'path' setting is required."
	}

	# Resolve display paths from the convention settings.
	$targetPath = Get-RepositoryPath -PathSetting $Settings.path
	$targetDisplayPath = Format-RepositoryRelativePath -Path $targetPath
	$configuredSection = Get-ConfigTextSection -Settings $Settings

	# Managed sections can update files, but not directory paths.
	if (Test-Path -LiteralPath $targetPath -PathType Container) {
		throw "The target path '$targetDisplayPath' is a directory."
	}

	# Read existing content and reuse its line ending where possible.
	$existingContent = ''
	$lineEnding = "`n"

	if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
		$existingContent = [System.IO.File]::ReadAllText($targetPath)
		$lineEnding = Get-LineEnding -Content $existingContent
	}

	# Compute the desired target content before touching the file system.
	$sectionResult = Set-ConfigTextSectionText -Content $existingContent -Section $configuredSection -LineEnding $lineEnding -TargetPath $targetPath
	$newContent = $sectionResult.Content

	# Avoid rewriting files that already contain the desired managed section.
	if ($newContent -ceq $existingContent) {
		return
	}

	$targetDirectory = [System.IO.Path]::GetDirectoryName($targetPath)

	# Create the target directory just before the first write.
	if (-not [string]::IsNullOrEmpty($targetDirectory)) {
		[System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
	}

	[System.IO.File]::WriteAllText($targetPath, $newContent, $utf8)

	Write-Host "Updated '$($configuredSection.Name)' section in '$targetDisplayPath'."
}

Export-ModuleMember -Function @(
	'Get-ConfigTextSectionLineRecords'
	'Get-ConfigTextSectionName'
	'Get-ConfigTextSectionRecords'
	'Get-ConfigTextSectionText'
	'Invoke-ConfigTextSection'
)

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load shared repository helpers used by cleanup.
$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath
$configTextSectionPath = Join-Path $PSScriptRoot '..' 'scripts' 'ConfigTextSection.psm1'
Import-Module $configTextSectionPath

function GetEditorConfigLineObjects {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	# Convert shared line records into mutable objects that preserve original endings.
	$lines = [System.Collections.Generic.List[object]]::new()

	foreach ($lineRecord in Get-ConfigTextSectionLineRecords -Content $Content) {
		$lineText = $lineRecord.Text
		$fullText = $Content.Substring($lineRecord.StartIndex, $lineRecord.EndIndex - $lineRecord.StartIndex)
		$lineEnding = $fullText.Substring($lineText.Length)

		$lines.Add([pscustomobject]@{
			Text = $lineText
			Ending = $lineEnding
			Remove = $false
			IsManaged = $false
			IsSectionHeader = $false
			SectionHeader = $null
			Key = $null
			Value = $null
		})
	}

	return $lines
}

function TestEditorConfigCommentOrBlankLine {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

	# Treat blank lines and full-line comments as non-semantic section content.
	$trimmed = $Text.Trim()
	return $trimmed.Length -eq 0 -or $trimmed.StartsWith('#', [System.StringComparison]::Ordinal) -or $trimmed.StartsWith(';', [System.StringComparison]::Ordinal)
}

function SetEditorConfigLineMetadata {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines
	)

	# Track managed blocks and the active unmanaged section while scanning lines.
	$inManagedBlock = $false
	$currentSectionHeader = $null

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
			$currentSectionHeader = $null
			continue
		}

		$trimmed = $line.Text.Trim()

		if ($trimmed -match '^\[[^\]]+\]$') {
			$currentSectionHeader = $trimmed
			$line.IsSectionHeader = $true
			$line.SectionHeader = $currentSectionHeader
			continue
		}

		$line.SectionHeader = $currentSectionHeader

		if (TestEditorConfigCommentOrBlankLine -Text $line.Text) {
			continue
		}

		if ($line.Text -match '^\s*(?<Key>[^#;=\s][^=]*?)\s*=\s*(?<Value>.*?)\s*$') {
			$line.Key = $Matches.Key.Trim()
			$line.Value = $Matches.Value.Trim()
		}
	}
}

function GetManagedEditorConfigRules {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

	# Parse configured managed text into exact section/property/value entries.
	$rules = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
	$lines = @(GetEditorConfigLineObjects -Content $Text)
	SetEditorConfigLineMetadata -Lines $lines

	foreach ($line in $lines) {
		if ($null -eq $line.SectionHeader -or $null -eq $line.Key) {
			continue
		}

		if (-not $rules.ContainsKey($line.SectionHeader)) {
			$rules[$line.SectionHeader] = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
		}

		$sectionRules = $rules[$line.SectionHeader]

		if (-not $sectionRules.ContainsKey($line.Key)) {
			$sectionRules[$line.Key] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
		}

		$valueSet = $sectionRules[$line.Key]
		$valueSet.Add($line.Value) | Out-Null
	}

	return $rules
}

function TestManagedEditorConfigTextIsRoot {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

	# Detect whether this managed text owns the top-level editorconfig root declaration.
	$lines = @(GetEditorConfigLineObjects -Content $Text)
	SetEditorConfigLineMetadata -Lines $lines

	foreach ($line in $lines) {
		if ($null -eq $line.SectionHeader -and $line.Key -eq 'root' -and $line.Value -eq 'true') {
			return $true
		}
	}

	return $false
}

function GetEditorConfigRemoveRootRuleNames {
	param(
		[AllowNull()]
		[object] $RemoveRootRulesSetting
	)

	# Default to no root rule cleanup unless the convention opts into specific rules.
	$ruleNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

	if ($null -eq $RemoveRootRulesSetting) {
		return ,$ruleNames
	}

	if ($RemoveRootRulesSetting -is [string] -or $RemoveRootRulesSetting -isnot [System.Collections.IEnumerable]) {
		throw "The 'remove-root-rules' setting must be an array of non-empty strings."
	}

	# Validate every configured rule name before using it for cleanup.
	foreach ($ruleName in $RemoveRootRulesSetting) {
		if ($ruleName -isnot [string] -or [string]::IsNullOrWhiteSpace($ruleName)) {
			throw "The 'remove-root-rules' setting must be an array of non-empty strings."
		}

		if ($ruleName.Contains("`r") -or $ruleName.Contains("`n")) {
			throw "The 'remove-root-rules' setting must contain only single-line strings."
		}

		$ruleNames.Add($ruleName.Trim()) | Out-Null
	}

	return ,$ruleNames
}

function GetEditorConfigSectionKey {
	param(
		[Parameter(Mandatory = $true)]
		[string] $SectionHeader
	)

	# Extract the section key from a normalized editorconfig section header.
	$trimmed = $SectionHeader.Trim()

	if ($trimmed -notmatch '^\[(?<Key>[^\]]+)\]$') {
		return $null
	}

	return $Matches.Key
}

function ExpandEditorConfigSectionKey {
	param(
		[Parameter(Mandatory = $true)]
		[string] $SectionKey
	)

	# Expand only simple finite brace alternatives that can be proven by exact string comparison.
	$alternatives = [System.Collections.Generic.List[string]]::new()
	$alternatives.Add('') | Out-Null
	$position = 0

	while ($position -lt $SectionKey.Length) {
		$braceStart = $SectionKey.IndexOf('{', $position)

		if ($braceStart -lt 0) {
			$literal = $SectionKey.Substring($position)

			if ($literal.Contains('}')) {
				return [pscustomobject]@{
					Supported = $false
					Alternatives = @()
				}
			}

			for ($alternativeIndex = 0; $alternativeIndex -lt $alternatives.Count; $alternativeIndex++) {
				$alternatives[$alternativeIndex] = $alternatives[$alternativeIndex] + $literal
			}

			return [pscustomobject]@{
				Supported = $true
				Alternatives = $alternatives.ToArray()
			}
		}

		# Reject unmatched or nested braces instead of guessing about editorconfig glob semantics.
		$literal = $SectionKey.Substring($position, $braceStart - $position)

		if ($literal.Contains('}')) {
			return [pscustomobject]@{
				Supported = $false
				Alternatives = @()
			}
		}

		$braceEnd = $SectionKey.IndexOf('}', $braceStart + 1)

		if ($braceEnd -lt 0) {
			return [pscustomobject]@{
				Supported = $false
				Alternatives = @()
			}
		}

		$braceText = $SectionKey.Substring($braceStart + 1, $braceEnd - $braceStart - 1)

		if ($braceText.Contains('{') -or $braceText.Contains('}')) {
			return [pscustomobject]@{
				Supported = $false
				Alternatives = @()
			}
		}

		$braceAlternatives = $braceText.Split(',')

		if ($braceAlternatives.Count -lt 2) {
			return [pscustomobject]@{
				Supported = $false
				Alternatives = @()
			}
		}

		foreach ($braceAlternative in $braceAlternatives) {
			if ([string]::IsNullOrEmpty($braceAlternative)) {
				return [pscustomobject]@{
					Supported = $false
					Alternatives = @()
				}
			}
		}

		# Append the literal and every brace option to produce the next finite alternative set.
		$expandedAlternatives = [System.Collections.Generic.List[string]]::new()

		foreach ($alternative in $alternatives) {
			foreach ($braceAlternative in $braceAlternatives) {
				$expandedAlternatives.Add($alternative + $literal + $braceAlternative) | Out-Null
			}
		}

		if ($expandedAlternatives.Count -gt 256) {
			return [pscustomobject]@{
				Supported = $false
				Alternatives = @()
			}
		}

		$alternatives = $expandedAlternatives
		$position = $braceEnd + 1
	}

	return [pscustomobject]@{
		Supported = $true
		Alternatives = $alternatives.ToArray()
	}
}

function TestEditorConfigSectionKeyCovered {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ManagedSectionKey,

		[Parameter(Mandatory = $true)]
		[string] $UnmanagedSectionKey
	)

	# Preserve exact-match behavior even for section keys that the subset logic does not expand.
	if ($ManagedSectionKey -eq $UnmanagedSectionKey) {
		return $true
	}

	$managedExpansion = ExpandEditorConfigSectionKey -SectionKey $ManagedSectionKey
	$unmanagedExpansion = ExpandEditorConfigSectionKey -SectionKey $UnmanagedSectionKey

	if (-not $managedExpansion.Supported -or -not $unmanagedExpansion.Supported) {
		return $false
	}

	# Treat the unmanaged key as covered only when every finite alternative is explicitly managed.
	$managedAlternatives = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

	foreach ($managedAlternative in $managedExpansion.Alternatives) {
		$managedAlternatives.Add($managedAlternative) | Out-Null
	}

	foreach ($unmanagedAlternative in $unmanagedExpansion.Alternatives) {
		if (-not $managedAlternatives.Contains($unmanagedAlternative)) {
			return $false
		}
	}

	return $true
}

function TestEditorConfigSectionHeaderCovered {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ManagedSectionHeader,

		[Parameter(Mandatory = $true)]
		[string] $UnmanagedSectionHeader
	)

	# Compare section keys after removing the editorconfig header brackets.
	$managedSectionKey = GetEditorConfigSectionKey -SectionHeader $ManagedSectionHeader
	$unmanagedSectionKey = GetEditorConfigSectionKey -SectionHeader $UnmanagedSectionHeader

	if ($null -eq $managedSectionKey -or $null -eq $unmanagedSectionKey) {
		return $false
	}

	return TestEditorConfigSectionKeyCovered -ManagedSectionKey $managedSectionKey -UnmanagedSectionKey $unmanagedSectionKey
}

function SetRedundantEditorConfigRuleRemoval {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines,

		[Parameter(Mandatory = $true)]
		[System.Collections.Generic.Dictionary[string, object]] $ManagedRules,

		[Parameter(Mandatory = $true)]
		[bool] $IsRoot,

		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[System.Collections.Generic.HashSet[string]] $RemoveRootRuleNames
	)

	# Remove unmanaged rules that are either redundant or explicitly delegated to the managed root section.
	$changed = $false

	foreach ($line in $Lines) {
		if ($line.IsManaged -or $null -eq $line.Key) {
			continue
		}

		$removeLine = $false

		if ($IsRoot -and $line.Key -eq 'root' -and $line.Value -eq 'true') {
			$removeLine = $true
		}
		elseif ($IsRoot -and $line.SectionHeader -eq '[*]' -and $RemoveRootRuleNames.Contains($line.Key)) {
			$removeLine = $true
		}
		elseif ($null -ne $line.SectionHeader) {
			foreach ($managedSectionHeader in $ManagedRules.Keys) {
				if (-not (TestEditorConfigSectionHeaderCovered -ManagedSectionHeader $managedSectionHeader -UnmanagedSectionHeader $line.SectionHeader)) {
					continue
				}

				$sectionRules = $ManagedRules[$managedSectionHeader]

				if ($sectionRules.ContainsKey($line.Key) -and $sectionRules[$line.Key].Contains($line.Value)) {
					$removeLine = $true
					break
				}
			}
		}

		if ($removeLine) {
			$line.Remove = $true
			$changed = $true
		}
	}

	return $changed
}

function SetRootEditorConfigLegacyMarkerRemoval {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines,

		[Parameter(Mandatory = $true)]
		[bool] $IsRoot
	)

	# Remove stale template-management marker comments that the root convention replaces.
	if (-not $IsRoot) {
		return $false
	}

	$changed = $false

	foreach ($line in $Lines) {
		if ($line.IsManaged) {
			continue
		}

		if ($line.Text.StartsWith('# DO NOT EDIT', [System.StringComparison]::Ordinal) -or $line.Text.StartsWith('# template-source:', [System.StringComparison]::Ordinal)) {
			$line.Remove = $true
			$changed = $true
		}
	}

	return $changed
}

function SetUnmanagedEditorConfigBlankLineCleanup {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines
	)

	# Collapse repeated blank lines outside managed blocks after cleanup removes unmanaged content.
	$changed = $false
	$previousUnmanagedBlankLine = $false

	foreach ($line in $Lines) {
		if ($line.Remove) {
			continue
		}

		if ($line.IsManaged) {
			$previousUnmanagedBlankLine = $false
			continue
		}

		if ($line.Text.Trim().Length -eq 0) {
			if ($previousUnmanagedBlankLine) {
				$line.Remove = $true
				$changed = $true
				continue
			}

			$previousUnmanagedBlankLine = $true
			continue
		}

		$previousUnmanagedBlankLine = $false
	}

	# Remove blank-only tails so deleted final content does not leave a blank line at EOF.
	for ($index = $Lines.Count - 1; $index -ge 0; $index--) {
		$line = $Lines[$index]

		if ($line.Remove) {
			continue
		}

		if ($line.IsManaged -or $line.Text.Trim().Length -ne 0) {
			break
		}

		$line.Remove = $true
		$changed = $true
	}

	return $changed
}

function SetEmptyEditorConfigSectionRemoval {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines
	)

	# Remove unmanaged sections that became comment-only or blank after rule cleanup.
	$changed = $false
	$index = 0

	while ($index -lt $Lines.Count) {
		$line = $Lines[$index]

		if ($line.IsManaged -or -not $line.IsSectionHeader) {
			$index++
			continue
		}

		$startIndex = $index
		$endIndex = $index + 1

		while ($endIndex -lt $Lines.Count -and -not $Lines[$endIndex].IsManaged -and -not $Lines[$endIndex].IsSectionHeader) {
			$endIndex++
		}

		$hadRemovedRule = $false
		$hasRemainingContent = $false

		for ($sectionIndex = $startIndex + 1; $sectionIndex -lt $endIndex; $sectionIndex++) {
			$sectionLine = $Lines[$sectionIndex]

			if ($sectionLine.Remove) {
				$hadRemovedRule = $true
				continue
			}

			if (-not (TestEditorConfigCommentOrBlankLine -Text $sectionLine.Text)) {
				$hasRemainingContent = $true
			}
		}

		if ($hadRemovedRule -and -not $hasRemainingContent) {
			for ($sectionIndex = $startIndex; $sectionIndex -lt $endIndex; $sectionIndex++) {
				$Lines[$sectionIndex].Remove = $true
			}

			# Remove separators that would otherwise become trailing blank lines.
			if ($endIndex -eq $Lines.Count) {
				$previousIndex = $startIndex - 1

				while ($previousIndex -ge 0 -and -not $Lines[$previousIndex].IsManaged -and $Lines[$previousIndex].Text.Trim().Length -eq 0) {
					$Lines[$previousIndex].Remove = $true
					$previousIndex--
				}
			}

			$changed = $true
		}

		$index = $endIndex
	}

	return $changed
}

function JoinEditorConfigLines {
	param(
		[Parameter(Mandatory = $true)]
		[object[]] $Lines
	)

	# Rebuild text from every line that cleanup did not mark for removal.
	$builder = [System.Text.StringBuilder]::new()

	foreach ($line in $Lines) {
		if (-not $line.Remove) {
			$builder.Append($line.Text) | Out-Null
			$builder.Append($line.Ending) | Out-Null
		}
	}

	return $builder.ToString()
}

function RemoveLeadingBlankEditorConfigLines {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	# Drop blank lines that would otherwise separate a moved root block from content.
	$lines = @(GetEditorConfigLineObjects -Content $Content)
	$builder = [System.Text.StringBuilder]::new()
	$skippingLeadingBlankLines = $true

	foreach ($line in $lines) {
		if ($skippingLeadingBlankLines -and $line.Text.Trim().Length -eq 0) {
			continue
		}

		$skippingLeadingBlankLines = $false
		$builder.Append($line.Text) | Out-Null
		$builder.Append($line.Ending) | Out-Null
	}

	return $builder.ToString()
}

function MoveRootEditorConfigBlockFirst {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding,

		[Parameter(Mandatory = $true)]
		[string] $TargetPath
	)

	# Find the managed block that contains the root declaration.
	$blocks = @(Get-ConfigTextSectionRecords -Content $Content -CommentPrefix '#' -CommentSuffix '' -TargetPath $TargetPath)
	$rootBlocks = @($blocks | Where-Object { $_.Name -eq $Name })

	if ($rootBlocks.Count -ne 1 -or $rootBlocks[0].StartIndex -eq 0) {
		return $Content
	}

	# Splice the root block to the beginning with one blank line before remaining content.
	$rootBlock = $rootBlocks[0]
	$rootBlockText = $Content.Substring($rootBlock.StartIndex, $rootBlock.EndIndex - $rootBlock.StartIndex)
	$remainingContent = $Content.Substring(0, $rootBlock.StartIndex) + $Content.Substring($rootBlock.EndIndex)
	$remainingContent = RemoveLeadingBlankEditorConfigLines -Content $remainingContent

	if ([string]::IsNullOrEmpty($remainingContent)) {
		return $rootBlockText
	}

	if ($rootBlockText.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		return $rootBlockText + $LineEnding + $remainingContent
	}

	return $rootBlockText + $LineEnding + $LineEnding + $remainingContent
}

function InvokeEditorConfigSectionCleanup {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings,

		[Parameter(Mandatory = $true)]
		[bool] $RemoveRedundantRules
	)

	# Normalize the settings already consumed by the managed section writer.
	$name = Get-ConfigTextSectionName -NameSetting $Settings.name
	$text = Get-ConfigTextSectionText -TextSetting $Settings.text -CommentPrefix '#' -CommentSuffix ''
	$isRoot = TestManagedEditorConfigTextIsRoot -Text $text
	$removeRootRuleNames = GetEditorConfigRemoveRootRuleNames -RemoveRootRulesSetting $Settings['remove-root-rules']
	$editorConfigPath = Get-RepositoryPath -PathSetting '.editorconfig'
	$editorConfigDisplayPath = Format-RepositoryRelativePath -Path $editorConfigPath

	# Skip cleanup when there is no editorconfig file to inspect.
	if (-not (Test-Path -LiteralPath $editorConfigPath -PathType Leaf)) {
		return
	}

	# Parse the current file and mark deterministic cleanup edits.
	$content = [System.IO.File]::ReadAllText($editorConfigPath)
	$lineEnding = Get-LineEnding -Content $content
	$managedRules = GetManagedEditorConfigRules -Text $text
	$lines = @(GetEditorConfigLineObjects -Content $content)
	SetEditorConfigLineMetadata -Lines $lines
	$changed = $false
	$deletedUnmanagedLines = $false

	# Delete redundant unmanaged rules only after this apply changed the managed section.
	if ($RemoveRedundantRules) {
		$removedRedundantRules = SetRedundantEditorConfigRuleRemoval -Lines $lines -ManagedRules $managedRules -IsRoot $isRoot -RemoveRootRuleNames $removeRootRuleNames
		$changed = $removedRedundantRules -or $changed
		$deletedUnmanagedLines = $removedRedundantRules -or $deletedUnmanagedLines
	}

	# Delete root-level legacy template markers whenever the root convention runs.
	$removedLegacyMarkers = SetRootEditorConfigLegacyMarkerRemoval -Lines $lines -IsRoot $isRoot
	$changed = $removedLegacyMarkers -or $changed
	$deletedUnmanagedLines = $removedLegacyMarkers -or $deletedUnmanagedLines

	# Remove unmanaged sections that became empty because cleanup deleted their rules.
	$removedEmptySections = SetEmptyEditorConfigSectionRemoval -Lines $lines
	$changed = $removedEmptySections -or $changed
	$deletedUnmanagedLines = $removedEmptySections -or $deletedUnmanagedLines
	$newContent = JoinEditorConfigLines -Lines $lines

	# Keep the root managed section before other editorconfig sections.
	if ($isRoot) {
		$movedContent = MoveRootEditorConfigBlockFirst -Content $newContent -Name $name -LineEnding $lineEnding -TargetPath $editorConfigPath
		$changed = ($movedContent -cne $newContent) -or $changed
		$newContent = $movedContent
	}

	# Normalize blank lines after all removals and root block movement have settled.
	if ($deletedUnmanagedLines) {
		$blankLines = @(GetEditorConfigLineObjects -Content $newContent)
		SetEditorConfigLineMetadata -Lines $blankLines
		$cleanedBlankLines = SetUnmanagedEditorConfigBlankLineCleanup -Lines $blankLines
		$changed = $cleanedBlankLines -or $changed

		if ($cleanedBlankLines) {
			$newContent = JoinEditorConfigLines -Lines $blankLines
		}
	}

	# Write only when cleanup changed the editorconfig text.
	if ($changed -and $newContent -cne $content) {
		[System.IO.File]::WriteAllText($editorConfigPath, $newContent, $utf8)
		Write-Host "Cleaned redundant rules in '$editorConfigDisplayPath'."
	}
}

# Write the managed .editorconfig section using the shared section writer.
$settings = Read-ConventionSettings -InputPath $args[0]
$sectionSettings = @{
	path = '.editorconfig'
	name = $settings.name
	text = $settings.text
	'comment-prefix' = '#'
	'comment-suffix' = ''
}
$sectionResult = Invoke-ConfigTextSection -Settings $sectionSettings -PassThru

# Clean up unmanaged .editorconfig lines after the managed section writer has run.
InvokeEditorConfigSectionCleanup -Settings $settings -RemoveRedundantRules $sectionResult.Updated

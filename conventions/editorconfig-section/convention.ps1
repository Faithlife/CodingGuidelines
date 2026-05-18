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
		elseif ($null -ne $line.SectionHeader -and $ManagedRules.ContainsKey($line.SectionHeader)) {
			$sectionRules = $ManagedRules[$line.SectionHeader]

			if ($sectionRules.ContainsKey($line.Key) -and $sectionRules[$line.Key].Contains($line.Value)) {
				$removeLine = $true
			}
		}

		if ($removeLine) {
			$line.Remove = $true
			$changed = $true
		}
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
		[System.Collections.IDictionary] $Settings
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
	$changed = SetRedundantEditorConfigRuleRemoval -Lines $lines -ManagedRules $managedRules -IsRoot $isRoot -RemoveRootRuleNames $removeRootRuleNames
	$changed = (SetEmptyEditorConfigSectionRemoval -Lines $lines) -or $changed
	$newContent = JoinEditorConfigLines -Lines $lines

	# Keep the root managed section before other editorconfig sections.
	if ($isRoot) {
		$movedContent = MoveRootEditorConfigBlockFirst -Content $newContent -Name $name -LineEnding $lineEnding -TargetPath $editorConfigPath
		$changed = ($movedContent -cne $newContent) -or $changed
		$newContent = $movedContent
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
Invoke-ConfigTextSection -Settings $sectionSettings

# Clean up unmanaged .editorconfig rules after the managed section is written.
InvokeEditorConfigSectionCleanup -Settings $settings

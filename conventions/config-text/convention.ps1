#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

function GetConfiguredLines {
	param(
		[Parameter(Mandatory = $true)]
		[object] $LinesSetting
	)

	if ($LinesSetting -is [string]) {
		throw "The 'lines' setting must be an array of strings."
	}

	if ($LinesSetting -isnot [System.Collections.IEnumerable]) {
		throw "The 'lines' setting must be an array of strings."
	}

	$lines = [System.Collections.Generic.List[string]]::new()

	foreach ($line in $LinesSetting) {
		if ($line -isnot [string]) {
			throw "Each line in 'lines' must be a string."
		}

		if ($line.Contains("`r") -or $line.Contains("`n")) {
			throw "Each line in 'lines' must be a single line."
		}

		$lines.Add($line)
	}

	return (, $lines)
}

function GetConfiguredNewFileText {
	param(
		[Parameter(Mandatory = $true)]
		[object] $NewFileTextSetting
	)

	if ($NewFileTextSetting -isnot [string]) {
		throw "The 'new-file-text' setting must be a string."
	}

	return $NewFileTextSetting
}

function GetConfiguredAgentInstructions {
	param(
		[AllowNull()]
		[object] $InstructionsSetting
	)

	if ($null -eq $InstructionsSetting) {
		return $null
	}

	if ($InstructionsSetting -isnot [string]) {
		throw "The 'agent.instructions' setting must be a string."
	}

	if ([string]::IsNullOrWhiteSpace($InstructionsSetting)) {
		return $null
	}

	return $InstructionsSetting
}

function GetConfiguredAgent {
	param(
		[Parameter(Mandatory = $true)]
		[object] $AgentSetting
	)

	if ($AgentSetting -isnot [System.Collections.IDictionary]) {
		throw "The 'agent' setting must be an object."
	}

	$instructions = if ($AgentSetting.Contains('instructions')) { GetConfiguredAgentInstructions -InstructionsSetting $AgentSetting.instructions } else { $null }

	return [pscustomobject]@{
		Instructions = $instructions
	}
}

function GetConfiguredCommitMessage {
	param(
		[AllowNull()]
		[object] $MessageSetting
	)

	if ($null -eq $MessageSetting) {
		return $null
	}

	if ($MessageSetting -isnot [string]) {
		throw "The 'commit.message' setting must be a string."
	}

	if ([string]::IsNullOrWhiteSpace($MessageSetting)) {
		return $null
	}

	return $MessageSetting
}

function GetConfiguredCommit {
	param(
		[Parameter(Mandatory = $true)]
		[object] $CommitSetting
	)

	if ($CommitSetting -isnot [System.Collections.IDictionary]) {
		throw "The 'commit' setting must be an object."
	}

	$message = if ($CommitSetting.Contains('message')) { GetConfiguredCommitMessage -MessageSetting $CommitSetting.message } else { $null }

	return [pscustomobject]@{
		Message = $message
	}
}

function GetConfiguredSectionName {
	param(
		[Parameter(Mandatory = $true)]
		[object] $NameSetting
	)

	if ($NameSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($NameSetting)) {
		throw "The 'section.name' setting must be a non-empty string."
	}

	if ($NameSetting.Contains("`r") -or $NameSetting.Contains("`n")) {
		throw "The 'section.name' setting must be a single line."
	}

	return $NameSetting
}

function GetConfiguredSectionCommentPrefix {
	param(
		[Parameter(Mandatory = $true)]
		[object] $CommentPrefixSetting
	)

	if ($CommentPrefixSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($CommentPrefixSetting)) {
		throw "The 'section.comment-prefix' setting must be a non-empty string."
	}

	if ($CommentPrefixSetting.Contains("`r") -or $CommentPrefixSetting.Contains("`n")) {
		throw "The 'section.comment-prefix' setting must be a single line."
	}

	return $CommentPrefixSetting
}

function GetConfiguredSectionCommentSuffix {
	param(
		[AllowNull()]
		[object] $CommentSuffixSetting
	)

	if ($null -eq $CommentSuffixSetting) {
		return ''
	}

	if ($CommentSuffixSetting -isnot [string]) {
		throw "The 'section.comment-suffix' setting must be a string."
	}

	if ($CommentSuffixSetting.Contains("`r") -or $CommentSuffixSetting.Contains("`n")) {
		throw "The 'section.comment-suffix' setting must be a single line."
	}

	return $CommentSuffixSetting
}

function GetManagedSectionCommentSuffixText {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $CommentSuffix
	)

	if ([string]::IsNullOrEmpty($CommentSuffix)) {
		return ''
	}

	return ' ' + $CommentSuffix.TrimStart()
}

function GetConfiguredSectionText {
	param(
		[Parameter(Mandatory = $true)]
		[object] $TextSetting,

		[Parameter(Mandatory = $true)]
		[string] $CommentPrefix,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $CommentSuffix
	)

	if ($TextSetting -isnot [string]) {
		throw "The 'section.text' setting must be a string."
	}

	$openingPattern = '^' + [System.Text.RegularExpressions.Regex]::Escape($CommentPrefix) + ' DO NOT EDIT: .+ convention' + [System.Text.RegularExpressions.Regex]::Escape($CommentSuffix) + '$'
	$closingLine = "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	$textLines = ($TextSetting -replace "`r`n", "`n" -replace "`r", "`n") -split "`n", 0, 'SimpleMatch'

	foreach ($line in $textLines) {
		if ($line -eq $closingLine -or $line -match $openingPattern) {
			throw "The 'section.text' setting must not contain managed section marker lines."
		}
	}

	return $TextSetting
}

function GetConfiguredSection {
	param(
		[Parameter(Mandatory = $true)]
		[object] $SectionSetting
	)

	if ($SectionSetting -isnot [System.Collections.IDictionary]) {
		throw "The 'section' setting must be an object."
	}

	if (-not $SectionSetting.Contains('name')) {
		throw "The 'section.name' setting is required."
	}

	if (-not $SectionSetting.Contains('text')) {
		throw "The 'section.text' setting is required."
	}

	if (-not $SectionSetting.Contains('comment-prefix')) {
		throw "The 'section.comment-prefix' setting is required."
	}

	$commentPrefix = GetConfiguredSectionCommentPrefix -CommentPrefixSetting $SectionSetting['comment-prefix']
	$commentSuffix = GetManagedSectionCommentSuffixText -CommentSuffix (GetConfiguredSectionCommentSuffix -CommentSuffixSetting $SectionSetting['comment-suffix'])
	$name = GetConfiguredSectionName -NameSetting $SectionSetting.name
	$text = GetConfiguredSectionText -TextSetting $SectionSetting.text -CommentPrefix $commentPrefix -CommentSuffix $commentSuffix

	return [pscustomobject]@{
		Name = $name
		Text = $text
		CommentPrefix = $commentPrefix
		CommentSuffix = $commentSuffix
	}
}

function GetLineRecords {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	$lineRecords = [System.Collections.Generic.List[object]]::new()
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

		$lineRecords.Add([pscustomobject]@{
			Text = $lineText
			StartIndex = $lineStart
			EndIndex = $position
		})
	}

	return $lineRecords.ToArray()
}

function GetManagedSectionRecords {
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

	$openingPattern = '^' + [System.Text.RegularExpressions.Regex]::Escape($CommentPrefix) + ' DO NOT EDIT: (?<Name>.+) convention' + [System.Text.RegularExpressions.Regex]::Escape($CommentSuffix) + '$'
	$closingLine = "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	$blocks = [System.Collections.Generic.List[object]]::new()
	$currentBlock = $null

	foreach ($line in GetLineRecords -Content $Content) {
		if ($null -ne $currentBlock) {
			if ($line.Text -match $openingPattern) {
				throw "Found an unterminated managed section before '$($line.Text)' in '$TargetPath'."
			}

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

		if ($line.Text -eq $closingLine) {
			throw "Found an unexpected '$closingLine' marker in '$TargetPath'."
		}

		$match = [System.Text.RegularExpressions.Regex]::Match($line.Text, $openingPattern)

		if ($match.Success) {
			$currentBlock = [pscustomobject]@{
				Name = $match.Groups['Name'].Value
				StartIndex = $line.StartIndex
			}
		}
	}

	if ($null -ne $currentBlock) {
		throw "Found an unterminated managed section for '$($currentBlock.Name)' in '$TargetPath'."
	}

	return $blocks.ToArray()
}

function ConvertToTargetLineEndings {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	return ($Text -replace "`r`n", "`n" -replace "`r", "`n").Replace("`n", $LineEnding)
}

function GetTrailingLineEndingText {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text
	)

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

function NewManagedSectionText {
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

	$normalizedText = ConvertToTargetLineEndings -Text $Text -LineEnding $LineEnding
	$blockText = "$CommentPrefix DO NOT EDIT: $Name convention$CommentSuffix$LineEnding$normalizedText"

	if (-not $normalizedText.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$blockText += $LineEnding
	}

	$blockText += "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	return $blockText
}

function AddManagedSectionSeparator {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	if ([string]::IsNullOrEmpty($Content)) {
		return $Content
	}

	if ($Content.EndsWith($LineEnding + $LineEnding, [System.StringComparison]::Ordinal)) {
		return $Content
	}

	if ($Content.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		return $Content + $LineEnding
	}

	return $Content + $LineEnding + $LineEnding
}

function AddConfiguredLinesText {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content,

		[Parameter(Mandatory = $true)]
		[System.Collections.Generic.List[string]] $ConfiguredLines,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	if ($ConfiguredLines.Count -eq 0) {
		return [pscustomobject]@{
			Content = $Content
			AddedCount = 0
		}
	}

	$existingLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

	if ($Content.Length -gt 0) {
		foreach ($line in GetLineRecords -Content $Content) {
			$null = $existingLines.Add($line.Text)
		}
	}

	$seenLines = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

	foreach ($existingLine in $existingLines) {
		$null = $seenLines.Add($existingLine)
	}

	$linesToAdd = [System.Collections.Generic.List[string]]::new()

	foreach ($line in $ConfiguredLines) {
		if ($seenLines.Add($line)) {
			$linesToAdd.Add($line)
		}
	}

	if ($linesToAdd.Count -eq 0) {
		return [pscustomobject]@{
			Content = $Content
			AddedCount = 0
		}
	}

	$prefix = ''

	if ($Content.Length -gt 0 -and -not ($Content.EndsWith("`r`n", [System.StringComparison]::Ordinal) -or $Content.EndsWith("`n", [System.StringComparison]::Ordinal))) {
		$prefix = $LineEnding
	}

	return [pscustomobject]@{
		Content = $Content + $prefix + ($linesToAdd -join $LineEnding) + $LineEnding
		AddedCount = $linesToAdd.Count
	}
}

function SetManagedSectionText {
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

	$managedSection = NewManagedSectionText -Name $Section.Name -Text $Section.Text -CommentPrefix $Section.CommentPrefix -CommentSuffix $Section.CommentSuffix -LineEnding $LineEnding
	$blocks = GetManagedSectionRecords -Content $Content -CommentPrefix $Section.CommentPrefix -CommentSuffix $Section.CommentSuffix -TargetPath $TargetPath
	$namedBlocks = @($blocks | Where-Object { $_.Name -eq $Section.Name })

	if ($namedBlocks.Count -gt 1) {
		throw "Found multiple managed sections named '$($Section.Name)' in '$TargetPath'."
	}

	if ($namedBlocks.Count -eq 1) {
		$block = $namedBlocks[0]
		$currentBlockText = $Content.Substring($block.StartIndex, $block.EndIndex - $block.StartIndex)
		$replacementBlockText = $managedSection + (GetTrailingLineEndingText -Text $currentBlockText)

		if ($replacementBlockText -ceq $currentBlockText) {
			return [pscustomobject]@{
				Content = $Content
				Updated = $false
			}
		}

		$newContent = $Content.Substring(0, $block.StartIndex) + $replacementBlockText + $Content.Substring($block.EndIndex)

		return [pscustomobject]@{
			Content = $newContent
			Updated = ($newContent -cne $Content)
		}
	}

	$newContent = AddManagedSectionSeparator -Content $Content -LineEnding $LineEnding
	$newContent += $managedSection

	if (-not $newContent.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$newContent += $LineEnding
	}

	return [pscustomobject]@{
		Content = $newContent
		Updated = $true
	}
}

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

function TestGitHasWorkingTreeChanges {
	[string[]] $statusLines = @(InvokeGit -Arguments @('status', '--short', '--untracked-files=all') -CaptureOutput -FailureMessage 'Failed to inspect git status.')
	return $statusLines.Count -gt 0
}

function NewCommitFromWorkingTreeChanges {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Message
	)

	if (-not (TestGitHasWorkingTreeChanges)) {
		return $false
	}

	InvokeGit -Arguments @('add', '-A') -FailureMessage 'Failed to stage convention changes.'
	InvokeGit -Arguments @('commit', '-m', $Message) -FailureMessage "Failed to create commit '$Message'."
	return $true
}

if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$inputPath = $args[0]
$settings = Read-ConventionSettings -InputPath $inputPath

if ($null -eq $settings -or -not $settings.ContainsKey('path')) {
	throw "The 'path' setting is required."
}

if (-not $settings.ContainsKey('lines') -and -not $settings.ContainsKey('new-file-text') -and -not $settings.ContainsKey('section')) {
	throw "The 'lines' setting, 'new-file-text' setting, or 'section' setting is required."
}

$targetPath = Get-RepositoryPath -PathSetting $settings.path
$configuredLines = [System.Collections.Generic.List[string]]::new()
$configuredNewFileText = if ($settings.ContainsKey('new-file-text')) { GetConfiguredNewFileText -NewFileTextSetting $settings['new-file-text'] } else { $null }
$configuredAgent = if ($settings.ContainsKey('agent')) { GetConfiguredAgent -AgentSetting $settings.agent } else { $null }
$configuredCommit = if ($settings.ContainsKey('commit')) { GetConfiguredCommit -CommitSetting $settings.commit } else { $null }

if ($settings.ContainsKey('lines')) {
	$configuredLines = GetConfiguredLines -LinesSetting $settings.lines
}

$configuredSection = if ($settings.ContainsKey('section')) { GetConfiguredSection -SectionSetting $settings.section } else { $null }

if ($configuredLines.Count -eq 0 -and $null -eq $configuredNewFileText -and $null -eq $configuredSection) {
	Write-Host "No configured lines to add for '$targetPath'."
	return
}

if (Test-Path -LiteralPath $targetPath -PathType Container) {
	throw "The target path '$targetPath' is a directory."
}

$existingContent = ''
$lineEnding = "`n"
$usedNewFileText = $false

if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
	$existingContent = [System.IO.File]::ReadAllText($targetPath)
	$lineEnding = Get-LineEnding -Content $existingContent
}

$newContent = $existingContent

if ($existingContent.Length -eq 0 -and -not (Test-Path -LiteralPath $targetPath -PathType Leaf) -and $null -ne $configuredNewFileText) {
	$newContent = $configuredNewFileText
	$lineEnding = Get-LineEnding -Content $configuredNewFileText
	$usedNewFileText = $true
	}

$addedLineCount = 0

if ($configuredLines.Count -gt 0) {
	$lineResult = AddConfiguredLinesText -Content $newContent -ConfiguredLines $configuredLines -LineEnding $lineEnding
	$newContent = $lineResult.Content
	$addedLineCount = $lineResult.AddedCount
}

if ($null -ne $configuredSection) {
	$sectionResult = SetManagedSectionText -Content $newContent -Section $configuredSection -LineEnding $lineEnding -TargetPath $targetPath
	$newContent = $sectionResult.Content
}

if ($newContent -ceq $existingContent) {
	if ($null -ne $configuredSection -and $configuredLines.Count -gt 0) {
		Write-Host "'$targetPath' already contains all configured lines and the '$($configuredSection.Name)' section."
		return
	}

	if ($null -ne $configuredSection) {
		Write-Host "'$targetPath' already contains the '$($configuredSection.Name)' section."
		return
	}

	if ($null -ne $configuredNewFileText) {
		Write-Host "'$targetPath' already exists."
		return
	}

	Write-Host "'$targetPath' already contains all configured lines."
	return
}

$targetDirectory = [System.IO.Path]::GetDirectoryName($targetPath)

if (-not [string]::IsNullOrEmpty($targetDirectory)) {
	[System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
}

Write-Utf8NoBomFile -Path $targetPath -Content $newContent

if ($null -ne $configuredAgent -and -not [string]::IsNullOrWhiteSpace($configuredAgent.Instructions)) {
	Write-Host "'$targetPath' changed; starting Copilot with configured agent instructions."
	Invoke-CopilotWithIsolatedConfig -Instructions $configuredAgent.Instructions
}

if ($null -ne $configuredCommit -and -not [string]::IsNullOrWhiteSpace($configuredCommit.Message)) {
	if (NewCommitFromWorkingTreeChanges -Message $configuredCommit.Message) {
		Write-Host "Committed convention changes with message '$($configuredCommit.Message)'."
	}
}

if ($null -ne $configuredSection -and ($configuredLines.Count -gt 0 -or $usedNewFileText)) {
	Write-Host "Updated configured text and the '$($configuredSection.Name)' section in '$targetPath'."
	return
}

if ($null -ne $configuredSection) {
	Write-Host "Updated '$($configuredSection.Name)' section in '$targetPath'."
	return
}

if ($usedNewFileText) {
	Write-Host "Initialized '$targetPath'."
	return
	}

Write-Host "Added $addedLineCount lines to '$targetPath'."

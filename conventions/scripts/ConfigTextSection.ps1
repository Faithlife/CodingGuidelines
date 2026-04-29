#requires -PSEdition Core
#requires -Version 7.0

$helpersPath = Join-Path $PSScriptRoot 'Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

function Get-ConfigTextSectionAgentInstructions {
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

function Get-ConfigTextSectionAgent {
	param(
		[Parameter(Mandatory = $true)]
		[object] $AgentSetting
	)

	if ($AgentSetting -isnot [System.Collections.IDictionary]) {
		throw "The 'agent' setting must be an object."
	}

	$instructions = if ($AgentSetting.Contains('instructions')) { Get-ConfigTextSectionAgentInstructions -InstructionsSetting $AgentSetting.instructions } else { $null }

	return [pscustomobject]@{
		Instructions = $instructions
	}
}

function Get-ConfigTextSectionCommitMessage {
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

function Get-ConfigTextSectionCommit {
	param(
		[Parameter(Mandatory = $true)]
		[object] $CommitSetting
	)

	if ($CommitSetting -isnot [System.Collections.IDictionary]) {
		throw "The 'commit' setting must be an object."
	}

	$message = if ($CommitSetting.Contains('message')) { Get-ConfigTextSectionCommitMessage -MessageSetting $CommitSetting.message } else { $null }

	return [pscustomobject]@{
		Message = $message
	}
}

function Get-ConfigTextSectionName {
	param(
		[Parameter(Mandatory = $true)]
		[object] $NameSetting
	)

	if ($NameSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($NameSetting)) {
		throw "The 'name' setting must be a non-empty string."
	}

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

	if ($CommentPrefixSetting -isnot [string] -or [string]::IsNullOrWhiteSpace($CommentPrefixSetting)) {
		throw "The 'comment-prefix' setting must be a non-empty string."
	}

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

	if ($null -eq $CommentSuffixSetting) {
		return ''
	}

	if ($CommentSuffixSetting -isnot [string]) {
		throw "The 'comment-suffix' setting must be a string."
	}

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

	if ([string]::IsNullOrEmpty($CommentSuffix)) {
		return ''
	}

	return ' ' + $CommentSuffix.TrimStart()
}

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

	if ($TextSetting -isnot [string]) {
		throw "The 'text' setting must be a string."
	}

	$openingPattern = '^' + [System.Text.RegularExpressions.Regex]::Escape($CommentPrefix) + ' DO NOT EDIT: .+ convention' + [System.Text.RegularExpressions.Regex]::Escape($CommentSuffix) + '$'
	$closingLine = "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	$textLines = ($TextSetting -replace "`r`n", "`n" -replace "`r", "`n") -split "`n", 0, 'SimpleMatch'

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

	if (-not $Settings.Contains('name')) {
		throw "The 'name' setting is required."
	}

	if (-not $Settings.Contains('text')) {
		throw "The 'text' setting is required."
	}

	if (-not $Settings.Contains('comment-prefix')) {
		throw "The 'comment-prefix' setting is required."
	}

	$commentPrefix = Get-ConfigTextSectionCommentPrefix -CommentPrefixSetting $Settings['comment-prefix']
	$commentSuffix = Get-ConfigTextSectionMarkerCommentSuffixText -CommentSuffix (Get-ConfigTextSectionCommentSuffix -CommentSuffixSetting $Settings['comment-suffix'])
	$name = Get-ConfigTextSectionName -NameSetting $Settings.name
	$text = Get-ConfigTextSectionText -TextSetting $Settings.text -CommentPrefix $commentPrefix -CommentSuffix $commentSuffix

	return [pscustomobject]@{
		Name = $name
		Text = $text
		CommentPrefix = $commentPrefix
		CommentSuffix = $commentSuffix
	}
}

function Get-ConfigTextSectionLineRecords {
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

	$openingPattern = '^' + [System.Text.RegularExpressions.Regex]::Escape($CommentPrefix) + ' DO NOT EDIT: (?<Name>.+) convention' + [System.Text.RegularExpressions.Regex]::Escape($CommentSuffix) + '$'
	$closingLine = "$CommentPrefix END DO NOT EDIT$CommentSuffix"
	$blocks = [System.Collections.Generic.List[object]]::new()
	$currentBlock = $null

	foreach ($line in Get-ConfigTextSectionLineRecords -Content $Content) {
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

function ConvertTo-ConfigTextSectionLineEndings {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	return ($Text -replace "`r`n", "`n" -replace "`r", "`n").Replace("`n", $LineEnding)
}

function Get-ConfigTextSectionTrailingLineEndingText {
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

	$normalizedText = ConvertTo-ConfigTextSectionLineEndings -Text $Text -LineEnding $LineEnding
	$blockText = "$CommentPrefix DO NOT EDIT: $Name convention$CommentSuffix$LineEnding$normalizedText"

	if (-not $normalizedText.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$blockText += $LineEnding
	}

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

	$managedSection = New-ConfigTextSectionText -Name $Section.Name -Text $Section.Text -CommentPrefix $Section.CommentPrefix -CommentSuffix $Section.CommentSuffix -LineEnding $LineEnding
	$blocks = Get-ConfigTextSectionRecords -Content $Content -CommentPrefix $Section.CommentPrefix -CommentSuffix $Section.CommentSuffix -TargetPath $TargetPath
	$namedBlocks = @($blocks | Where-Object { $_.Name -eq $Section.Name })

	if ($namedBlocks.Count -gt 1) {
		throw "Found multiple managed sections named '$($Section.Name)' in '$TargetPath'."
	}

	if ($namedBlocks.Count -eq 1) {
		$block = $namedBlocks[0]
		$currentBlockText = $Content.Substring($block.StartIndex, $block.EndIndex - $block.StartIndex)
		$replacementBlockText = $managedSection + (Get-ConfigTextSectionTrailingLineEndingText -Text $currentBlockText)

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

	$newContent = Add-ConfigTextSectionSeparator -Content $Content -LineEnding $LineEnding
	$newContent += $managedSection

	if (-not $newContent.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$newContent += $LineEnding
	}

	return [pscustomobject]@{
		Content = $newContent
		Updated = $true
	}
}

function Invoke-ConfigTextSectionGit {
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

function Test-ConfigTextSectionGitHasWorkingTreeChanges {
	[string[]] $statusLines = @(Invoke-ConfigTextSectionGit -Arguments @('status', '--short', '--untracked-files=all') -CaptureOutput -FailureMessage 'Failed to inspect git status.')
	return $statusLines.Count -gt 0
}

function Invoke-ConfigTextSectionCommit {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Message
	)

	if (-not (Test-ConfigTextSectionGitHasWorkingTreeChanges)) {
		return $false
	}

	Invoke-ConfigTextSectionGit -Arguments @('add', '-A') -FailureMessage 'Failed to stage convention changes.'
	Invoke-ConfigTextSectionGit -Arguments @('commit', '-m', $Message) -FailureMessage "Failed to create commit '$Message'."
	return $true
}

function Invoke-ConfigTextSection {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary] $Settings
	)

	if ($null -eq $Settings -or -not $Settings.ContainsKey('path')) {
		throw "The 'path' setting is required."
	}

	$targetPath = Get-RepositoryPath -PathSetting $Settings.path
	$targetDisplayPath = Format-RepositoryRelativePath -Path $targetPath
	$configuredAgent = if ($Settings.ContainsKey('agent')) { Get-ConfigTextSectionAgent -AgentSetting $Settings.agent } else { $null }
	$configuredCommit = if ($Settings.ContainsKey('commit')) { Get-ConfigTextSectionCommit -CommitSetting $Settings.commit } else { $null }
	$configuredSection = Get-ConfigTextSection -Settings $Settings

	if (Test-Path -LiteralPath $targetPath -PathType Container) {
		throw "The target path '$targetDisplayPath' is a directory."
	}

	$existingContent = ''
	$lineEnding = "`n"

	if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
		$existingContent = [System.IO.File]::ReadAllText($targetPath)
		$lineEnding = Get-LineEnding -Content $existingContent
	}

	$sectionResult = Set-ConfigTextSectionText -Content $existingContent -Section $configuredSection -LineEnding $lineEnding -TargetPath $targetPath
	$newContent = $sectionResult.Content

	if ($newContent -ceq $existingContent) {
		Write-Host "'$targetDisplayPath' already contains the '$($configuredSection.Name)' section."
		return
	}

	$targetDirectory = [System.IO.Path]::GetDirectoryName($targetPath)

	if (-not [string]::IsNullOrEmpty($targetDirectory)) {
		[System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
	}

	Write-Utf8NoBomFile -Path $targetPath -Content $newContent

	if ($null -ne $configuredAgent -and -not [string]::IsNullOrWhiteSpace($configuredAgent.Instructions)) {
		Write-Host "'$targetDisplayPath' changed; starting Copilot with configured agent instructions."
		Invoke-CopilotWithIsolatedConfig -Instructions $configuredAgent.Instructions

		$copilotContent = ''
		$copilotLineEnding = $lineEnding

		if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
			$copilotContent = [System.IO.File]::ReadAllText($targetPath)
			$copilotLineEnding = Get-LineEnding -Content $copilotContent
		}

		$reconciledSectionResult = Set-ConfigTextSectionText -Content $copilotContent -Section $configuredSection -LineEnding $copilotLineEnding -TargetPath $targetPath

		if ($reconciledSectionResult.Updated) {
			Write-Utf8NoBomFile -Path $targetPath -Content $reconciledSectionResult.Content
		}
	}

	if ($null -ne $configuredCommit -and -not [string]::IsNullOrWhiteSpace($configuredCommit.Message)) {
		if (Invoke-ConfigTextSectionCommit -Message $configuredCommit.Message) {
			Write-Host "Committed convention changes with message '$($configuredCommit.Message)'."
		}
	}

	Write-Host "Updated '$($configuredSection.Name)' section in '$targetDisplayPath'."
}
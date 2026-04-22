Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

function GetConfiguredName {
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

function GetConfiguredText {
	param(
		[Parameter(Mandatory = $true)]
		[object] $TextSetting
	)

	if ($TextSetting -isnot [string]) {
		throw "The 'text' setting must be a string."
	}

	$textLines = ($TextSetting -replace "`r`n", "`n" -replace "`r", "`n") -split "`n", 0, 'SimpleMatch'

	foreach ($line in $textLines) {
		if ($line -eq '# END DO NOT EDIT' -or $line -match '^# DO NOT EDIT: .+ convention$') {
			throw "The 'text' setting must not contain managed block marker lines."
		}
	}

	return $TextSetting
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

function GetManagedBlockRecords {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	$openingPattern = '^# DO NOT EDIT: (?<Name>.+) convention$'
	$blocks = [System.Collections.Generic.List[object]]::new()
	$currentBlock = $null

	foreach ($line in GetLineRecords -Content $Content) {
		if ($null -ne $currentBlock) {
			if ($line.Text -match $openingPattern) {
				throw "Found an unterminated managed block before '$($line.Text)' in '.editorconfig'."
			}

			if ($line.Text -eq '# END DO NOT EDIT') {
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

		if ($line.Text -eq '# END DO NOT EDIT') {
			throw "Found an unexpected '# END DO NOT EDIT' marker in '.editorconfig'."
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
		throw "Found an unterminated managed block for '$($currentBlock.Name)' in '.editorconfig'."
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

function NewManagedBlockText {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Text,

		[Parameter(Mandatory = $true)]
		[string] $LineEnding
	)

	$normalizedText = ConvertToTargetLineEndings -Text $Text -LineEnding $LineEnding
	$blockText = "# DO NOT EDIT: $Name convention$LineEnding$normalizedText"

	if (-not $normalizedText.EndsWith($LineEnding, [System.StringComparison]::Ordinal)) {
		$blockText += $LineEnding
	}

	$blockText += '# END DO NOT EDIT'
	return $blockText
}

function AddManagedBlockSeparator {
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

if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$settings = Read-ConventionSettings -InputPath $args[0]

if ($null -eq $settings -or -not $settings.ContainsKey('name')) {
	throw "The 'name' setting is required."
}

if (-not $settings.ContainsKey('text')) {
	throw "The 'text' setting is required."
}

$targetPath = Get-RepositoryPath -PathSetting '/.editorconfig'
$name = GetConfiguredName -NameSetting $settings.name
$text = GetConfiguredText -TextSetting $settings.text

$existingContent = ''
$lineEnding = "`n"

if (Test-Path -LiteralPath $targetPath -PathType Container) {
	throw "The target path '$targetPath' is a directory."
}

if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
	$existingContent = [System.IO.File]::ReadAllText($targetPath)
	$lineEnding = Get-LineEnding -Content $existingContent
}

$managedBlock = NewManagedBlockText -Name $name -Text $text -LineEnding $lineEnding
$newContent = $existingContent

if ($existingContent.Length -eq 0 -and -not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
	$newContent = "root = true$lineEnding$lineEnding$managedBlock$lineEnding"
}
else {
	$blocks = GetManagedBlockRecords -Content $existingContent
	$namedBlocks = @($blocks | Where-Object { $_.Name -eq $name })

	if ($namedBlocks.Count -gt 1) {
		throw "Found multiple managed blocks named '$name' in '.editorconfig'."
	}

	if ($namedBlocks.Count -eq 1) {
		$block = $namedBlocks[0]
		$newContent = $existingContent.Substring(0, $block.StartIndex) + $managedBlock + $existingContent.Substring($block.EndIndex)
		if (-not $newContent.EndsWith($lineEnding, [System.StringComparison]::Ordinal)) {
			$newContent += $lineEnding
		}
	}
	else {
		$newContent = AddManagedBlockSeparator -Content $existingContent -LineEnding $lineEnding
		$newContent += $managedBlock
		if (-not $newContent.EndsWith($lineEnding, [System.StringComparison]::Ordinal)) {
			$newContent += $lineEnding
		}
	}
}

if ($newContent -ceq $existingContent) {
	Write-Host "'$targetPath' already contains the '$name' section."
	return
}

Write-Utf8NoBomFile -Path $targetPath -Content $newContent
Write-Host "Updated '$name' section in '$targetPath'."

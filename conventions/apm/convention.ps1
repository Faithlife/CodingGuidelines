#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Collect optional install settings from the convention input.
$packagesToInstall = @()
$shouldUpdate = $false
$installAsDevelopment = $false
$conventionInput = Get-Content -LiteralPath $args[0] -Raw | ConvertFrom-Json -AsHashtable
$settings = $conventionInput.settings

function TestApmManifestHasTargets {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	# Treat only unindented targets entries as the repository-level APM targets declaration.
	if (-not (Test-Path -LiteralPath $Path)) {
		return $false
	}

	# Scan the manifest without otherwise parsing or reformatting YAML content.
	foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
		if ($line -match '^\uFEFF?targets\s*:') {
			return $true
		}
	}

	return $false
}

function EnsureApmManifestTargets {
	# Resolve the manifest path from the target repository root PowerShell location.
	$repositoryRoot = (Get-Location).ProviderPath
	$apmManifestPath = Join-Path $repositoryRoot 'apm.yml'

	# Leave repositories with an existing top-level targets declaration untouched.
	if (TestApmManifestHasTargets -Path $apmManifestPath) {
		return
	}

	# Add the default Copilot target to a new or existing APM manifest.
	$targetText = "targets:`n- copilot`n"
	if (-not (Test-Path -LiteralPath $apmManifestPath)) {
		[System.IO.File]::WriteAllText($apmManifestPath, $targetText, $utf8)
		return
	}

	# Append the targets declaration after any existing manifest content.
	$manifestText = [System.IO.File]::ReadAllText($apmManifestPath)
	$manifestText = $manifestText -replace "(?:\r?\n[ \t]*)+\z", ''
	if ($manifestText.Length -gt 0) {
		$manifestText += "`n"
	}
	$manifestText += $targetText
	[System.IO.File]::WriteAllText($apmManifestPath, $manifestText, $utf8)
}

function RemoveApmManifestAuthor {
	# Resolve the manifest path from the target repository root PowerShell location.
	$repositoryRoot = (Get-Location).ProviderPath
	$apmManifestPath = Join-Path $repositoryRoot 'apm.yml'

	# Remove the generated top-level author entry because it is optional and often inaccurate.
	if (-not (Test-Path -LiteralPath $apmManifestPath)) {
		return
	}
	[string[]] $manifestLines = @([System.IO.File]::ReadAllLines($apmManifestPath))
	[string[]] $filteredLines = @($manifestLines | Where-Object { $_ -notmatch '^\uFEFF?author\s*:' })
	if ($filteredLines.Count -eq $manifestLines.Count) {
		return
	}

	# Write the manifest back only when an author line was removed.
	$manifestText = if ($filteredLines.Count -eq 0) {
		''
	}
	else {
		($filteredLines -join "`n") + "`n"
	}
	[System.IO.File]::WriteAllText($apmManifestPath, $manifestText, $utf8)
}

function GetApmRootDependencySection {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IList] $Lines,

		[Parameter(Mandatory = $true)]
		[string] $Name
	)

	# Find the requested top-level dependency section without parsing unrelated YAML.
	$sectionStart = -1
	$headerValue = ''
	$headerPrefix = ''
	$headerPattern = '^(?:\uFEFF)?' + [regex]::Escape($Name) + '\s*:\s*(?<value>.*)$'

	for ($index = 0; $index -lt $Lines.Count; $index++) {
		$headerMatch = [regex]::Match($Lines[$index], $headerPattern)
		if (-not $headerMatch.Success) {
			continue
		}

		if ($sectionStart -ge 0) {
			throw "The APM manifest has more than one top-level '$Name' section."
		}

		$sectionStart = $index
		$headerValue = $headerMatch.Groups['value'].Value
		$headerPrefix = $Lines[$index].Substring(0, $headerMatch.Groups['value'].Index)
	}

	if ($sectionStart -lt 0) {
		return [pscustomobject]@{
			Found = $false
			Start = -1
			End = -1
			HeaderValue = ''
			HeaderPrefix = ''
			HeaderComment = ''
		}
	}

	# Bound the section at the next top-level mapping key.
	$sectionEnd = $Lines.Count
	for ($index = $sectionStart + 1; $index -lt $Lines.Count; $index++) {
		if ($Lines[$index] -cmatch '^(?:\uFEFF)?[^ \t#][^:]*:\s*(?:.*)$') {
			$sectionEnd = $index
			break
		}
	}

	# Accept the empty mapping forms emitted by APM and preserve any inline comment.
	$commentMatch = [regex]::Match($headerValue, '^(?<comment>#.*)$|(?<spacing>[ \t]+#.*)$')
	$cleanHeaderValue = $headerValue
	$headerComment = ''
	if ($commentMatch.Success) {
		$cleanHeaderValue = $headerValue.Substring(0, $commentMatch.Index).Trim()
		$headerComment = ' ' + $commentMatch.Value.Trim()
	}

	if ($cleanHeaderValue -notin @('', '{}', 'null', '~')) {
		throw "Cannot safely migrate APM packages from the inline '$Name' value. Use a block mapping in apm.yml."
	}

	return [pscustomobject]@{
		Found = $true
		Start = $sectionStart
		End = $sectionEnd
		HeaderValue = $cleanHeaderValue
		HeaderPrefix = $headerPrefix
		HeaderComment = $headerComment
	}
}

function ConvertApmDependencyEntry {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Line,

		[Parameter(Mandatory = $true)]
		[int] $LineIndex
	)

	# Parse one APM package scalar and retain its quoting and comment for migration.
	$itemMatch = [regex]::Match($Line, '^(?<indent>[ \t]*)-(?<spacing>[ \t]*)(?<body>.*)$')
	if (-not $itemMatch.Success) {
		throw "Cannot safely migrate an APM dependency list entry on line $($LineIndex + 1)."
	}

	$body = $itemMatch.Groups['body'].Value.Trim()
	if ([string]::IsNullOrWhiteSpace($body) -or $body.StartsWith('#')) {
		throw "Cannot safely migrate an empty APM dependency list entry on line $($LineIndex + 1)."
	}

	$scalar = ''
	$value = ''
	$comment = ''
	$singleQuotedMatch = [regex]::Match($body, '^(?<scalar>\x27(?:[^\x27]|\x27\x27)*\x27)(?<comment>[ \t]+#.*)?[ \t]*$')
	$doubleQuotedMatch = [regex]::Match($body, '^(?<scalar>"(?:\\.|[^"\\])*")(?<comment>[ \t]+#.*)?[ \t]*$')

	if ($singleQuotedMatch.Success) {
		$scalar = $singleQuotedMatch.Groups['scalar'].Value
		$value = $scalar.Substring(1, $scalar.Length - 2).Replace("''", "'")
		$comment = $singleQuotedMatch.Groups['comment'].Value
	}
	elseif ($doubleQuotedMatch.Success) {
		$scalar = $doubleQuotedMatch.Groups['scalar'].Value
		try {
			$value = ConvertFrom-Json -InputObject $scalar -AsHashtable
		}
		catch {
			throw "Cannot safely parse a quoted APM dependency on line $($LineIndex + 1)."
		}

		if ($value -isnot [string]) {
			throw "Cannot safely parse a quoted APM dependency on line $($LineIndex + 1)."
		}

		$comment = $doubleQuotedMatch.Groups['comment'].Value
	}
	else {
		$commentMatch = [regex]::Match($body, '[ \t]+#')
		if ($commentMatch.Success) {
			$scalar = $body.Substring(0, $commentMatch.Index).TrimEnd()
			$comment = $body.Substring($commentMatch.Index)
		}
		else {
			$scalar = $body
		}

		if ([string]::IsNullOrWhiteSpace($scalar) -or $scalar -match '[ \t]') {
			throw "Cannot safely parse an unquoted APM dependency on line $($LineIndex + 1)."
		}

		$value = $scalar
	}

	return [pscustomobject]@{
		LineIndex = $LineIndex
		Indent = $itemMatch.Groups['indent'].Value
		Value = $value
		Scalar = $scalar
		Comment = $comment
	}
}

function GetApmDependencyList {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IList] $Lines,

		[Parameter(Mandatory = $true)]
		[psobject] $Section,

		[Parameter(Mandatory = $true)]
		[string] $SectionName
	)

	# Return an empty package list when the section has no APM dependency group.
	$dependencyGroups = [System.Collections.Generic.List[object]]::new()
	$defaultIndent = '  '
	for ($index = $Section.Start + 1; $index -lt $Section.End; $index++) {
		$line = $Lines[$index]
		if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
			continue
		}

		if ($line -cmatch '^(?<indent>[ \t]+)\S') {
			$defaultIndent = $Matches['indent']
			break
		}
	}

	$groupPattern = '^(?<prefix>[ \t]+apm\s*:\s*)(?<value>.*)$'
	for ($index = $Section.Start + 1; $index -lt $Section.End; $index++) {
		$groupMatch = [regex]::Match($Lines[$index], $groupPattern)
		if ($groupMatch.Success) {
			$dependencyGroups.Add([pscustomobject]@{
				Index = $index
				Prefix = $groupMatch.Groups['prefix'].Value
				Value = $groupMatch.Groups['value'].Value
			})
		}
	}

	if ($dependencyGroups.Count -gt 1) {
		throw "The APM manifest has more than one 'apm' group in '$SectionName'."
	}

	if ($dependencyGroups.Count -eq 0) {
		return [pscustomobject]@{
			Found = $false
			Index = -1
			End = -1
			Indent = $defaultIndent
			ItemIndent = $defaultIndent
			HeaderPrefix = ''
			HeaderValue = ''
			HeaderComment = ''
			Entries = @()
		}
	}

	# Parse the APM group as the block list format written by APM.
	$group = $dependencyGroups[0]
	$headerCommentMatch = [regex]::Match($group.Value, '^(?<comment>#.*)$|(?<spacing>[ \t]+#.*)$')
	$cleanGroupValue = $group.Value
	$groupComment = ''
	if ($headerCommentMatch.Success) {
		$cleanGroupValue = $group.Value.Substring(0, $headerCommentMatch.Index).Trim()
		$groupComment = ' ' + $headerCommentMatch.Value.Trim()
	}

	if ($cleanGroupValue -notin @('', '[]', 'null', '~')) {
		throw "Cannot safely migrate APM packages from the inline '$SectionName.apm' value. Use a block list in apm.yml."
	}

	$groupIndent = [regex]::Match($group.Prefix, '^[ \t]+').Value
	$entries = [System.Collections.Generic.List[object]]::new()
	$groupEnd = $Section.End
	for ($index = $group.Index + 1; $index -lt $Section.End; $index++) {
		$line = $Lines[$index]
		if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
			continue
		}

		$lineIndent = [regex]::Match($line, '^[ \t]*').Value
		$content = $line.Substring($lineIndent.Length)
		if ($lineIndent.Length -lt $groupIndent.Length -or
			($lineIndent.Length -eq $groupIndent.Length -and $content -notmatch '^-(?:[ \t]|$)')) {
			$groupEnd = $index
			break
		}

		if ($content -notmatch '^-(?:[ \t]|$)') {
			throw "Cannot safely migrate the '$SectionName.apm' dependency group in apm.yml."
		}

		$entries.Add((ConvertApmDependencyEntry -Line $line -LineIndex $index))
	}

	if ($cleanGroupValue -in @('[]', 'null', '~') -and $entries.Count -gt 0) {
		throw "The APM manifest mixes an inline '$SectionName.apm' value with block entries."
	}

	return [pscustomobject]@{
		Found = $true
		Index = $group.Index
		End = $groupEnd
		Indent = $groupIndent
		ItemIndent = if ($entries.Count -gt 0) { $entries[0].Indent } else { $groupIndent }
		HeaderPrefix = $group.Prefix
		HeaderValue = $cleanGroupValue
		HeaderComment = $groupComment
		Entries = @($entries)
	}
}

function GetApmSectionInsertionIndex {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IList] $Lines,

		[Parameter(Mandatory = $true)]
		[psobject] $Section
	)

	# Keep trailing comments and blank lines ahead of the next top-level section.
	$insertionIndex = $Section.End
	while ($insertionIndex -gt $Section.Start + 1) {
		$line = $Lines[$insertionIndex - 1]
		if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
			$insertionIndex--
			continue
		}
		break
	}

	return $insertionIndex
}

function AddApmDevelopmentEntries {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IList] $Lines,

		[Parameter(Mandatory = $true)]
		[object[]] $Entries,

		[Parameter(Mandatory = $true)]
		[psobject] $DevelopmentSection,

		[Parameter(Mandatory = $true)]
		[psobject] $DevelopmentList
	)

	# Create a root development section when none exists.
	if (-not $DevelopmentSection.Found) {
		$developmentLines = [System.Collections.Generic.List[string]]::new()
		$developmentLines.Add('devDependencies:')
		$developmentLines.Add($DevelopmentList.Indent + 'apm:')
		foreach ($entry in $Entries) {
			$developmentLines.Add($DevelopmentList.Indent + '- ' + $entry.Scalar + $entry.Comment)
		}

		$productionSection = GetApmRootDependencySection -Lines $Lines -Name 'dependencies'
		$insertionIndex = GetApmSectionInsertionIndex -Lines $Lines -Section $productionSection
		for ($index = 0; $index -lt $developmentLines.Count; $index++) {
			$Lines.Insert($insertionIndex + $index, $developmentLines[$index])
		}
		return
	}

	# Convert an empty inline map into a block map before adding APM dependencies.
	if ($DevelopmentSection.HeaderValue -in @('{}', 'null', '~')) {
		$Lines[$DevelopmentSection.Start] = $DevelopmentSection.HeaderPrefix.TrimEnd() + $DevelopmentSection.HeaderComment
	}

	# Append to the existing APM list or create its provider group.
	if ($DevelopmentList.Found) {
		$insertAt = if ($DevelopmentList.Entries.Count -gt 0) {
			$DevelopmentList.Entries[-1].LineIndex + 1
		}
		else {
			$DevelopmentList.Index + 1
		}

		if ($DevelopmentList.HeaderValue -in @('[]', 'null', '~')) {
			$Lines[$DevelopmentList.Index] = $DevelopmentList.HeaderPrefix.TrimEnd() + $DevelopmentList.HeaderComment
		}
	}
	else {
		$insertAt = GetApmSectionInsertionIndex -Lines $Lines -Section $DevelopmentSection
		$Lines.Insert($insertAt, $DevelopmentList.Indent + 'apm:')
		$insertAt++
	}

	# Add only references that were absent from the development list.
	for ($index = 0; $index -lt $Entries.Count; $index++) {
		$Lines.Insert($insertAt + $index, $DevelopmentList.ItemIndent + '- ' + $Entries[$index].Scalar + $Entries[$index].Comment)
	}
}

function MoveConfiguredApmPackagesToDevelopment {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ManifestPath,

		[Parameter(Mandatory = $true)]
		[string[]] $Packages
	)

	# Skip manifest migration when no package identifiers were configured.
	if ($Packages.Count -eq 0) {
		return $false
	}

	# Read the manifest and retain its existing newline convention.
	$manifestText = [System.IO.File]::ReadAllText($ManifestPath)
	$newline = if ($manifestText.Contains("`r`n")) {
		"`r`n"
	}
	elseif ($manifestText.Contains("`n")) {
		"`n"
	}
	elseif ($manifestText.Contains("`r")) {
		"`r"
	}
	else {
		"`n"
	}
	$lines = [System.Collections.Generic.List[string]]::new([regex]::Split($manifestText, '\r\n|\n|\r'))

	# Read both dependency scopes before changing either one.
	$productionSection = GetApmRootDependencySection -Lines $lines -Name 'dependencies'
	if (-not $productionSection.Found) {
		return $false
	}
	$productionList = GetApmDependencyList -Lines $lines -Section $productionSection -SectionName 'dependencies'

	# Select only configured APM package identifiers already in production scope.
	$configuredPackages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
	foreach ($package in $Packages) {
		[void] $configuredPackages.Add($package)
	}
	$entriesToMove = @($productionList.Entries | Where-Object { $configuredPackages.Contains($_.Value) })
	if ($entriesToMove.Count -eq 0) {
		return $false
	}

	# Read development dependencies only when a production reference needs migration.
	$developmentSection = GetApmRootDependencySection -Lines $lines -Name 'devDependencies'
	$developmentList = if ($developmentSection.Found) {
		GetApmDependencyList -Lines $lines -Section $developmentSection -SectionName 'devDependencies'
	}
	else {
		[pscustomobject]@{
			Found = $false
			Index = -1
			End = -1
			Indent = '  '
			ItemIndent = '  '
			HeaderPrefix = ''
			HeaderValue = ''
			HeaderComment = ''
			Entries = @()
		}
	}

	# Keep existing development entries and add only missing configured identifiers.
	$developmentPackages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
	foreach ($entry in $developmentList.Entries) {
		[void] $developmentPackages.Add($entry.Value)
	}
	$entriesToAdd = [System.Collections.Generic.List[object]]::new()
	foreach ($entry in $entriesToMove) {
		if ($developmentPackages.Add($entry.Value)) {
			$entriesToAdd.Add($entry)
		}
	}

	# Remove selected entries from the production APM list without touching other kinds.
	for ($index = $entriesToMove.Count - 1; $index -ge 0; $index--) {
		$lines.RemoveAt($entriesToMove[$index].LineIndex)
	}

	# Keep an empty APM dependency group valid when every production reference moved.
	$remainingProductionEntries = @($productionList.Entries | Where-Object { -not $configuredPackages.Contains($_.Value) })
	if ($remainingProductionEntries.Count -eq 0) {
		$lines[$productionList.Index] = $productionList.HeaderPrefix.TrimEnd() + ' []' + $productionList.HeaderComment
	}

	# Add moved references to the development scope only after the production list is valid.
	if ($entriesToAdd.Count -gt 0) {
		$developmentSection = GetApmRootDependencySection -Lines $lines -Name 'devDependencies'
		if ($developmentSection.Found) {
			$developmentList = GetApmDependencyList -Lines $lines -Section $developmentSection -SectionName 'devDependencies'
		}
		AddApmDevelopmentEntries -Lines $lines -Entries $entriesToAdd.ToArray() -DevelopmentSection $developmentSection -DevelopmentList $developmentList
	}

	# Write the complete migration atomically so parse or write failures cannot truncate apm.yml.
	$updatedManifestText = [string]::Join($newline, $lines)
	$temporaryPath = Join-Path ([System.IO.Path]::GetDirectoryName($ManifestPath)) ('.apm-' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
	try {
		[System.IO.File]::WriteAllText($temporaryPath, $updatedManifestText, $utf8)
		[System.IO.File]::Move($temporaryPath, $ManifestPath, $true)
	}
	finally {
		if (Test-Path -LiteralPath $temporaryPath) {
			Remove-Item -LiteralPath $temporaryPath -Force
		}
	}

	Write-Host "Moved $($entriesToMove.Count) configured APM package reference(s) to devDependencies."
	return $true
}

function InvokeApmCommand {
	param(
		[Parameter(Mandatory = $true)]
		[string[]] $Arguments
	)

	# Run apm and fail the convention if the command fails.
	Write-Host ('Running apm ' + ($Arguments -join ' ') + '.')
	& apm @Arguments

	if ($LASTEXITCODE -ne 0) {
		throw ('apm ' + $Arguments[0] + ' failed.')
	}
}

if ($null -ne $settings -and $settings.ContainsKey('install') -and $null -ne $settings.install) {
	[string[]] $packagesToInstall = @($settings.install)
}

if ($null -ne $settings -and $settings.ContainsKey('update') -and $null -ne $settings.update) {
	$shouldUpdate = [bool] $settings.update
}

# Read the optional development setting and reject non-boolean values.
if ($null -ne $settings -and $settings.ContainsKey('dev') -and $null -ne $settings.dev) {
	if ($settings.dev -isnot [bool]) {
		throw "The apm convention setting 'dev' must be a boolean."
	}
	$installAsDevelopment = $settings.dev
}

# Skip when neither an apm manifest nor explicit packages are available.
if ($packagesToInstall.Count -eq 0 -and -not (Test-Path -LiteralPath 'apm.yml')) {
	Write-Host 'Skipping apm because apm.yml is absent and no packages were configured.'
	return
}

# Verify apm is available before invoking it.
Get-Command -Name apm -ErrorAction Stop | Out-Null

# Initialize an APM manifest before installing configured packages into a repository without one.
if ($packagesToInstall.Count -gt 0 -and -not (Test-Path -LiteralPath 'apm.yml')) {
	InvokeApmCommand -Arguments @('init', '--yes')
	RemoveApmManifestAuthor
}

# Ensure apm can resolve the Copilot target from the repository manifest.
EnsureApmManifestTargets

# Move existing configured production references before APM resolves the dependency graph.
if ($installAsDevelopment -and $packagesToInstall.Count -gt 0) {
	MoveConfiguredApmPackagesToDevelopment -ManifestPath (Join-Path (Get-Location).ProviderPath 'apm.yml') -Packages $packagesToInstall | Out-Null
}

# Refresh existing development dependencies before installing new packages when requested.
$updateBeforeInstall = $installAsDevelopment -and $packagesToInstall.Count -gt 0 -and $shouldUpdate
if ($updateBeforeInstall) {
	InvokeApmCommand -Arguments @('update', '--yes')
}

# Install configured packages or the repository manifest.
$installArguments = @('install')
if ($installAsDevelopment -and $packagesToInstall.Count -gt 0) {
	$installArguments += '--dev'
}
if ($packagesToInstall.Count -gt 0) {
	$installArguments += $packagesToInstall
}
InvokeApmCommand -Arguments $installArguments

# Update after installation for production installs and update-only conventions.
if ($shouldUpdate -and -not $updateBeforeInstall) {
	InvokeApmCommand -Arguments @('update', '--yes')
}

# Inspect the working tree for changes left by apm.
[string[]] $changedPaths = @(
	& git status --porcelain=v1 --untracked-files=all |
		Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
		ForEach-Object { $_.Substring(3) }
)

if ($LASTEXITCODE -ne 0) {
	throw 'git status failed.'
}

# Drop lockfile-only churn for other runs, but keep an intentional pre-install dev refresh.
if ($changedPaths.Count -eq 1 -and $changedPaths[0] -eq 'apm.lock.yaml' -and -not $updateBeforeInstall) {
	Write-Host 'Reverting apm.lock.yaml because it is the only changed file.'
	& git restore --source=HEAD --staged --worktree -- 'apm.lock.yaml'
	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to revert apm.lock.yaml.'
	}
}

#requires -PSEdition Core
#requires -Version 7.0
<#
.SYNOPSIS
Writes text as UTF-8 without a byte order mark.
#>
function Write-Utf8NoBomFile {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path,

		[Parameter(Mandatory = $true)]
		[string] $Content
	)

	$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
	[System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

<#
.SYNOPSIS
Compares two files byte-for-byte.
#>
function Test-FileContentMatches {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ExpectedPath,

		[Parameter(Mandatory = $true)]
		[string] $ActualPath
	)

	if (-not (Test-Path -LiteralPath $ActualPath -PathType Leaf)) {
		return $false
	}

	[byte[]] $expectedBytes = [System.IO.File]::ReadAllBytes($ExpectedPath)
	[byte[]] $actualBytes = [System.IO.File]::ReadAllBytes($ActualPath)

	if ($expectedBytes.Length -ne $actualBytes.Length) {
		return $false
	}

	for ($index = 0; $index -lt $expectedBytes.Length; $index++) {
		if ($expectedBytes[$index] -ne $actualBytes[$index]) {
			return $false
		}
	}

	return $true
}

<#
.SYNOPSIS
Copies a published convention file only when the destination is missing or different.
#>
function Copy-FileIfDifferent {
	param(
		[Parameter(Mandatory = $true)]
		[string] $SourcePath,

		[Parameter(Mandatory = $true)]
		[string] $DestinationPath
	)

	$hadDestination = Test-Path -LiteralPath $DestinationPath -PathType Leaf
	$contentMatched = Test-FileContentMatches -ExpectedPath $SourcePath -ActualPath $DestinationPath

	if ($contentMatched) {
		return [pscustomobject]@{
			Changed = $false
			Created = $false
			Updated = $false
		}
	}

	$destinationDirectory = Split-Path -Parent $DestinationPath

	if (-not [string]::IsNullOrWhiteSpace($destinationDirectory)) {
		New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	}

	Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force

	return [pscustomobject]@{
		Changed = $true
		Created = -not $hadDestination
		Updated = $hadDestination
	}
}

<#
.SYNOPSIS
Detects the newline sequence already used in text content.
#>
function Get-LineEnding {
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $Content
	)

	if ($Content.Contains("`r`n")) {
		return "`r`n"
	}

	if ($Content.Contains("`n")) {
		return "`n"
	}

	return "`n"
}

<#
.SYNOPSIS
Reads the settings object from a RepoConventions input file.
#>
function Read-ConventionSettings {
	param(
		[Parameter(Mandatory = $true)]
		[string] $InputPath
	)

	return (Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -AsHashtable).settings
}

<#
.SYNOPSIS
Resolves a repository-root-relative path setting to a full path.
#>
function Get-RepositoryPath {
	param(
		[Parameter(Mandatory = $true)]
		[string] $PathSetting
	)

	if ([string]::IsNullOrWhiteSpace($PathSetting)) {
		throw "The 'path' setting must be a non-empty string."
	}

	if ([System.IO.Path]::IsPathRooted($PathSetting) -and -not ($PathSetting.StartsWith('/', [System.StringComparison]::Ordinal) -or $PathSetting.StartsWith('\\', [System.StringComparison]::Ordinal))) {
		throw "The 'path' setting must be relative or start with '/'."
	}

	$repositoryRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
	$pathText = $PathSetting.Replace('/', [System.IO.Path]::DirectorySeparatorChar).Replace('\\', [System.IO.Path]::DirectorySeparatorChar)
	$relativePath = if ($PathSetting.StartsWith('/', [System.StringComparison]::Ordinal) -or $PathSetting.StartsWith('\\', [System.StringComparison]::Ordinal)) {
		$pathText.TrimStart([System.IO.Path]::DirectorySeparatorChar)
	}
	else {
		$pathText
	}

	return [System.IO.Path]::GetFullPath((Join-Path -Path $repositoryRoot -ChildPath $relativePath))
}

<#
.SYNOPSIS
Formats a repository path for user-facing output as a repo-root-relative path with forward slashes.
#>
function Format-RepositoryRelativePath {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	$repositoryRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $fullPath)

	if ($relativePath -eq '.') {
		return '.'
	}

	return $relativePath.Replace('\', '/')
}

<#
.SYNOPSIS
Creates a unique temporary directory and returns its full path.
#>
function New-TemporaryDirectory {
	$path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
	[System.IO.Directory]::CreateDirectory($path) | Out-Null
	return $path
}

<#
.SYNOPSIS
Sets console encodings to UTF-8 without a byte order mark.
#>
function Set-Utf8NoBomConsoleEncoding {
	[System.Text.Encoding] $utf8 = [System.Text.UTF8Encoding]::new($false)
	[Console]::InputEncoding = $utf8
	[Console]::OutputEncoding = $utf8
	$script:OutputEncoding = $utf8
}

<#
.SYNOPSIS
Runs Copilot with shared convention settings and an isolated config directory.
#>
function Invoke-CopilotWithIsolatedConfig {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Instructions
	)

	Get-Command -Name copilot -ErrorAction Stop | Out-Null

	# Use an isolated Copilot config directory so convention runs do not depend on or mutate the user's setup.
	$copilotConfigDirectory = New-TemporaryDirectory

	try {
		$Instructions | & copilot --config-dir $copilotConfigDirectory --no-ask-user --allow-all-tools --allow-all-paths --model auto
	}
	finally {
		Remove-Item -LiteralPath $copilotConfigDirectory -Recurse -Force
	}
}

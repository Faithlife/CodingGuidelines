#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

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

	# Missing destinations cannot match the expected published file.
	if (-not (Test-Path -LiteralPath $ActualPath -PathType Leaf)) {
		return $false
	}

	# Compare raw bytes so line endings and encodings are part of the result.
	[byte[]] $expectedBytes = [System.IO.File]::ReadAllBytes($ExpectedPath)
	[byte[]] $actualBytes = [System.IO.File]::ReadAllBytes($ActualPath)

	# Differing lengths are enough to prove the files are different.
	if ($expectedBytes.Length -ne $actualBytes.Length) {
		return $false
	}

	# Walk each byte to find the first content mismatch.
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

	# Remember whether the destination existed so the result can classify the change.
	$hadDestination = Test-Path -LiteralPath $DestinationPath -PathType Leaf
	$contentMatched = Test-FileContentMatches -ExpectedPath $SourcePath -ActualPath $DestinationPath

	# Return a no-op result when the published file already matches byte-for-byte.
	if ($contentMatched) {
		return [pscustomobject]@{
			Changed = $false
			Created = $false
			Updated = $false
		}
	}

	$destinationDirectory = Split-Path -Parent $DestinationPath

	# Create parent directories for published files nested below the repository root.
	if (-not [string]::IsNullOrWhiteSpace($destinationDirectory)) {
		New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	}

	Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force

	# Report both the generic change flag and whether this was create or update.
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

	# Prefer CRLF when the file already contains it anywhere.
	if ($Content.Contains("`r`n")) {
		return "`r`n"
	}

	# Preserve LF-only files as LF.
	if ($Content.Contains("`n")) {
		return "`n"
	}

	# Default empty or single-line files to LF.
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

	# RepoConventions inputs wrap convention-specific values under settings.
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

	# Require a concrete repository-relative path value.
	if ([string]::IsNullOrWhiteSpace($PathSetting)) {
		throw "The 'path' setting must be a non-empty string."
	}

	# Allow repo-rooted slash paths but reject drive-qualified absolute paths.
	if ([System.IO.Path]::IsPathRooted($PathSetting) -and -not ($PathSetting.StartsWith('/', [System.StringComparison]::Ordinal) -or $PathSetting.StartsWith('\\', [System.StringComparison]::Ordinal))) {
		throw "The 'path' setting must be relative or start with '/'."
	}

	# Normalize slash styles before resolving against the current repository root.
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

	# Resolve both roots before calculating a stable relative display path.
	$repositoryRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$relativePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $fullPath)

	# Preserve the repository root as a concise dot path.
	if ($relativePath -eq '.') {
		return '.'
	}

	# Use forward slashes in messages regardless of platform separators.
	return $relativePath.Replace('\', '/')
}

<#
.SYNOPSIS
Creates a unique temporary directory and returns its full path.
#>
function New-TemporaryDirectory {
	# Create an isolated temp directory name without reusing an existing path.
	$path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
	[System.IO.Directory]::CreateDirectory($path) | Out-Null
	return $path
}

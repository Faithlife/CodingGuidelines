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
	$OutputEncoding = $utf8
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

	$token = [System.Environment]::GetEnvironmentVariable('COPILOT_GITHUB_TOKEN')

	if ([string]::IsNullOrWhiteSpace($token)) {
		throw "COPILOT_GITHUB_TOKEN must be set to a non-empty value before running Copilot-based conventions."
	}

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

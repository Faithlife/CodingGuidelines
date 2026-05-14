#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

if ((Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1).Version -lt [version]'5.0.0') {
	throw "Pester 5 is required to run these tests. Currently using $((Get-Module Pester).Version)."
}

$helpersPath = Join-Path $PSScriptRoot 'Helpers.ps1'
. $helpersPath

<#
.SYNOPSIS
Creates a temporary RepoConventions input file for a test.
#>
function New-ConventionInputFile {
	[CmdletBinding(DefaultParameterSetName = 'Settings')]
	param(
		[Parameter(Mandatory = $true, ParameterSetName = 'Settings')]
		[hashtable] $Settings,

		[Parameter(Mandatory = $true, ParameterSetName = 'Json')]
		[string] $InputJson
	)

	# Place each generated RepoConventions input in a unique temp JSON file.
	$inputPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
	$content = if ($PSCmdlet.ParameterSetName -eq 'Settings') {
		# Wrap settings in the input shape consumed by convention scripts.
		@{ settings = $Settings } | ConvertTo-Json -Depth 10 -Compress
	}
	else {
		# Use caller-supplied JSON verbatim for malformed-input tests.
		$InputJson
	}

	# Write the input with the same encoding conventions as published files.
	[System.IO.File]::WriteAllText($inputPath, $content, $utf8)
	return $inputPath
}

<#
.SYNOPSIS
Runs a convention script from a test repository directory.
#>
function Invoke-ConventionScript {
	param(
		[Parameter(Mandatory = $true)]
		[string] $ScriptPath,

		[Parameter(Mandatory = $true)]
		[string] $RepositoryRoot,

		[string] $InputPath
	)

	# Run the script from the temporary repository root under test.
	Push-Location $RepositoryRoot
	try {
		# Pass an input path only for conventions that require one.
		if ($PSBoundParameters.ContainsKey('InputPath')) {
			return @(& $ScriptPath $InputPath 6>&1)
		}

		# Capture informational output from scripts invoked without input.
		return @(& $ScriptPath 6>&1)
	}
	finally {
		# Restore the caller's location even when the convention throws.
		Pop-Location
	}
}

<#
.SYNOPSIS
Initializes a temporary Git repository with one initial commit.
#>
function Initialize-TestRepository {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	# Initialize Git state inside the temporary repository under test.
	Push-Location $Path
	try {
		& git init -b master | Out-Null
		& git config user.email 'test@example.com'
		& git config user.name 'Test User'
		& git config core.autocrlf false

		# Create a baseline commit so tests can inspect later convention changes.
		[System.IO.File]::WriteAllText((Join-Path $Path 'README.md'), "# Test`n", $utf8)
		& git add -A
		& git commit -m 'Initial' | Out-Null
	}
	finally {
		# Restore the caller's location after repository initialization.
		Pop-Location
	}
}

<#
.SYNOPSIS
Returns recent commit subjects from a test repository.
#>
function Get-CommitSubjects {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory,

		[int] $Count = 10
	)

	# Read recent subjects from inside the repository under test.
	Push-Location $TestDirectory
	try {
		[string[]] $subjects = @(& git log --format=%s -$Count)
		return $subjects
	}
	finally {
		Pop-Location
	}
}

<#
.SYNOPSIS
Returns the commit ID for a revision in a test repository.
#>
function Get-CommitId {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory,

		[string] $Revision = 'HEAD'
	)

	# Resolve the requested revision from inside the repository under test.
	Push-Location $TestDirectory
	try {
		return (& git rev-parse $Revision)
	}
	finally {
		Pop-Location
	}
}

<#
.SYNOPSIS
Returns `git status --short` output lines from a test repository.
#>
function Get-GitStatusLines {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	# Return porcelain status lines from inside the repository under test.
	Push-Location $TestDirectory
	try {
		[string[]] $statusLines = @(& git status --short)
		return $statusLines
	}
	finally {
		Pop-Location
	}
}

<#
.SYNOPSIS
Copies published convention assets into a test repository.
#>
function Copy-TestConventionAssets {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	# Locate the source repository root relative to the shared test helper script.
	$sourceRepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..'))

	# Copy published conventions and shared sections into the temp repository.
	Copy-Item -LiteralPath (Join-Path $sourceRepositoryRoot 'conventions') -Destination (Join-Path $TestDirectory 'conventions') -Recurse
	Copy-Item -LiteralPath (Join-Path $sourceRepositoryRoot 'sections') -Destination (Join-Path $TestDirectory 'sections') -Recurse
}

<#
.SYNOPSIS
Runs repo-conventions apply from a test repository.
#>
function Invoke-RepoConventionsApply {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory,

		[string] $CopilotCommandDirectory
	)

	# Create a temporary fake Copilot command unless the test supplies one.
	$temporaryCopilot = $null

	if (-not $PSBoundParameters.ContainsKey('CopilotCommandDirectory')) {
		$temporaryCopilot = New-TemporaryTestCopilotCommand
		$CopilotCommandDirectory = $temporaryCopilot.CommandDirectory
	}

	# Prepend the fake Copilot command directory for this apply invocation.
	$originalPath = $env:PATH
	$env:PATH = "$CopilotCommandDirectory$([System.IO.Path]::PathSeparator)$originalPath"

	# Run repo-conventions from the temporary repository under test.
	Push-Location $TestDirectory
	try {
		return @(& repo-conventions apply 6>&1)
	}
	finally {
		# Restore caller state and remove any helper command created here.
		Pop-Location
		$env:PATH = $originalPath

		if ($null -ne $temporaryCopilot) {
			Remove-Item -LiteralPath $temporaryCopilot.CommandDirectory -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

<#
.SYNOPSIS
Creates a fake copilot command for behavior tests.
#>
function New-TestCopilotCommand {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	# Create a repository-local tools directory to hold the fake command.
	$commandDirectory = Join-Path $TestDirectory '.test-tools'
	[System.IO.Directory]::CreateDirectory($commandDirectory) | Out-Null

	$inputPath = Join-Path $commandDirectory 'copilot-input.txt'
	$argumentsPath = Join-Path $commandDirectory 'copilot-arguments.txt'
	$copilotHomePath = Join-Path $commandDirectory 'copilot-home.txt'

	# Write a platform-specific command that captures invocation details for assertions.
	if ($IsWindows) {
		$commandPath = Join-Path $commandDirectory 'copilot.cmd'
		$escapedInputPath = $inputPath.Replace('"', '""')
		$escapedArgumentsPath = $argumentsPath.Replace('"', '""')
		$escapedCopilotHomePath = $copilotHomePath.Replace('"', '""')
		[System.IO.File]::WriteAllText($commandPath, "@echo off`r`n> `"$escapedArgumentsPath`" echo(%*`r`n> `"$escapedCopilotHomePath`" echo(%COPILOT_HOME%`r`nmore > `"$escapedInputPath`"`r`nexit /b 0`r`n", $utf8)
	}
	else {
		$commandPath = Join-Path $commandDirectory 'copilot'
		$commandContent = @'
#!/bin/sh
printf '%s\n' "$*" > '{0}'
printf '%s\n' "$COPILOT_HOME" > '{1}'
cat > '{2}'
exit 0
'@ -f $argumentsPath, $copilotHomePath, $inputPath
		[System.IO.File]::WriteAllText($commandPath, $commandContent, $utf8)
		& chmod +x $commandPath | Out-Null
	}

	# Return the command directory and captured invocation paths to the test.
	return [pscustomobject]@{
		CommandDirectory = $commandDirectory
		InputPath = $inputPath
		ArgumentsPath = $argumentsPath
		CopilotHomePath = $copilotHomePath
	}
}

<#
.SYNOPSIS
Creates a fake copilot command in a temporary directory outside the test repository.
#>
function New-TemporaryTestCopilotCommand {
	# Create a fake Copilot command outside the repository under test.
	$commandDirectory = New-TemporaryDirectory
	$inputPath = Join-Path $commandDirectory 'copilot-input.txt'
	$argumentsPath = Join-Path $commandDirectory 'copilot-arguments.txt'
	$copilotHomePath = Join-Path $commandDirectory 'copilot-home.txt'

	# Write a platform-specific command that discards stdin for apply tests.
	if ($IsWindows) {
		$commandPath = Join-Path $commandDirectory 'copilot.cmd'
		$escapedInputPath = $inputPath.Replace('"', '""')
		$escapedArgumentsPath = $argumentsPath.Replace('"', '""')
		$escapedCopilotHomePath = $copilotHomePath.Replace('"', '""')
		[System.IO.File]::WriteAllText($commandPath, "@echo off`r`n> `"$escapedArgumentsPath`" echo(%*`r`n> `"$escapedCopilotHomePath`" echo(%COPILOT_HOME%`r`nmore > `"$escapedInputPath`"`r`nexit /b 0`r`n", $utf8)
	}
	else {
		$commandPath = Join-Path $commandDirectory 'copilot'
		$commandContent = @'
#!/bin/sh
printf '%s\n' "$*" > '{0}'
printf '%s\n' "$COPILOT_HOME" > '{1}'
cat > /dev/null
exit 0
'@ -f $argumentsPath, $copilotHomePath
		[System.IO.File]::WriteAllText($commandPath, $commandContent, $utf8)
		& chmod +x $commandPath | Out-Null
	}

	# Return the command location so callers can prepend it to PATH.
	return [pscustomobject]@{
		CommandDirectory = $commandDirectory
		InputPath = $inputPath
		ArgumentsPath = $argumentsPath
		CopilotHomePath = $copilotHomePath
	}
}

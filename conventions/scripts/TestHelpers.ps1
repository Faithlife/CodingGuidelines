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
	[CmdletBinding(DefaultParameterSetName = 'Structured')]
	param(
		[Parameter(Mandatory = $true, ParameterSetName = 'Structured')]
		[hashtable] $Settings,

		[Parameter(ParameterSetName = 'Structured')]
		[switch] $GitNoVerify,

		[Parameter(Mandatory = $true, ParameterSetName = 'Verbatim')]
		[string] $InputJson
	)

	# Place each generated RepoConventions input in a unique temp JSON file.
	$inputPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
	$content = if ($PSCmdlet.ParameterSetName -eq 'Structured') {
		# Mirror the input shape RepoConventions produces.
		@{ settings = $Settings; git = @{ noVerify = [bool] $GitNoVerify } } | ConvertTo-Json -Depth 10 -Compress
	}
	else {
		# Use caller-supplied JSON verbatim for specialized (e.g., malformed) test cases.
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

		# Write test Git settings directly to avoid spawning multiple git config processes.
		$gitConfigPath = Join-Path $Path '.git' 'config'
		[System.IO.File]::AppendAllText($gitConfigPath, "`n[user]`n`temail = test@example.com`n`tname = Test User`n[core]`n`tautocrlf = false`n", $utf8)

		# Exclude linked convention assets from Git tracking so tests do not stage and commit the entire conventions tree.
		$excludeLines = [System.Collections.Generic.List[string]]::new()
		foreach ($linkedName in @('conventions', 'sections')) {
			$linkedPath = Join-Path $Path $linkedName
			if (Test-Path -LiteralPath $linkedPath) {
				$linkedItem = Get-Item -LiteralPath $linkedPath -Force
				if ($null -ne $linkedItem.LinkType) {
					$excludeLines.Add("$linkedName/")
				}
			}
		}

		if ($excludeLines.Count -gt 0) {
			$excludePath = Join-Path $Path '.git' 'info' 'exclude'
			[System.IO.File]::AppendAllText($excludePath, "`n" + ($excludeLines -join "`n") + "`n", $utf8)
		}

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

	# Link published conventions and shared sections into the temp repository to avoid copying hundreds of files per test.
	$linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
	New-Item -ItemType $linkType -Path (Join-Path $TestDirectory 'conventions') -Target (Join-Path $sourceRepositoryRoot 'conventions') | Out-Null
	New-Item -ItemType $linkType -Path (Join-Path $TestDirectory 'sections') -Target (Join-Path $sourceRepositoryRoot 'sections') | Out-Null
}

<#
.SYNOPSIS
Runs repo-conventions apply from a test repository.
#>
function Invoke-RepoConventionsApply {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	# Run repo-conventions from the temporary repository under test, preferring a preinstalled tool binary over dotnet dnx.
	Push-Location $TestDirectory
	try {
		if (-not [string]::IsNullOrWhiteSpace($env:REPO_CONVENTIONS_EXE) -and (Test-Path -LiteralPath $env:REPO_CONVENTIONS_EXE)) {
			return @(& $env:REPO_CONVENTIONS_EXE apply 6>&1)
		}

		$repoConventionsCommand = Get-Command 'repo-conventions' -ErrorAction SilentlyContinue
		if ($null -ne $repoConventionsCommand) {
			return @(& $repoConventionsCommand.Source apply 6>&1)
		}

		return @(& dotnet dnx -y repo-conventions -- apply 6>&1)
	}
	finally {
		# Restore the caller location after the apply command completes.
		Pop-Location
	}
}

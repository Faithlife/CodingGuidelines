$helpersPath = Join-Path $PSScriptRoot 'Helpers.ps1'
. $helpersPath

<#
.SYNOPSIS
Creates a unique temporary directory for a test case.
#>
function New-TestDirectory {
	return New-TemporaryDirectory
}

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

	$inputPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
	$content = if ($PSCmdlet.ParameterSetName -eq 'Settings') {
		@{ settings = $Settings } | ConvertTo-Json -Depth 10 -Compress
	}
	else {
		$InputJson
	}

	Write-Utf8NoBomFile -Path $inputPath -Content $content
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

	Push-Location $RepositoryRoot
	try {
		if ($PSBoundParameters.ContainsKey('InputPath')) {
			return @(& $ScriptPath $InputPath 6>&1)
		}

		return @(& $ScriptPath 6>&1)
	}
	finally {
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

	Push-Location $Path
	try {
		& git init | Out-Null
		& git config user.email 'test@example.com'
		& git config user.name 'Test User'
		& git config core.autocrlf false

		Write-Utf8NoBomFile -Path (Join-Path $Path 'README.md') -Content "# Test`n"
		& git add -A
		& git commit -m 'Initial.' | Out-Null
	}
	finally {
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

	$sourceRepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

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

	$temporaryCopilot = $null

	if (-not $PSBoundParameters.ContainsKey('CopilotCommandDirectory')) {
		$temporaryCopilot = New-TemporaryTestCopilotCommand
		$CopilotCommandDirectory = $temporaryCopilot.CommandDirectory
	}

	$originalPath = $env:PATH
	$env:PATH = "$CopilotCommandDirectory;$originalPath"

	Push-Location $TestDirectory
	try {
		return @(& repo-conventions apply 6>&1)
	}
	finally {
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

	$commandDirectory = Join-Path $TestDirectory '.test-tools'
	[System.IO.Directory]::CreateDirectory($commandDirectory) | Out-Null

	$inputPath = Join-Path $commandDirectory 'copilot-input.txt'
	$commandPath = Join-Path $commandDirectory 'copilot.cmd'
	$escapedInputPath = $inputPath.Replace('"', '""')

	Write-Utf8NoBomFile -Path $commandPath -Content "@echo off`r`nmore > `"$escapedInputPath`"`r`nexit /b 0`r`n"

	return [pscustomobject]@{
		CommandDirectory = $commandDirectory
		InputPath = $inputPath
	}
}

<#
.SYNOPSIS
Creates a fake copilot command in a temporary directory outside the test repository.
#>
function New-TemporaryTestCopilotCommand {
	$commandDirectory = New-TemporaryDirectory
	$inputPath = Join-Path $commandDirectory 'copilot-input.txt'
	$commandPath = Join-Path $commandDirectory 'copilot.cmd'
	$escapedInputPath = $inputPath.Replace('"', '""')

	Write-Utf8NoBomFile -Path $commandPath -Content "@echo off`r`nmore > `"$escapedInputPath`"`r`nexit /b 0`r`n"

	return [pscustomobject]@{
		CommandDirectory = $commandDirectory
		InputPath = $inputPath
	}
}

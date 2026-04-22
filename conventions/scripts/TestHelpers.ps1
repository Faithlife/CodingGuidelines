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

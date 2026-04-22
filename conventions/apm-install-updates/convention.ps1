Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function GetGitStatusMap {
	if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
		return $null
	}

	& git rev-parse --is-inside-work-tree *> $null
	if ($LASTEXITCODE -ne 0) {
		return $null
	}

	$statusMap = @{}
	[string[]] $statusLines = @(& git status --porcelain=v1 --untracked-files=all)
	if ($LASTEXITCODE -ne 0) {
		throw 'git status failed.'
	}

	foreach ($statusLine in $statusLines) {
		if ([string]::IsNullOrWhiteSpace($statusLine)) {
			continue
		}

		$path = $statusLine.Substring(3)
		if ($path.Contains(' -> ')) {
			$path = $path.Split(' -> ')[1]
		}

		$statusMap[$path] = $statusLine.Substring(0, 2)
	}

	return $statusMap
}

function GetChangedGitPaths {
	param(
		[Parameter(Mandatory = $true)]
		[AllowNull()]
		[hashtable] $BeforeStatus,

		[Parameter(Mandatory = $true)]
		[AllowNull()]
		[hashtable] $AfterStatus
	)

	if ($null -eq $BeforeStatus -or $null -eq $AfterStatus) {
		return @()
	}

	$allPaths = @($BeforeStatus.Keys + $AfterStatus.Keys | Sort-Object -Unique)
	$changedPaths = foreach ($path in $allPaths) {
		$beforeEntry = if ($BeforeStatus.ContainsKey($path)) { $BeforeStatus[$path] } else { $null }
		$afterEntry = if ($AfterStatus.ContainsKey($path)) { $AfterStatus[$path] } else { $null }

		if ($beforeEntry -ne $afterEntry) {
			$path
		}
	}

	return ,@($changedPaths)
}

Get-Command -Name apm -ErrorAction Stop | Out-Null

$beforeStatus = GetGitStatusMap
$apmExitCode = 0

try {
	Write-Host 'Running apm install --update.'
	& apm install --update
	$apmExitCode = $LASTEXITCODE
}
finally {
	$afterStatus = GetGitStatusMap
	$changedPaths = GetChangedGitPaths -BeforeStatus $beforeStatus -AfterStatus $afterStatus

	if ($changedPaths.Count -eq 1 -and $changedPaths[0] -eq 'apm.lock.yaml') {
		Write-Host 'Reverting apm.lock.yaml because it is the only changed file.'
		& git restore --source=HEAD --staged --worktree -- 'apm.lock.yaml'
		if ($LASTEXITCODE -ne 0) {
			throw 'Failed to revert apm.lock.yaml.'
		}
	}
}

if ($apmExitCode -ne 0) {
	throw 'apm install --update failed.'
}

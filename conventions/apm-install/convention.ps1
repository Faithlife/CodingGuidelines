Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$apmArguments = @('install', '--update')

if ($args.Count -gt 0 -and (Test-Path -LiteralPath $args[0])) {
	$conventionInput = Get-Content -LiteralPath $args[0] -Raw | ConvertFrom-Json
	if ($null -ne $conventionInput.settings -and $null -ne $conventionInput.settings.packages) {
		[string[]] $packages = @($conventionInput.settings.packages)
		$apmArguments += $packages
	}
}

Get-Command -Name apm -ErrorAction Stop | Out-Null

Write-Host ('Running apm ' + ($apmArguments -join ' ') + '.')
& apm @apmArguments

if ($LASTEXITCODE -ne 0) {
	throw 'apm install --update failed.'
}

[string[]] $changedPaths = @(
	& git status --porcelain=v1 --untracked-files=all |
		Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
		ForEach-Object { $_.Substring(3) }
)

if ($LASTEXITCODE -ne 0) {
	throw 'git status failed.'
}

if ($changedPaths.Count -eq 1 -and $changedPaths[0] -eq 'apm.lock.yaml') {
	Write-Host 'Reverting apm.lock.yaml because it is the only changed file.'
	& git restore --source=HEAD --staged --worktree -- 'apm.lock.yaml'
	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to revert apm.lock.yaml.'
	}
}

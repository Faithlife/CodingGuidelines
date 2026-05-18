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
$conventionInput = Get-Content -LiteralPath $args[0] -Raw | ConvertFrom-Json -AsHashtable
$settings = $conventionInput.settings

if ($null -ne $settings -and $settings.ContainsKey('install') -and $null -ne $settings.install) {
	[string[]] $packagesToInstall = @($settings.install)
}

if ($null -ne $settings -and $settings.ContainsKey('update') -and $null -ne $settings.update) {
	$shouldUpdate = [bool] $settings.update
}

# Skip when neither an apm manifest nor explicit packages are available.
if ($packagesToInstall.Count -eq 0 -and -not (Test-Path -LiteralPath 'apm.yml')) {
	Write-Host 'Skipping apm install because apm.yml is absent and no packages were configured.'
	return
}

# Build the apm install command for the copilot target.
$apmArguments = @('install')

if ($shouldUpdate) {
	$apmArguments += '--update'
}

$apmArguments += @('--target', 'copilot')

if ($packagesToInstall.Count -gt 0) {
	$apmArguments += $packagesToInstall
}

# Verify apm is available before invoking it.
Get-Command -Name apm -ErrorAction Stop | Out-Null

# Run apm and fail the convention if installation fails.
Write-Host ('Running apm ' + ($apmArguments -join ' ') + '.')
& apm @apmArguments

if ($LASTEXITCODE -ne 0) {
	throw 'apm install failed.'
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

# Drop lockfile-only churn so no-op runs stay clean.
if ($changedPaths.Count -eq 1 -and $changedPaths[0] -eq 'apm.lock.yaml') {
	Write-Host 'Reverting apm.lock.yaml because it is the only changed file.'
	& git restore --source=HEAD --staged --worktree -- 'apm.lock.yaml'
	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to revert apm.lock.yaml.'
	}
}

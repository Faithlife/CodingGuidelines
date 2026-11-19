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

function TestApmManifestHasTargets {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path
	)

	# Treat only unindented targets entries as the repository-level APM targets declaration.
	if (-not (Test-Path -LiteralPath $Path)) {
		return $false
	}

	# Scan the manifest without otherwise parsing or reformatting YAML content.
	foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
		if ($line -match '^\uFEFF?targets\s*:') {
			return $true
		}
	}

	return $false
}

function EnsureApmManifestTargets {
	# Resolve the manifest path from the target repository root PowerShell location.
	$repositoryRoot = (Get-Location).ProviderPath
	$apmManifestPath = Join-Path $repositoryRoot 'apm.yml'

	# Leave repositories with an existing top-level targets declaration untouched.
	if (TestApmManifestHasTargets -Path $apmManifestPath) {
		return
	}

	# Add the default Copilot target to a new or existing APM manifest.
	$targetText = "targets:`n- copilot`n"
	if (-not (Test-Path -LiteralPath $apmManifestPath)) {
		[System.IO.File]::WriteAllText($apmManifestPath, $targetText, $utf8)
		return
	}

	# Append the targets declaration after any existing manifest content.
	$manifestText = [System.IO.File]::ReadAllText($apmManifestPath)
	$manifestText = $manifestText -replace "(?:\r?\n[ \t]*)+\z", ''
	if ($manifestText.Length -gt 0) {
		$manifestText += "`n"
	}
	$manifestText += $targetText
	[System.IO.File]::WriteAllText($apmManifestPath, $manifestText, $utf8)
}

function RemoveApmManifestAuthor {
	# Resolve the manifest path from the target repository root PowerShell location.
	$repositoryRoot = (Get-Location).ProviderPath
	$apmManifestPath = Join-Path $repositoryRoot 'apm.yml'

	# Remove the generated top-level author entry because it is optional and often inaccurate.
	if (-not (Test-Path -LiteralPath $apmManifestPath)) {
		return
	}
	[string[]] $manifestLines = @([System.IO.File]::ReadAllLines($apmManifestPath))
	[string[]] $filteredLines = @($manifestLines | Where-Object { $_ -notmatch '^\uFEFF?author\s*:' })
	if ($filteredLines.Count -eq $manifestLines.Count) {
		return
	}

	# Write the manifest back only when an author line was removed.
	$manifestText = if ($filteredLines.Count -eq 0) {
		''
	}
	else {
		($filteredLines -join "`n") + "`n"
	}
	[System.IO.File]::WriteAllText($apmManifestPath, $manifestText, $utf8)
}

function RemoveUnhashedDeployedDirectories {
	# Resolve the lockfile path from the target repository root PowerShell location.
	$repositoryRoot = (Get-Location).ProviderPath
	$lockFilePath = Join-Path $repositoryRoot 'apm.lock.yaml'
	if (-not (Test-Path -LiteralPath $lockFilePath)) {
		return
	}

	# Scan the lockfile for deployed paths and per-file hashes without a YAML parser.
	$deployedPaths = [System.Collections.Generic.List[string]]::new()
	$hashedPaths = [System.Collections.Generic.List[string]]::new()
	$inDeployedFiles = $false
	foreach ($line in [System.IO.File]::ReadAllLines($lockFilePath)) {
		if ($line -match '^\s*deployed_files\s*:\s*$') {
			$inDeployedFiles = $true
			continue
		}
		if ($inDeployedFiles -and $line -match '^\s*-\s+(\S.*?)\s*$') {
			$deployedPaths.Add($Matches[1].Trim("'", '"'))
			continue
		}
		$inDeployedFiles = $false
		if ($line -match '^\s+(\S[^:]*):\s*sha256:[0-9a-f]+\s*$' -and $Matches[1] -ne 'content_hash') {
			$hashedPaths.Add($Matches[1].Trim("'", '"'))
		}
	}

	# Older apm versions recorded deployed skill directories without per-file hashes. Newer versions
	# refuse to replace such a directory ("no trustworthy local deployment baseline") unless it is
	# identical to what they would deploy, so remove it and let apm redeploy it and record hashes.
	foreach ($deployedPath in $deployedPaths) {
		if ([System.IO.Path]::IsPathRooted($deployedPath) -or ($deployedPath -split '[\\/]') -contains '..') {
			continue
		}
		$item = Get-Item -LiteralPath (Join-Path $repositoryRoot $deployedPath) -Force -ErrorAction SilentlyContinue
		if ($null -eq $item -or -not $item.PSIsContainer -or $null -ne $item.LinkType) {
			continue
		}
		$prefix = $deployedPath.TrimEnd('/') + '/'
		if (@($hashedPaths | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::Ordinal) }).Count -gt 0) {
			continue
		}
		Write-Host "Removing '$deployedPath' so apm can redeploy it with per-file hashes."
		Remove-Item -LiteralPath $item.FullName -Recurse -Force
	}
}

function InvokeApmCommand {
	param(
		[Parameter(Mandatory = $true)]
		[string[]] $Arguments
	)

	# Run apm and fail the convention if the command fails.
	Write-Host ('Running apm ' + ($Arguments -join ' ') + '.')
	& apm @Arguments

	if ($LASTEXITCODE -ne 0) {
		throw ('apm ' + $Arguments[0] + ' failed.')
	}
}

if ($null -ne $settings -and $settings.ContainsKey('install') -and $null -ne $settings.install) {
	[string[]] $packagesToInstall = @($settings.install)
}

if ($null -ne $settings -and $settings.ContainsKey('update') -and $null -ne $settings.update) {
	$shouldUpdate = [bool] $settings.update
}

# Skip when neither an apm manifest nor explicit packages are available.
if ($packagesToInstall.Count -eq 0 -and -not (Test-Path -LiteralPath 'apm.yml')) {
	Write-Host 'Skipping apm because apm.yml is absent and no packages were configured.'
	return
}

# Verify apm is available before invoking it.
Get-Command -Name apm -ErrorAction Stop | Out-Null

# Initialize an APM manifest before installing configured packages into a repository without one.
if ($packagesToInstall.Count -gt 0 -and -not (Test-Path -LiteralPath 'apm.yml')) {
	InvokeApmCommand -Arguments @('init', '--yes')
	RemoveApmManifestAuthor
}

# Ensure apm can resolve the Copilot target from the repository manifest.
EnsureApmManifestTargets

# Remove deployed directories that older apm versions recorded without per-file hashes.
RemoveUnhashedDeployedDirectories

# Install configured packages or the repository manifest before updating.
$installArguments = @('install')
if ($packagesToInstall.Count -gt 0) {
	$installArguments += $packagesToInstall
}
InvokeApmCommand -Arguments $installArguments

# Update installed packages after the install step when requested.
if ($shouldUpdate) {
	InvokeApmCommand -Arguments @('update', '--yes')
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

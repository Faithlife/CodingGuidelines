#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Read optional item paths from the convention input.
$conventionInput = Get-Content -LiteralPath $args[0] -Raw | ConvertFrom-Json -AsHashtable
$settings = $conventionInput.settings
$hasItems = $false
[string[]] $items = @()

# Switch from update mode to add mode when items are explicitly configured.
if ($null -ne $settings -and $settings.ContainsKey('items') -and $null -ne $settings.items) {
	$hasItems = $true
	$items = @($settings.items)
}

# Build the dotnet-solution-items command arguments.
[string[]] $arguments = @('-y', 'dotnet-solution-items')
if ($hasItems) {
	$arguments += @('add', '--force')
	$arguments += $items
}
else {
	$arguments += 'update'
}

# Verify dnx is available before invoking it.
Get-Command -Name dnx -ErrorAction Stop | Out-Null

# Run dotnet-solution-items and fail the convention if the command fails.
Write-Host ('Running dnx ' + ($arguments -join ' ') + '.')
& dnx @arguments

if ($LASTEXITCODE -ne 0) {
	throw ('dnx dotnet-solution-items ' + $arguments[2] + ' failed.')
}

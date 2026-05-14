#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load the shared config text section implementation.
$configTextSectionPath = Join-Path $PSScriptRoot '..' 'scripts' 'ConfigTextSection.ps1'
. $configTextSectionPath

# List Prettier configuration file names that signal Prettier usage.
$prettierConfigFileNames = @(
	'.prettierrc',
	'.prettierrc.json',
	'.prettierrc.json5',
	'.prettierrc.yaml',
	'.prettierrc.yml',
	'.prettierrc.js',
	'.prettierrc.cjs',
	'.prettierrc.mjs',
	'.prettierrc.ts',
	'.prettierrc.cts',
	'.prettierrc.mts',
	'prettier.config.js',
	'prettier.config.cjs',
	'prettier.config.mjs',
	'prettier.config.ts',
	'prettier.config.cts',
	'prettier.config.mts'
)

# Detect whether the repository contains a standalone Prettier config.
function TestPrettierConfigFile {
	foreach ($configFileName in $prettierConfigFileNames) {
		if (Test-Path -LiteralPath (Join-Path (Get-Location).Path $configFileName) -PathType Leaf) {
			return $true
		}
	}

	return $false
}

# Detect Prettier settings or dependencies in package.json.
function TestPackageJsonPrettier {
	$packageJsonPath = Join-Path (Get-Location).Path 'package.json'

	if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
		return $false
	}

	try {
		$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json -AsHashtable
	}
	catch {
		throw "Failed to parse 'package.json' while detecting Prettier."
	}

	if ($null -eq $packageJson) {
		return $false
	}

	if ($packageJson.ContainsKey('prettier')) {
		return $true
	}

	foreach ($dependencyProperty in @('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies')) {
		if (-not $packageJson.ContainsKey($dependencyProperty)) {
			continue
		}

		$dependencies = $packageJson[$dependencyProperty]

		if ($dependencies -is [System.Collections.IDictionary] -and $dependencies.ContainsKey('prettier')) {
			return $true
		}
	}

	return $false
}

# Determine whether the repository appears to use Prettier.
function TestPrettierUsage {
	if (Test-Path -LiteralPath (Join-Path (Get-Location).Path '.prettierignore') -PathType Leaf) {
		return $true
	}

	if (TestPrettierConfigFile) {
		return $true
	}

	if (TestPackageJsonPrettier) {
		return $true
	}

	return $false
}

# Map this convention's settings into the config-text-section convention.
function GetConfigTextSectionSettings {
	param(
		[AllowNull()]
		[System.Collections.IDictionary] $Settings
	)

	$configTextSectionSettings = @{
		path = '.prettierignore'
		'comment-prefix' = '#'
	}

	if ($null -eq $Settings) {
		return $configTextSectionSettings
	}

	foreach ($settingName in @('name', 'text', 'agent', 'commit')) {
		if ($Settings.ContainsKey($settingName)) {
			$configTextSectionSettings[$settingName] = $Settings[$settingName]
		}
	}

	return $configTextSectionSettings
}

# Require and read the convention input settings.
if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$inputPath = $args[0]
$settings = Read-ConventionSettings -InputPath $inputPath

# Leave repositories without Prettier usage unchanged.
if (-not (TestPrettierUsage)) {
	Write-Host "Prettier was not detected; leaving '.prettierignore' unchanged."
	return
}

# Apply the configured .prettierignore section.
Invoke-ConfigTextSection -Settings (GetConfigTextSectionSettings -Settings $settings)

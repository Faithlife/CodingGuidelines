#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Load the shared config text section implementation.
$configTextSectionPath = Join-Path $PSScriptRoot '..' 'scripts' 'ConfigTextSection.ps1'
. $configTextSectionPath

# Require the convention input path before reading settings.
if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

# Apply the configured text section to the target repository.
$inputPath = $args[0]
$settings = Read-ConventionSettings -InputPath $inputPath
Invoke-ConfigTextSection -Settings $settings

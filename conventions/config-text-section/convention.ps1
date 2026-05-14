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

# Apply the configured text section to the target repository.
$settings = Read-ConventionSettings -InputPath $args[0]
Invoke-ConfigTextSection -Settings $settings

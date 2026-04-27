#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configTextSectionPath = Join-Path $PSScriptRoot '..\scripts\ConfigTextSection.ps1'
. $configTextSectionPath

if ($args.Count -eq 0) {
	throw 'The input path argument is required.'
}

$inputPath = $args[0]
$settings = Read-ConventionSettings -InputPath $inputPath
Invoke-ConfigTextSection -Settings $settings

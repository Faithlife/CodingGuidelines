#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\scripts\Helpers.ps1'
. $helpersPath

Set-Utf8NoBomConsoleEncoding

$sourceWorkflowPath = Join-Path $PSScriptRoot 'files\build.yaml'
$targetWorkflowPath = Join-Path (Get-Location) '.github/workflows/build.yaml'
$copyResult = Copy-FileIfDifferent -SourcePath $sourceWorkflowPath -DestinationPath $targetWorkflowPath

if ($copyResult.Updated) {
	Write-Host "Updated '$targetWorkflowPath' from the published Faithlife build workflow."
}
elseif ($copyResult.Created) {
	Write-Host "Created '$targetWorkflowPath' from the published Faithlife build workflow."
}
else {
	Write-Host "'$targetWorkflowPath' already matches the published Faithlife build workflow."
}

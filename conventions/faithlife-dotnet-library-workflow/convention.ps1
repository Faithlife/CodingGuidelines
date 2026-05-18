#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
. $helpersPath

# Copy each published workflow into the repository when it differs.
$publishedWorkflowNames = @(
	'ci.yml'
	'copilot-setup-steps.yml'
)

foreach ($publishedWorkflowName in $publishedWorkflowNames) {
	$sourceWorkflowPath = Join-Path $PSScriptRoot 'files' $publishedWorkflowName
	$targetWorkflowPath = Join-Path (Get-Location) '.github/workflows' $publishedWorkflowName
	$copyResult = Copy-FileIfDifferent -SourcePath $sourceWorkflowPath -DestinationPath $targetWorkflowPath

	# Report whether the workflow was created or updated.
	if ($copyResult.Updated) {
		Write-Host "Updated '$targetWorkflowPath' from the published Faithlife build workflow."
	}
	elseif ($copyResult.Created) {
		Write-Host "Created '$targetWorkflowPath' from the published Faithlife build workflow."
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workflowPath = Join-Path $PWD '.github/workflows/repo-conventions.yml'
$existingWorkflowContent = $null
$existingMinute = $null
if (Test-Path -LiteralPath $workflowPath) {
  $existingWorkflowContent = Get-Content -LiteralPath $workflowPath -Raw
  if ($existingWorkflowContent -match "(?m)^  - cron: '(?<minute>([0-9]|[1-5][0-9])) 9 \* \* 1-5'\r?$") {
    $existingMinute = $Matches.minute
  }
}

$workflowDirectory = Split-Path -Parent $workflowPath
New-Item -ItemType Directory -Path $workflowDirectory -Force | Out-Null

$minute = if ($null -ne $existingMinute) {
  $existingMinute
} else {
  Get-Random -Minimum 1 -Maximum 60
}
$workflowContent = @"
name: Apply Repository Conventions

on:
  schedule:
  - cron: '$minute 9 * * 1-5'
  workflow_dispatch:
    inputs:
      conventions:
        type: string
        description: Optional convention names to add (space-separated)
        required: false
        default: ''

permissions:
  contents: write
  pull-requests: write

jobs:
  apply:
    uses: Faithlife/CodingGuidelines/.github/workflows/repo-conventions-call.yml@master
    with:
      conventions: `${{ github.event.inputs.conventions || '' }}
    secrets: inherit
"@

$normalizedWorkflowContent = $workflowContent.Replace("`r`n", "`n").TrimEnd("`n")
if ($null -ne $existingWorkflowContent) {
  $normalizedExistingWorkflowContent = $existingWorkflowContent.Replace("`r`n", "`n").TrimEnd("`n")
  if ($normalizedExistingWorkflowContent -eq $normalizedWorkflowContent) {
    Write-Host 'Workflow already up to date.'
    exit 0
  }
}

Set-Content -LiteralPath $workflowPath -Value $workflowContent -Encoding utf8NoBOM
Write-Host "Updated $workflowPath"
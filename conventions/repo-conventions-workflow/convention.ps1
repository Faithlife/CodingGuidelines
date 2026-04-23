Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$workflowPath = Join-Path $PWD '.github/workflows/repo-conventions.yml'
if (Test-Path -LiteralPath $workflowPath) {
  Write-Host 'Workflow already exists.'
  exit 0
}

$workflowDirectory = Split-Path -Parent $workflowPath
New-Item -ItemType Directory -Path $workflowDirectory -Force | Out-Null

$minute = Get-Random -Minimum 1 -Maximum 60
$workflowContent = @"
name: Apply Repository Conventions

on:
  schedule:
  - cron: '$minute 9 * * 1-5'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  apply:
    uses: Faithlife/CodingGuidelines/.github/workflows/repo-conventions-call.yml@master
    secrets: inherit
"@

Set-Content -LiteralPath $workflowPath -Value $workflowContent -Encoding utf8NoBOM
Write-Host "Created $workflowPath"
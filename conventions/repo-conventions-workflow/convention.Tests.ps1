#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
# Run these tests with Invoke-Pester

Describe 'repo-conventions-workflow' {
  BeforeAll {
    $script:scriptPath = Join-Path $PSScriptRoot 'convention.ps1'

    function script:NewTestDirectory {
      $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $path | Out-Null
      return $path
    }

    function script:InvokeConvention {
      param(
        [Parameter(Mandatory = $true)]
        [string] $RepositoryPath
      )

      $payloadPath = Join-Path $RepositoryPath 'payload.json'
      Set-Content -LiteralPath $payloadPath -Value '{"settings":null}' -Encoding utf8NoBOM

      Push-Location $RepositoryPath
      try {
        & $script:scriptPath $payloadPath
      }
      finally {
        Pop-Location
      }
    }
  }

  It 'creates the workflow when missing' {
    $repoPath = NewTestDirectory
    try {
      InvokeConvention -RepositoryPath $repoPath

      $workflowPath = Join-Path $repoPath '.github/workflows/repo-conventions.yml'
      $content = Get-Content -LiteralPath $workflowPath -Raw

        Test-Path -LiteralPath $workflowPath | Should -Be $true
        $content | Should -Match "(?m)^name: Apply Repository Conventions\r?$"
        $content | Should -Match "(?m)^  - cron: '([1-9]|[1-5][0-9]) 9 \* \* 1-5'\r?$"
        $content | Should -Match "(?m)^    uses: Faithlife/CodingGuidelines/\.github/workflows/repo-conventions-call\.yml@master\r?$"
        $content | Should -Match "(?m)^    secrets: inherit\r?$"
    }
    finally {
      Remove-Item -LiteralPath $repoPath -Recurse -Force
    }
  }

  It 'leaves an existing workflow unchanged' {
    $repoPath = NewTestDirectory
    try {
      $workflowPath = Join-Path $repoPath '.github/workflows/repo-conventions.yml'
      New-Item -ItemType Directory -Path (Split-Path -Parent $workflowPath) -Force | Out-Null
      Set-Content -LiteralPath $workflowPath -Value 'existing content' -Encoding utf8NoBOM

      InvokeConvention -RepositoryPath $repoPath

        ((Get-Content -LiteralPath $workflowPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'existing content'
    }
    finally {
      Remove-Item -LiteralPath $repoPath -Recurse -Force
    }
  }
}
#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'repo-conventions-workflow convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedWorkflowPath = Join-Path $PSScriptRoot 'files' 'conventions.yml'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeRepoConventionsWorkflowConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			$inputPath = New-ConventionInputFile -Settings @{}
			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}
	}

	It 'creates .github/workflows/conventions.yml when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeRepoConventionsWorkflowConvention -TestDirectory $testDirectory
			$workflowPath = Join-Path $testDirectory '.github/workflows/conventions.yml'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $workflowPath) | Should -Be $true
			(Get-Content -LiteralPath $workflowPath -Raw) | Should -Be (Get-Content -LiteralPath $script:expectedWorkflowPath -Raw)
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^\?\? \.github/workflows/conventions\.yml$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$workflowPath' from the published repo-conventions workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates an existing conventions workflow to the published file' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$workflowPath = Join-Path $testDirectory '.github/workflows/conventions.yml'
			New-Item -ItemType Directory -Path (Split-Path -Parent $workflowPath) -Force | Out-Null
			Write-Utf8NoBomFile -Path $workflowPath -Content "name: Placeholder`n"

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add placeholder workflow' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeRepoConventionsWorkflowConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $workflowPath -Raw) | Should -Be (Get-Content -LiteralPath $script:expectedWorkflowPath -Raw)
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^ M \.github/workflows/conventions\.yml$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Updated '$workflowPath' from the published repo-conventions workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			InvokeRepoConventionsWorkflowConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add conventions workflow' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeRepoConventionsWorkflowConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			$expectedWorkflowPath = Join-Path $testDirectory '.github' 'workflows' 'conventions.yml'
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$expectedWorkflowPath' already matches the published repo-conventions workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

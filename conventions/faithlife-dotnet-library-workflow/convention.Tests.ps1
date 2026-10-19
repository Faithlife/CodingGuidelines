#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'faithlife-dotnet-library-workflow convention' {
	BeforeAll {
		# Cache convention paths and load shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedWorkflowPaths = @{
			'ci.yml' = Join-Path $PSScriptRoot 'files' 'ci.yml'
			'copilot-setup-steps.yml' = Join-Path $PSScriptRoot 'files' 'copilot-setup-steps.yml'
		}
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeFaithlifeDotNetLibraryWorkflowConvention {
			# Invoke the convention script with an empty settings file.
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

		function script:GetAllGitStatusLines {
			# Read git status including untracked files from the test repository.
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			Push-Location $TestDirectory
			try {
				return @(& git status --short --untracked-files=all)
			}
			finally {
				Pop-Location
			}
		}
	}

	It 'creates the published workflows when they are missing' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an empty initialized repository.
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention and collect the generated workflow state.
			$output = InvokeFaithlifeDotNetLibraryWorkflowConvention -TestDirectory $testDirectory
			$status = @(GetAllGitStatusLines -TestDirectory $testDirectory)
			$ciWorkflowPath = Join-Path $testDirectory '.github/workflows/ci.yml'
			$copilotSetupWorkflowPath = Join-Path $testDirectory '.github/workflows/copilot-setup-steps.yml'

			# Assert the published workflow was created and reported.
			(Test-Path -LiteralPath $ciWorkflowPath) | Should -Be $true
			(Get-Content -LiteralPath $ciWorkflowPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedWorkflowPaths['ci.yml'] -Raw)
			(Test-Path -LiteralPath $copilotSetupWorkflowPath) | Should -Be $true
			(Get-Content -LiteralPath $copilotSetupWorkflowPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedWorkflowPaths['copilot-setup-steps.yml'] -Raw)
			$status.Count | Should -Be 2
			$status | Should -Contain '?? .github/workflows/ci.yml'
			$status | Should -Contain '?? .github/workflows/copilot-setup-steps.yml'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$ciWorkflowPath' from the published Faithlife build workflow.") | Should -Be $true
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$copilotSetupWorkflowPath' from the published Faithlife build workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates existing published workflows to the packaged files' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with a committed placeholder workflow.
			Initialize-TestRepository -Path $testDirectory
			$ciWorkflowPath = Join-Path $testDirectory '.github/workflows/ci.yml'
			$copilotSetupWorkflowPath = Join-Path $testDirectory '.github/workflows/copilot-setup-steps.yml'
			New-Item -ItemType Directory -Path (Split-Path -Parent $ciWorkflowPath) -Force | Out-Null
			[System.IO.File]::WriteAllText($ciWorkflowPath, "name: Placeholder`n", $utf8)
			[System.IO.File]::WriteAllText($copilotSetupWorkflowPath, "name: Placeholder`n", $utf8)

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add placeholder workflow' | Out-Null
			}
			finally {
				Pop-Location
			}

			# Apply the convention and collect the modified workflow state.
			$output = InvokeFaithlifeDotNetLibraryWorkflowConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the workflow was replaced with the published file.
			(Get-Content -LiteralPath $ciWorkflowPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedWorkflowPaths['ci.yml'] -Raw)
			(Get-Content -LiteralPath $copilotSetupWorkflowPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedWorkflowPaths['copilot-setup-steps.yml'] -Raw)
			$status.Count | Should -Be 2
			$status | Should -Contain ' M .github/workflows/ci.yml'
			$status | Should -Contain ' M .github/workflows/copilot-setup-steps.yml'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Updated '$ciWorkflowPath' from the published Faithlife build workflow.") | Should -Be $true
			(@($output | ForEach-Object { $_.ToString() }) -contains "Updated '$copilotSetupWorkflowPath' from the published Faithlife build workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository after a successful first convention run.
			Initialize-TestRepository -Path $testDirectory

			InvokeFaithlifeDotNetLibraryWorkflowConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add ci workflow' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			# Apply the convention a second time and capture repository state.
			$output = InvokeFaithlifeDotNetLibraryWorkflowConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the second run reported no content changes.
			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			@($output).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

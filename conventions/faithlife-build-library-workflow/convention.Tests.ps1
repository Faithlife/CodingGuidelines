#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'faithlife-build-library-workflow convention' {
	BeforeAll {
		# Cache convention paths and load shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedWorkflowPath = Join-Path $PSScriptRoot 'files' 'build.yaml'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeFaithlifeBuildLibraryWorkflowConvention {
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

	It 'creates .github/workflows/build.yaml when it is missing' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an empty initialized repository.
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention and collect the generated workflow state.
			$output = InvokeFaithlifeBuildLibraryWorkflowConvention -TestDirectory $testDirectory
			$workflowPath = Join-Path $testDirectory '.github/workflows/build.yaml'
			$status = @(GetAllGitStatusLines -TestDirectory $testDirectory)

			# Assert the published workflow was created and reported.
			(Test-Path -LiteralPath $workflowPath) | Should -Be $true
			(Get-Content -LiteralPath $workflowPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedWorkflowPath -Raw)
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^\?\? \.github/workflows/build\.yaml$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$workflowPath' from the published Faithlife build workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates an existing build workflow to the published file' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with a committed placeholder workflow.
			Initialize-TestRepository -Path $testDirectory
			$workflowPath = Join-Path $testDirectory '.github/workflows/build.yaml'
			New-Item -ItemType Directory -Path (Split-Path -Parent $workflowPath) -Force | Out-Null
			[System.IO.File]::WriteAllText($workflowPath, "name: Placeholder`n", $utf8)

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add placeholder workflow' | Out-Null
			}
			finally {
				Pop-Location
			}

			# Apply the convention and collect the modified workflow state.
			$output = InvokeFaithlifeBuildLibraryWorkflowConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the workflow was replaced with the published file.
			(Get-Content -LiteralPath $workflowPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedWorkflowPath -Raw)
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^ M \.github/workflows/build\.yaml$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Updated '$workflowPath' from the published Faithlife build workflow.") | Should -Be $true
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

			InvokeFaithlifeBuildLibraryWorkflowConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add build workflow' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			# Apply the convention a second time and capture repository state.
			$output = InvokeFaithlifeBuildLibraryWorkflowConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the second run reported no content changes.
			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			$expectedWorkflowPath = Join-Path $testDirectory '.github' 'workflows' 'build.yaml'
		(@($output | ForEach-Object { $_.ToString() }) -contains "'$expectedWorkflowPath' already matches the published Faithlife build workflow.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

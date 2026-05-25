#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the faithlife-dotnet-library-contributing convention.
Describe 'faithlife-dotnet-library-contributing convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'publishes the shared CONTRIBUTING file and is idempotent' {
		# Set up an empty repository for contributor guidance publishing.
		$testDirectory = New-TemporaryDirectory

		try {
			# Run the convention and compare the published file to the source asset.
			$output = Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $testDirectory
			$targetPath = Join-Path $testDirectory 'CONTRIBUTING.md'
			$expectedPath = Join-Path $PSScriptRoot 'files' 'CONTRIBUTING.md'

			Test-FileContentMatches -ExpectedPath $expectedPath -ActualPath $targetPath | Should -Be $true
			$output[-1].ToString() | Should -Be "Updated 'CONTRIBUTING.md'."

			# Re-run the convention and assert it produces no output when compliant.
			$secondOutput = Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $testDirectory
			Test-FileContentMatches -ExpectedPath $expectedPath -ActualPath $targetPath | Should -Be $true
			@($secondOutput).Count | Should -Be 0
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the dotnet-slnx convention.
Describe 'dotnet-slnx convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention against the supplied temporary repository.
		function script:InvokeDotnetSlnxConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory
		}

		# Write a minimal legacy .sln file for migration tests.
		function script:SetSolutionFileContent {
			param(
				[Parameter(Mandatory = $true)]
				[string] $Path
			)

			$solutionContent = @"
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Global
    GlobalSection(SolutionProperties) = preSolution
        HideSolutionNode = FALSE
    EndGlobalSection
EndGlobal
"@

			[System.IO.File]::WriteAllText($Path, $solutionContent, $utf8)
		}
	}

	It 'migrates solution files and renames matching DotSettings files' {
		# Set up a repository with a legacy solution and matching DotSettings file.
		$testDirectory = New-TemporaryDirectory

		try {
			$solutionPath = Join-Path $testDirectory 'Test.sln'
			$slnxPath = Join-Path $testDirectory 'Test.slnx'
			$dotSettingsPath = Join-Path $testDirectory 'Test.sln.DotSettings'
			$slnxDotSettingsPath = Join-Path $testDirectory 'Test.slnx.DotSettings'

			SetSolutionFileContent -Path $solutionPath
			Set-Content -LiteralPath $dotSettingsPath -Value 'dotsettings' -Encoding utf8NoBOM

			# Run the convention to migrate the solution format.
			$output = InvokeDotnetSlnxConvention -TestDirectory $testDirectory

			# Assert the solution and DotSettings files were renamed as expected.
			(Test-Path -LiteralPath $solutionPath) | Should -Be $false
			(Test-Path -LiteralPath $slnxPath) | Should -Be $true
			(Test-Path -LiteralPath $dotSettingsPath) | Should -Be $false
			(Test-Path -LiteralPath $slnxDotSettingsPath) | Should -Be $true
			((Get-Content -LiteralPath $slnxDotSettingsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'dotsettings'
			$output.Count | Should -Be 3
			$output[0].ToString() | Should -Be "Migrating solution '$solutionPath' to '$slnxPath'."
			$output[1].ToString() | Should -Be "Removing migrated solution file '$solutionPath'."
			$output[2].ToString() | Should -Be "Renaming '$dotSettingsPath' to '$slnxDotSettingsPath'."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'leaves DotSettings files in place when the corresponding slnx file does not exist' {
		# Set up an orphaned DotSettings file without a matching slnx file.
		$testDirectory = New-TemporaryDirectory

		try {
			$dotSettingsPath = Join-Path $testDirectory 'Orphan.sln.DotSettings'
			[System.IO.File]::WriteAllText($dotSettingsPath, 'orphan', $utf8)

			# Run the convention with no solution migration to pair with the file.
			InvokeDotnetSlnxConvention -TestDirectory $testDirectory

			# Assert the orphaned DotSettings file is preserved.
			(Test-Path -LiteralPath $dotSettingsPath) | Should -Be $true
			((Get-Content -LiteralPath $dotSettingsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'orphan'
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'throws when the destination DotSettings file already exists' {
		# Set up conflicting source and destination DotSettings files.
		$testDirectory = New-TemporaryDirectory

		try {
			$slnxPath = Join-Path $testDirectory 'Conflict.slnx'
			$dotSettingsPath = Join-Path $testDirectory 'Conflict.sln.DotSettings'
			$slnxDotSettingsPath = Join-Path $testDirectory 'Conflict.slnx.DotSettings'

			[System.IO.File]::WriteAllText($slnxPath, '<Solution />', $utf8)
			[System.IO.File]::WriteAllText($dotSettingsPath, 'source', $utf8)
			[System.IO.File]::WriteAllText($slnxDotSettingsPath, 'destination', $utf8)

			$message = $null

			# Run the convention and capture the expected conflict message.
			try {
				InvokeDotnetSlnxConvention -TestDirectory $testDirectory
			}
			catch {
				$message = $_.Exception.Message
			}

			# Assert the conflict message identifies the blocked rename.
			$message | Should -Match "Cannot rename '.+Conflict\.sln\.DotSettings' because '.+Conflict\.slnx\.DotSettings' already exists\."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

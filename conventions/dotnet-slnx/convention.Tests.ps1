#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'dotnet-slnx convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeDotnetSlnxConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory
		}

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

			Write-Utf8NoBomFile -Path $Path -Content $solutionContent
		}
	}

	It 'migrates solution files and renames matching DotSettings files' {
		$testDirectory = New-TestDirectory

		try {
			$solutionPath = Join-Path $testDirectory 'Test.sln'
			$slnxPath = Join-Path $testDirectory 'Test.slnx'
			$dotSettingsPath = Join-Path $testDirectory 'Test.sln.DotSettings'
			$slnxDotSettingsPath = Join-Path $testDirectory 'Test.slnx.DotSettings'

			SetSolutionFileContent -Path $solutionPath
			Set-Content -LiteralPath $dotSettingsPath -Value 'dotsettings' -Encoding utf8NoBOM

			$output = InvokeDotnetSlnxConvention -TestDirectory $testDirectory

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
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'leaves DotSettings files in place when the corresponding slnx file does not exist' {
		$testDirectory = New-TestDirectory

		try {
			$dotSettingsPath = Join-Path $testDirectory 'Orphan.sln.DotSettings'
			Write-Utf8NoBomFile -Path $dotSettingsPath -Content 'orphan'

			InvokeDotnetSlnxConvention -TestDirectory $testDirectory

			(Test-Path -LiteralPath $dotSettingsPath) | Should -Be $true
			((Get-Content -LiteralPath $dotSettingsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'orphan'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'throws when the destination DotSettings file already exists' {
		$testDirectory = New-TestDirectory

		try {
			$slnxPath = Join-Path $testDirectory 'Conflict.slnx'
			$dotSettingsPath = Join-Path $testDirectory 'Conflict.sln.DotSettings'
			$slnxDotSettingsPath = Join-Path $testDirectory 'Conflict.slnx.DotSettings'

			Write-Utf8NoBomFile -Path $slnxPath -Content '<Solution />'
			Write-Utf8NoBomFile -Path $dotSettingsPath -Content 'source'
			Write-Utf8NoBomFile -Path $slnxDotSettingsPath -Content 'destination'

			$message = $null

			try {
				InvokeDotnetSlnxConvention -TestDirectory $testDirectory
			}
			catch {
				$message = $_.Exception.Message
			}

			$message | Should -Match "Cannot rename '.+Conflict\.sln\.DotSettings' because '.+Conflict\.slnx\.DotSettings' already exists\."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the faithlife-dotnet-library-props convention.
Describe 'faithlife-dotnet-library-props convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention with temporary JSON input for each scenario.
		function script:InvokeFaithlifeDotnetLibraryPropsConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[hashtable] $Settings = @{}
			)

			$inputPath = New-ConventionInputFile -Settings $Settings

			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}
	}

	It 'creates a managed property group from existing repository values and is idempotent' {
		# Set up an MSBuild file with local repository identity and release metadata.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory 'Directory.Build.props'
			[System.IO.File]::WriteAllText($targetPath, @'
<Project>
  <PropertyGroup>
    <VersionPrefix>1.2.3</VersionPrefix>
    <PackageValidationBaselineVersion>1.2.0</PackageValidationBaselineVersion>
    <Nullable>disable</Nullable>
    <NoWarn>$(NoWarn);1591;1998</NoWarn>
    <GitHubOrganization>Faithlife</GitHubOrganization>
    <RepositoryName>Example</RepositoryName>
  </PropertyGroup>
  <PropertyGroup Condition=" '$(BuildNumber)' != '' ">
    <ContinuousIntegrationBuild>true</ContinuousIntegrationBuild>
  </PropertyGroup>
</Project>
'@.Replace("`r`n", "`n"), $utf8)

			# Run the convention and capture the generated managed section.
			$output = InvokeFaithlifeDotnetLibraryPropsConvention -TestDirectory $testDirectory
			$content = Get-Content -LiteralPath $targetPath -Raw

			# Assert local repository properties remain outside the managed section.
			$content | Should -Match '<GitHubOrganization>Faithlife</GitHubOrganization>'
			$content | Should -Match '<RepositoryName>Example</RepositoryName>'
			$content | Should -Match '<ContinuousIntegrationBuild>true</ContinuousIntegrationBuild>'
			$content | Should -Match '(?s)<!-- DO NOT EDIT: faithlife-dotnet-library-props convention -->.*<VersionPrefix>1.2.3</VersionPrefix>.*<PackageValidationBaselineVersion>1.2.0</PackageValidationBaselineVersion>.*<Nullable>disable</Nullable>.*<NoWarn>\$\(NoWarn\);1591;1998</NoWarn>.*<RepositoryUrl>https://github.com/\$\(GitHubOrganization\)/\$\(RepositoryName\)</RepositoryUrl>.*<NuGetAuditLevel>low</NuGetAuditLevel>.*<!-- END DO NOT EDIT -->'
			$output[-1].ToString() | Should -Be "Updated 'faithlife-dotnet-library-props' section in 'Directory.Build.props'."

			# Re-run the convention and assert it is idempotent.
			$secondOutput = InvokeFaithlifeDotnetLibraryPropsConvention -TestDirectory $testDirectory
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be $content
			@($secondOutput).Count | Should -Be 0
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses settings for new repositories and can omit package validation properties' {
		# Set up a minimal MSBuild file that relies on convention settings.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory 'Directory.Build.props'
			[System.IO.File]::WriteAllText($targetPath, "<Project>`n</Project>`n", $utf8)

			# Run the convention with explicit settings for values not present in the file.
			InvokeFaithlifeDotnetLibraryPropsConvention -TestDirectory $testDirectory -Settings @{ 'version-prefix' = '2.0.0'; nullable = 'enable'; 'package-validation' = $false }
			$content = Get-Content -LiteralPath $targetPath -Raw

			# Assert setting values are used and package validation properties are omitted.
			$content | Should -Match '<VersionPrefix>2.0.0</VersionPrefix>'
			$content | Should -Match '<Nullable>enable</Nullable>'
			$content | Should -Not -Match 'PackageValidationBaselineVersion'
			$content | Should -Not -Match 'EnableStrictModeForCompatibleTfms'
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'requires version-prefix when no existing VersionPrefix exists' {
		# Set up a minimal MSBuild file without release metadata.
		$testDirectory = New-TemporaryDirectory

		try {
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'Directory.Build.props'), "<Project>`n</Project>`n", $utf8)

			# Assert missing release metadata is rejected.
			{ InvokeFaithlifeDotnetLibraryPropsConvention -TestDirectory $testDirectory } | Should -Throw "The 'version-prefix' setting is required when Directory.Build.props does not contain VersionPrefix."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

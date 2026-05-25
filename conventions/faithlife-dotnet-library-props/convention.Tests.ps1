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

	It 'creates a managed property group that leaves repository-specific values unmanaged and is idempotent' {
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
			$content | Should -Match '<VersionPrefix>1.2.3</VersionPrefix>'
			$content | Should -Match '<PackageValidationBaselineVersion>1.2.0</PackageValidationBaselineVersion>'
			$content | Should -Match '<NoWarn>\$\(NoWarn\);1591;1998</NoWarn>'
			$content | Should -Match '(?s)<!-- DO NOT EDIT: faithlife-dotnet-library-props convention -->.*<Nullable>enable</Nullable>.*<RepositoryUrl>https://github.com/\$\(GitHubOrganization\)/\$\(RepositoryName\)</RepositoryUrl>.*<EnableStrictModeForCompatibleTfms>true</EnableStrictModeForCompatibleTfms>.*<DisablePackageBaselineValidation Condition=" \$\(PackageValidationBaselineVersion\) == \$\(VersionPrefix\) or \$\(PackageValidationBaselineVersion\) == ''0.0.0'' ">true</DisablePackageBaselineValidation>.*<NuGetAuditLevel>low</NuGetAuditLevel>.*<!-- END DO NOT EDIT -->'
			$content | Should -Not -Match '(?s)<!-- DO NOT EDIT: faithlife-dotnet-library-props convention -->.*<VersionPrefix>'
			$content | Should -Not -Match '(?s)<!-- DO NOT EDIT: faithlife-dotnet-library-props convention -->.*<PackageValidationBaselineVersion>'
			$content | Should -Not -Match '(?s)<!-- DO NOT EDIT: faithlife-dotnet-library-props convention -->.*<NoWarn>'
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

	It 'creates the fixed managed property group in a minimal MSBuild file' {
		# Set up a minimal MSBuild file with no repository-specific properties.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory 'Directory.Build.props'
			[System.IO.File]::WriteAllText($targetPath, "<Project>`n</Project>`n", $utf8)

			# Run the convention with no settings.
			InvokeFaithlifeDotnetLibraryPropsConvention -TestDirectory $testDirectory
			$content = Get-Content -LiteralPath $targetPath -Raw

			# Assert the fixed managed properties are present and repository-specific values are absent.
			$content | Should -Match '<Nullable>enable</Nullable>'
			$content | Should -Match '<EnableStrictModeForCompatibleTfms>true</EnableStrictModeForCompatibleTfms>'
			$content | Should -Match '<DisablePackageBaselineValidation Condition=" \$\(PackageValidationBaselineVersion\) == \$\(VersionPrefix\) or \$\(PackageValidationBaselineVersion\) == ''0.0.0'' ">true</DisablePackageBaselineValidation>'
			$content | Should -Not -Match '<VersionPrefix>'
			$content | Should -Not -Match 'PackageValidationBaselineVersion</PackageValidationBaselineVersion>'
			$content | Should -Not -Match 'NoWarn'
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

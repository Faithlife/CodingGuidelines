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
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Configure a temporary repository to apply the packaged props convention.
		function script:InitializePropsConventionTestRepository {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			Copy-TestConventionAssets -TestDirectory $TestDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $TestDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $TestDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/faithlife-dotnet-library-props
"@, $utf8)
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

			# Apply the packaged convention and capture the generated managed section.
			InitializePropsConventionTestRepository -TestDirectory $testDirectory
			Initialize-TestRepository -Path $testDirectory
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
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

			# Re-run the packaged convention and assert it is idempotent.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be $content
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
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

			# Apply the packaged convention with no settings.
			InitializePropsConventionTestRepository -TestDirectory $testDirectory
			Initialize-TestRepository -Path $testDirectory
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
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

	It 'commits Directory.Build.props changes with the packaged commit message' {
		# Set up a minimal repository that needs the props convention.
		$testDirectory = New-TemporaryDirectory

		try {
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'Directory.Build.props'), "<Project>`n</Project>`n", $utf8)
			InitializePropsConventionTestRepository -TestDirectory $testDirectory
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and allow RepoConventions to create the packaged commit.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the commit message and clean working tree match expectations.
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Update Directory.Build.props for .NET library'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the dotnet-common-props convention.
Describe 'dotnet-common-props convention' {
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
- path: ../conventions/dotnet-common-props
"@, $utf8)
		}
	}

	It 'creates a managed property group that leaves repository-specific values unmanaged and is idempotent' {
		# Set up MSBuild files with local repository identity, release metadata, and repository-owned package versions.
		$testDirectory = New-TemporaryDirectory

		try {
			$buildPropsPath = Join-Path $testDirectory 'Directory.Build.props'
			[System.IO.File]::WriteAllText($buildPropsPath, @'
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
			$packagePropsPath = Join-Path $testDirectory 'Directory.Packages.props'
			[System.IO.File]::WriteAllText($packagePropsPath, @'
<Project>
  <ItemGroup>
    <PackageVersion Include="Example" Version="1.0.0" />
  </ItemGroup>
</Project>
'@.Replace("`r`n", "`n"), $utf8)

			# Apply the packaged convention and capture the generated managed sections.
			InitializePropsConventionTestRepository -TestDirectory $testDirectory
			Initialize-TestRepository -Path $testDirectory
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
			$buildPropsContent = Get-Content -LiteralPath $buildPropsPath -Raw
			$packagePropsContent = Get-Content -LiteralPath $packagePropsPath -Raw

			# Assert local repository properties remain outside the managed build props section.
			$buildPropsContent | Should -Match '<GitHubOrganization>Faithlife</GitHubOrganization>'
			$buildPropsContent | Should -Match '<RepositoryName>Example</RepositoryName>'
			$buildPropsContent | Should -Match '<ContinuousIntegrationBuild>true</ContinuousIntegrationBuild>'
			$buildPropsContent | Should -Match '<VersionPrefix>1.2.3</VersionPrefix>'
			$buildPropsContent | Should -Match '<PackageValidationBaselineVersion>1.2.0</PackageValidationBaselineVersion>'
			$buildPropsContent | Should -Match '<NoWarn>\$\(NoWarn\);1591;1998</NoWarn>'
			$buildPropsContent | Should -Match ([regex]::Escape('<PackageProjectUrl Condition=" ''$(PackageProjectUrl)'' == '''' ">https://github.com/$(GitHubOrganization)/$(RepositoryName)</PackageProjectUrl>'))
			$buildPropsContent | Should -Match ([regex]::Escape('<PackageReleaseNotes Condition=" ''$(PackageReleaseNotes)'' == '''' ">https://github.com/$(GitHubOrganization)/$(RepositoryName)/blob/master/ReleaseNotes.md</PackageReleaseNotes>'))
			$buildPropsContent | Should -Match ([regex]::Escape('<Authors Condition=" ''$(Authors)'' == '''' ">$(GitHubOrganization)</Authors>'))
			$buildPropsContent | Should -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props convention -->.*<Nullable>enable</Nullable>.*<RepositoryUrl>https://github.com/\$\(GitHubOrganization\)/\$\(RepositoryName\)\.git</RepositoryUrl>.*<EnableStrictModeForCompatibleTfms>true</EnableStrictModeForCompatibleTfms>.*<DisablePackageBaselineValidation Condition=" \$\(PackageValidationBaselineVersion\) == \$\(VersionPrefix\) or \$\(PackageValidationBaselineVersion\) == ''0.0.0'' ">true</DisablePackageBaselineValidation>.*<NuGetAuditLevel>low</NuGetAuditLevel>.*<!-- END DO NOT EDIT -->'
			$buildPropsContent | Should -Not -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props convention -->.*<VersionPrefix>'
			$buildPropsContent | Should -Not -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props convention -->.*<PackageValidationBaselineVersion>'
			$buildPropsContent | Should -Not -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props convention -->.*<NoWarn>'
			$buildPropsContent | Should -Not -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props convention -->.*<PackageLicenseExpression>'

			# Assert repository-owned package versions remain outside the managed package props sections.
			$packagePropsContent | Should -Match '<PackageVersion Include="Example" Version="1.0.0" />'
			$packagePropsContent | Should -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props/properties convention -->.*<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>.*<CentralPackageFloatingVersionsEnabled>true</CentralPackageFloatingVersionsEnabled>.*<!-- END DO NOT EDIT -->'
			$packagePropsContent | Should -Match '(?s)<!-- DO NOT EDIT: dotnet-common-props/analyzers convention -->.*<GlobalPackageReference Include="Faithlife.Analyzers" Version="1\.\*" />.*<GlobalPackageReference Include="NUnit.Analyzers" Version="4\.\*" />.*<GlobalPackageReference Include="StyleCop.Analyzers" Version="1\.\*-\*" />.*<!-- END DO NOT EDIT -->'

			# Re-run the packaged convention and assert it is idempotent.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
			(Get-Content -LiteralPath $buildPropsPath -Raw) | Should -Be $buildPropsContent
			(Get-Content -LiteralPath $packagePropsPath -Raw) | Should -Be $packagePropsContent
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
			$buildPropsPath = Join-Path $testDirectory 'Directory.Build.props'
			$packagePropsPath = Join-Path $testDirectory 'Directory.Packages.props'
			[System.IO.File]::WriteAllText($buildPropsPath, "<Project>`n</Project>`n", $utf8)
			[System.IO.File]::WriteAllText($packagePropsPath, "<Project>`n</Project>`n", $utf8)

			# Apply the packaged convention with no settings.
			InitializePropsConventionTestRepository -TestDirectory $testDirectory
			Initialize-TestRepository -Path $testDirectory
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
			$buildPropsContent = Get-Content -LiteralPath $buildPropsPath -Raw
			$packagePropsContent = Get-Content -LiteralPath $packagePropsPath -Raw

			# Assert the fixed managed properties are present and repository-specific values are absent.
			$buildPropsContent | Should -Match '<Nullable>enable</Nullable>'
			$buildPropsContent | Should -Match ([regex]::Escape('<Authors Condition=" ''$(Authors)'' == '''' ">$(GitHubOrganization)</Authors>'))
			$buildPropsContent | Should -Match '<EnableStrictModeForCompatibleTfms>true</EnableStrictModeForCompatibleTfms>'
			$buildPropsContent | Should -Match '<DisablePackageBaselineValidation Condition=" \$\(PackageValidationBaselineVersion\) == \$\(VersionPrefix\) or \$\(PackageValidationBaselineVersion\) == ''0.0.0'' ">true</DisablePackageBaselineValidation>'
			$buildPropsContent | Should -Not -Match '<VersionPrefix>'
			$buildPropsContent | Should -Not -Match 'PackageValidationBaselineVersion</PackageValidationBaselineVersion>'
			$buildPropsContent | Should -Not -Match 'NoWarn'
			$buildPropsContent | Should -Not -Match '<PackageLicenseExpression>'
			$packagePropsContent | Should -Match '<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>'
			$packagePropsContent | Should -Match '<GlobalPackageReference Include="Faithlife.Analyzers" Version="1\.\*" />'
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
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'Directory.Packages.props'), "<Project>`n</Project>`n", $utf8)
			InitializePropsConventionTestRepository -TestDirectory $testDirectory
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and allow RepoConventions to create the packaged commit.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the commit message and clean working tree match expectations.
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Update .NET library props'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

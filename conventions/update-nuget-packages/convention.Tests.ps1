#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'update-nuget-packages convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:WriteTestFile {
			param(
				[Parameter(Mandatory = $true)]
				[string] $Path,

				[Parameter(Mandatory = $true)]
				[string] $Content
			)

			$directory = Split-Path -Parent $Path
			if (-not [string]::IsNullOrWhiteSpace($directory)) {
				New-Item -ItemType Directory -Path $directory -Force | Out-Null
			}

			[System.IO.File]::WriteAllText($Path, $Content, $utf8)
		}

		function script:WriteMetadataFile {
			param(
				[Parameter(Mandatory = $true)]
				[hashtable] $Packages
			)

			$metadataPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
			@{ packages = $Packages } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metadataPath -Encoding utf8NoBOM
			return $metadataPath
		}

		function script:WriteLocalPackage {
			param(
				[Parameter(Mandatory = $true)]
				[string] $SourceDirectory,

				[Parameter(Mandatory = $true)]
				[string] $PackageId,

				[Parameter(Mandatory = $true)]
				[string] $Version
			)

			New-Item -ItemType Directory -Path $SourceDirectory -Force | Out-Null
			$nupkgPath = Join-Path $SourceDirectory "$PackageId.$Version.nupkg"
			$archive = [System.IO.Compression.ZipFile]::Open($nupkgPath, [System.IO.Compression.ZipArchiveMode]::Create)
			try {
				$entry = $archive.CreateEntry("$PackageId.nuspec")
				$writer = [System.IO.StreamWriter]::new($entry.Open(), $utf8)
				try {
					$writer.Write("<?xml version=`"1.0`"?><package><metadata><id>$PackageId</id><version>$Version</version><authors>Test</authors><description>Test package</description></metadata></package>")
				}
				finally {
					$writer.Dispose()
				}
			}
			finally {
				$archive.Dispose()
			}
		}

		function script:InvokeUpdateNugetPackagesConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[Parameter(Mandatory = $true)]
				[hashtable] $Settings
			)

			$inputPath = New-ConventionInputFile -Settings $Settings
			$previousTestMode = [Environment]::GetEnvironmentVariable('UPDATE_NUGET_PACKAGES_TEST_MODE', 'Process')

			Push-Location $TestDirectory
			try {
				[Environment]::SetEnvironmentVariable('UPDATE_NUGET_PACKAGES_TEST_MODE', '1', 'Process')
				return @(& $script:conventionScriptPath $inputPath 3>&1 6>&1)
			}
			finally {
				Pop-Location
				[Environment]::SetEnvironmentVariable('UPDATE_NUGET_PACKAGES_TEST_MODE', $previousTestMode, 'Process')
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}

		function script:AddAndCommitAll {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[Parameter(Mandatory = $true)]
				[string] $Message
			)

			Push-Location $TestDirectory
			try {
				& git add -A
				& git commit -m $Message | Out-Null
			}
			finally {
				Pop-Location
			}
		}

		function script:AddAndCommitPaths {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[Parameter(Mandatory = $true)]
				[string[]] $Paths,

				[Parameter(Mandatory = $true)]
				[string] $Message
			)

			Push-Location $TestDirectory
			try {
				& git add -- $Paths
				& git commit -m $Message | Out-Null
			}
			finally {
				Pop-Location
			}
		}
	}

	It 'updates tracked package references and dotnet tools without touching untracked files' {
		$testDirectory = New-TemporaryDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$projectPath = Join-Path $testDirectory 'src' 'App' 'App.csproj'
			$toolManifestPath = Join-Path $testDirectory '.config' 'dotnet-tools.json'
			$untrackedProjectPath = Join-Path $testDirectory 'scratch' 'Scratch.csproj'

			WriteTestFile -Path $projectPath -Content @'
<Project>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="12.0.1" />
    <PackageReference Include="Floating.Package" Version="1.*" />
  </ItemGroup>
</Project>
'@
			WriteTestFile -Path $toolManifestPath -Content @'
{
  "version": 1,
  "isRoot": true,
  "tools": {
    "dotnet-format": {
      "version": "5.0.0",
      "commands": ["dotnet-format"]
    }
  }
}
'@
			AddAndCommitAll -TestDirectory $testDirectory -Message 'Add package files'
			WriteTestFile -Path $untrackedProjectPath -Content @'
<Project>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="12.0.1" />
  </ItemGroup>
</Project>
'@

			$metadataPath = WriteMetadataFile -Packages @{
				'Newtonsoft.Json' = @(
					@{ version = '13.0.1'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true },
					@{ version = '13.0.2'; publishedUtc = '2026-05-20T00:00:00Z'; listed = $true }
				)
				'dotnet-format' = @(
					@{ version = '6.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true }
				)
			}

			$output = InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'test-package-metadata-file' = $metadataPath
				'now-utc' = '2026-05-27T12:00:00Z'
			}
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $projectPath -Raw) | Should -Match 'Version="13\.0\.1"'
			(Get-Content -LiteralPath $projectPath -Raw) | Should -Match 'Version="1\.\*"'
			(Get-Content -LiteralPath $toolManifestPath -Raw) | Should -Match '"version": "6\.0\.0"'
			(Get-Content -LiteralPath $untrackedProjectPath -Raw) | Should -Match 'Version="12\.0\.1"'
			$status | Should -Contain ' M .config/dotnet-tools.json'
			$status | Should -Contain ' M src/App/App.csproj'
			(@($output | ForEach-Object { $_.ToString() }) -join "`n") | Should -Be "2 packages updated:`n- dotnet-format 6.0.0 (from 5.0.0)`n- Newtonsoft.Json 13.0.1 (from 12.0.1)"

			AddAndCommitPaths -TestDirectory $testDirectory -Paths @('.config/dotnet-tools.json', 'src/App/App.csproj') -Message 'Update package files'
			$secondOutput = InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'test-package-metadata-file' = $metadataPath
				'now-utc' = '2026-05-27T12:00:00Z'
			}

			$secondStatus = @(Get-GitStatusLines -TestDirectory $testDirectory)
			@($secondOutput).Count | Should -Be 0
			$secondStatus.Count | Should -Be 1
			$secondStatus[0] | Should -Match '^\?\? scratch/'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'honors version and prerelease rules' {
		$testDirectory = New-TemporaryDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$projectPath = Join-Path $testDirectory 'Directory.Packages.props'
			WriteTestFile -Path $projectPath -Content @'
<Project>
  <ItemGroup>
    <PackageVersion Include="Major.Package" Version="1.0.0" />
    <PackageVersion Include="Minor.Package" Version="1.0.0" />
    <PackageVersion Include="Patch.Package" Version="1.2.0" />
    <PackageVersion Include="Pinned.Package" Version="6.0.0" />
		<PackageVersion Include="Range.Package" Version="6.0.0" />
    <PackageVersion Include="No.Package" Version="1.0.0" />
    <PackageVersion Include="Pre.Package" Version="1.0.0" />
    <PackageVersion Include="NoPre.Package" Version="1.0.0" />
  </ItemGroup>
</Project>
'@

			AddAndCommitAll -TestDirectory $testDirectory -Message 'Add packages props'
			$metadataPath = WriteMetadataFile -Packages @{
				'Major.Package' = @(@{ version = '2.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'Minor.Package' = @(
					@{ version = '1.1.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true },
					@{ version = '2.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true }
				)
				'Patch.Package' = @(
					@{ version = '1.2.2'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true },
					@{ version = '1.3.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true }
				)
				'Pinned.Package' = @(
					@{ version = '7.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true },
					@{ version = '8.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true }
				)
				'Range.Package' = @(
					@{ version = '7.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true },
					@{ version = '7.5.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true },
					@{ version = '8.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true }
				)
				'No.Package' = @(@{ version = '9.0.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'Pre.Package' = @(@{ version = '2.0.0-alpha.1'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'NoPre.Package' = @(@{ version = '2.0.0-alpha.1'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
			}

			InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'test-package-metadata-file' = $metadataPath
				'now-utc' = '2026-05-27T12:00:00Z'
				rules = @(
					@{ packages = 'Minor.Package'; version = 'update-minor' },
					@{ packages = 'Patch.Package'; version = 'update-patch' },
					@{ packages = 'Pinned.Package'; version = '7.0.0' },
					@{ packages = 'Range.Package'; version = '[7.0.0, 8.0.0)' },
					@{ packages = 'No.Package'; version = 'no-update' },
					@{ packages = 'Pre.Package'; 'include-prerelease' = $true; 'prerelease-channel' = 'alpha' }
				)
			} | Out-Null

			$content = Get-Content -LiteralPath $projectPath -Raw
			$content | Should -Match 'Include="Major\.Package" Version="2\.0\.0"'
			$content | Should -Match 'Include="Minor\.Package" Version="1\.1\.0"'
			$content | Should -Match 'Include="Patch\.Package" Version="1\.2\.2"'
			$content | Should -Match 'Include="Pinned\.Package" Version="7\.0\.0"'
			$content | Should -Match 'Include="Range\.Package" Version="7\.5\.0"'
			$content | Should -Match 'Include="No\.Package" Version="1\.0\.0"'
			$content | Should -Match 'Include="Pre\.Package" Version="2\.0\.0-alpha\.1"'
			$content | Should -Match 'Include="NoPre\.Package" Version="1\.0\.0"'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates UTF-8 BOM XML project files' {
		$testDirectory = New-TemporaryDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$projectPath = Join-Path $testDirectory 'src' 'AppHost' 'AppHost.csproj'
			New-Item -ItemType Directory -Path (Split-Path -Parent $projectPath) -Force | Out-Null
			$utf8Bom = [System.Text.UTF8Encoding]::new($true)
			[System.IO.File]::WriteAllText($projectPath, @'
<Project>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="12.0.1" />
  </ItemGroup>
</Project>
'@, $utf8Bom)

			AddAndCommitAll -TestDirectory $testDirectory -Message 'Add BOM project file'
			$metadataPath = WriteMetadataFile -Packages @{
				'Newtonsoft.Json' = @(@{ version = '13.0.1'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
			}

			InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'test-package-metadata-file' = $metadataPath
				'now-utc' = '2026-05-27T12:00:00Z'
			} | Out-Null

			(Get-Content -LiteralPath $projectPath -Raw) | Should -Match 'Version="13\.0\.1"'
			$bytes = [System.IO.File]::ReadAllBytes($projectPath)
			$bytes[0] | Should -Be 0xEF
			$bytes[1] | Should -Be 0xBB
			$bytes[2] | Should -Be 0xBF
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses Tuesday as the publish cooldown boundary' {
		$testDirectory = New-TemporaryDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$projectPath = Join-Path $testDirectory 'App.csproj'
			WriteTestFile -Path $projectPath -Content @'
<Project>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="12.0.1" />
  </ItemGroup>
</Project>
'@

			AddAndCommitAll -TestDirectory $testDirectory -Message 'Add project file'
			$metadataPath = WriteMetadataFile -Packages @{
				'Newtonsoft.Json' = @(
					@{ version = '12.0.2'; publishedUtc = '2026-05-17T00:00:00Z'; listed = $true },
					@{ version = '13.0.0'; publishedUtc = '2026-05-19T00:00:00Z'; listed = $true },
					@{ version = '13.0.1'; publishedUtc = '2026-05-20T00:00:00Z'; listed = $true }
				)
			}

			InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'test-package-metadata-file' = $metadataPath
				'now-utc' = '2026-05-27T12:00:00Z'
			} | Out-Null

			$content = Get-Content -LiteralPath $projectPath -Raw
			$content | Should -Match 'Version="13\.0\.0"'
			$content | Should -Not -Match 'Version="13\.0\.1"'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates same-file properties and MSBuild SDK references' {
		$testDirectory = New-TemporaryDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$projectPath = Join-Path $testDirectory 'Directory.Build.props'
			WriteTestFile -Path $projectPath -Content @'
<Project Sdk="Proj.Sdk/1.0.0;Other.Sdk/2.0.0">
  <PropertyGroup>
    <NewtonsoftJsonVersion>12.0.1</NewtonsoftJsonVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Newtonsoft.Json" Version="$(NewtonsoftJsonVersion)" />
  </ItemGroup>
  <Import Project="Sdk.props" Sdk="Import.Sdk" Version="3.0.0" />
  <Sdk Name="Element.Sdk" Version="4.0.0" />
</Project>
'@

			AddAndCommitAll -TestDirectory $testDirectory -Message 'Add build props'
			$metadataPath = WriteMetadataFile -Packages @{
				'Newtonsoft.Json' = @(@{ version = '13.0.1'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'Proj.Sdk' = @(@{ version = '1.1.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'Other.Sdk' = @(@{ version = '2.1.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'Import.Sdk' = @(@{ version = '3.1.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
				'Element.Sdk' = @(@{ version = '4.1.0'; publishedUtc = '2026-05-10T00:00:00Z'; listed = $true })
			}

			InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'test-package-metadata-file' = $metadataPath
				'now-utc' = '2026-05-27T12:00:00Z'
			} | Out-Null

			$content = Get-Content -LiteralPath $projectPath -Raw
			$content | Should -Match '<NewtonsoftJsonVersion>13\.0\.1</NewtonsoftJsonVersion>'
			$content | Should -Match 'Sdk="Proj\.Sdk/1\.1\.0;Other\.Sdk/2\.1\.0"'
			$content | Should -Match 'Sdk="Import\.Sdk" Version="3\.1\.0"'
			$content | Should -Match 'Name="Element\.Sdk" Version="4\.1\.0"'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses package sources from nuget.config' {
		$testDirectory = New-TemporaryDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$packageSourcePath = Join-Path $testDirectory 'packages'
			$nugetConfigPath = Join-Path $testDirectory 'nuget.config'
			$projectPath = Join-Path $testDirectory 'App.csproj'

			WriteLocalPackage -SourceDirectory $packageSourcePath -PackageId 'Local.Package' -Version '1.1.0'
			WriteTestFile -Path $nugetConfigPath -Content @"
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$packageSourcePath" />
  </packageSources>
</configuration>
"@
			WriteTestFile -Path $projectPath -Content @'
<Project>
  <ItemGroup>
    <PackageReference Include="Local.Package" Version="1.0.0" />
  </ItemGroup>
</Project>
'@

			AddAndCommitAll -TestDirectory $testDirectory -Message 'Add local package source'

			InvokeUpdateNugetPackagesConvention -TestDirectory $testDirectory -Settings @{
				'now-utc' = '2026-05-27T12:00:00Z'
			} | Out-Null

			(Get-Content -LiteralPath $projectPath -Raw) | Should -Match 'Version="1\.1\.0"'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

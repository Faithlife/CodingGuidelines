#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'nuget-config convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedNuGetConfigPath = Join-Path $PSScriptRoot 'files' 'nuget.config'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeNuGetConfigConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			$inputPath = New-ConventionInputFile -Settings @{}

			Push-Location $TestDirectory
			try {
				return @(& $script:conventionScriptPath $inputPath 3>&1 6>&1)
			}
			finally {
				Pop-Location
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}
	}

	It 'creates nuget.config when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$nuGetConfigPath = Join-Path $testDirectory 'nuget.config'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $nuGetConfigPath) | Should -Be $true
			(Get-Content -LiteralPath $nuGetConfigPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedNuGetConfigPath -Raw)
			((Get-Content -LiteralPath $nuGetConfigPath -Raw) -match 'protocolVersion=') | Should -Be $false
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^\?\? nuget\.config$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$nuGetConfigPath' from the published NuGet config.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'renames an existing non-lowercase NuGet config to nuget.config' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$originalNuGetConfigPath = Join-Path $testDirectory 'NuGet.Config'
			$expectedContent = Get-Content -LiteralPath $expectedNuGetConfigPath -Raw
			Write-Utf8NoBomFile -Path $originalNuGetConfigPath -Content $expectedContent

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add NuGet.Config' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$nuGetConfigPath = Join-Path $testDirectory 'nuget.config'
			$nuGetConfigNames = @(Get-ChildItem -LiteralPath $testDirectory -File | Where-Object { $_.Name -ieq 'nuget.config' } | Select-Object -ExpandProperty Name)

			$nuGetConfigNames.Count | Should -Be 1
			$nuGetConfigNames[0] | Should -Be 'nuget.config'
			(Get-Content -LiteralPath $nuGetConfigPath -Raw) | Should -Be $expectedContent
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$nuGetConfigPath' already matches the published NuGet config.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'replaces an existing different nuget.config' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$nuGetConfigPath = Join-Path $testDirectory 'nuget.config'
			$existingContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
"@
			Write-Utf8NoBomFile -Path $nuGetConfigPath -Content $existingContent

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add existing nuget config' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $nuGetConfigPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedNuGetConfigPath -Raw)
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^ M nuget\.config$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Replaced '$nuGetConfigPath' with the published NuGet config.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			InvokeNuGetConfigConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add nuget config' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			$nuGetConfigPath = Join-Path $testDirectory 'nuget.config'
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$nuGetConfigPath' already matches the published NuGet config.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

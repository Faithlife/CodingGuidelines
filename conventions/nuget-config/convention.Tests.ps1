Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$expectedNuGetConfigPath = Join-Path $PSScriptRoot 'nuget.config'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeNuGetConfigConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	$inputPath = New-ConventionInputFile -Settings @{}

	Push-Location $TestDirectory
	try {
		return @(& $conventionScriptPath $inputPath 3>&1 6>&1)
	}
	finally {
		Pop-Location
		Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
	}
}

Describe 'nuget-config convention' {
	It 'creates nuget.config when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$nuGetConfigPath = Join-Path $testDirectory 'nuget.config'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $nuGetConfigPath) | Should Be $true
			(Get-Content -LiteralPath $nuGetConfigPath -Raw) | Should Be (Get-Content -LiteralPath $expectedNuGetConfigPath -Raw)
			((Get-Content -LiteralPath $nuGetConfigPath -Raw) -match 'protocolVersion=') | Should Be $false
			$status.Count | Should Be 1
			$status[0] | Should Match '^\?\? nuget\.config$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$nuGetConfigPath' from the published NuGet config.") | Should Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'warns and leaves an existing different nuget.config unchanged' {
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
				& git commit -m 'Add existing nuget config.' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $nuGetConfigPath -Raw) | Should Be $existingContent
			$status.Count | Should Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "Existing '$nuGetConfigPath' does not match the published NuGet config; leaving it unchanged.") | Should Be $true
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
				& git commit -m 'Add nuget config.' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeNuGetConfigConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should Be $headAfterFirstRun
			$status.Count | Should Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$($testDirectory)\nuget.config' already matches the published NuGet config.") | Should Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

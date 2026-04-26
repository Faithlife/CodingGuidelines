#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'faithlife-build-script convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedBuildScriptPath = Join-Path $PSScriptRoot 'files\build.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeFaithlifeBuildScriptConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			$inputPath = New-ConventionInputFile -Settings @{}

			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}

		function script:GetBuildScriptIndexMode {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			Push-Location $TestDirectory
			try {
				[string[]] $indexLines = @(& git ls-files --stage -- build.ps1)

				if ($indexLines.Count -eq 0) {
					return $null
				}

				return ($indexLines[0] -split '\s+', 2)[0]
			}
			finally {
				Pop-Location
			}
		}
	}

	It 'creates build.ps1 in the repository root and marks it executable in Git' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeFaithlifeBuildScriptConvention -TestDirectory $testDirectory
			$buildScriptPath = Join-Path $testDirectory 'build.ps1'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $buildScriptPath) | Should -Be $true
			(Get-Content -LiteralPath $buildScriptPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedBuildScriptPath -Raw)
			(GetBuildScriptIndexMode -TestDirectory $testDirectory) | Should -Be '100755'
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^A\s\sbuild\.ps1$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Marked 'build.ps1' as executable in Git.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates an existing build.ps1 to the published script' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$buildScriptPath = Join-Path $testDirectory 'build.ps1'
			Write-Utf8NoBomFile -Path $buildScriptPath -Content "Write-Host 'placeholder'`n"

			Push-Location $testDirectory
			try {
				& git add -- build.ps1
				& git commit -m 'Add placeholder build script' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeFaithlifeBuildScriptConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $buildScriptPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedBuildScriptPath -Raw)
			(GetBuildScriptIndexMode -TestDirectory $testDirectory) | Should -Be '100755'
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^M\s\sbuild\.ps1$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Updated '$buildScriptPath' from the published Faithlife build script.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			InvokeFaithlifeBuildScriptConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git commit -m 'Add build script' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeFaithlifeBuildScriptConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "'build.ps1' already matches the published Faithlife build script and is executable in Git.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

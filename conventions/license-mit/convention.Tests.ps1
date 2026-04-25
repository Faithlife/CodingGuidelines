#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$templateLicensePath = Join-Path $PSScriptRoot 'files\LICENSE'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeLicenseMitConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	$inputPath = New-ConventionInputFile -Settings @{}

	try {
		return Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
	}
	finally {
		Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
	}
}

function GetExpectedLicenseText {
	$templateContent = Get-Content -LiteralPath $templateLicensePath -Raw
	$currentUtcYear = [DateTime]::UtcNow.Year.ToString([System.Globalization.CultureInfo]::InvariantCulture)
	return $templateContent.Replace('<YEAR>', $currentUtcYear)
}

Describe 'license-mit convention' {
	It 'creates LICENSE when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory
			$licensePath = Join-Path $testDirectory 'LICENSE'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $licensePath) | Should Be $true
			(Get-Content -LiteralPath $licensePath -Raw) | Should Be (GetExpectedLicenseText)
			((Get-Content -LiteralPath $licensePath -Raw) -match '<YEAR>') | Should Be $false
			$status.Count | Should Be 1
			$status[0] | Should Match '^\?\? LICENSE$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$licensePath' from the published MIT license.") | Should Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'replaces an existing LICENSE when it differs' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$licensePath = Join-Path $testDirectory 'LICENSE'
			Write-Utf8NoBomFile -Path $licensePath -Content "Old license text`n"

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add old license.' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $licensePath -Raw) | Should Be (GetExpectedLicenseText)
			$status.Count | Should Be 1
			$status[0] | Should Match '^ M LICENSE$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Replaced '$licensePath' with the published MIT license.") | Should Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			InvokeLicenseMitConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add MIT license.' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should Be $headAfterFirstRun
			$status.Count | Should Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$($testDirectory)\LICENSE' already matches the published MIT license.") | Should Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'license-mit convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:templateLicensePath = Join-Path $PSScriptRoot 'files\LICENSE'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		$script:defaultCopyrightHolder = 'Faithlife'
		. $script:testHelpersPath

		function script:InvokeLicenseMitConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[string] $CopyrightHolder
			)

			$settings = @{}

			if ($PSBoundParameters.ContainsKey('CopyrightHolder')) {
				$settings['copyright-holder'] = $CopyrightHolder
			}

			$inputPath = New-ConventionInputFile -Settings $settings

			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}

		function script:GetExpectedLicenseText {
			param(
				[Parameter(Mandatory = $true)]
				[string] $CopyrightHolder
			)

			$templateContent = Get-Content -LiteralPath $script:templateLicensePath -Raw
			$currentUtcYear = [DateTime]::UtcNow.Year.ToString([System.Globalization.CultureInfo]::InvariantCulture)
			return $templateContent.Replace('<YEAR>', $currentUtcYear).Replace('<COPYRIGHT-HOLDER>', $CopyrightHolder)
		}
	}

	It 'requires the copyright-holder setting' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			{ InvokeLicenseMitConvention -TestDirectory $testDirectory } | Should -Throw "The 'copyright-holder' setting is required."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'creates LICENSE when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder $script:defaultCopyrightHolder
			$licensePath = Join-Path $testDirectory 'LICENSE'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $licensePath) | Should -Be $true
			(Get-Content -LiteralPath $licensePath -Raw) | Should -Be (GetExpectedLicenseText -CopyrightHolder $script:defaultCopyrightHolder)
			((Get-Content -LiteralPath $licensePath -Raw) -match '<YEAR>') | Should -Be $false
			((Get-Content -LiteralPath $licensePath -Raw) -match '<COPYRIGHT-HOLDER>') | Should -Be $false
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^\?\? LICENSE$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Created '$licensePath' from the published MIT license.") | Should -Be $true
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
				& git commit -m 'Add old license' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder 'Contoso'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Get-Content -LiteralPath $licensePath -Raw) | Should -Be (GetExpectedLicenseText -CopyrightHolder 'Contoso')
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^ M LICENSE$'
			(@($output | ForEach-Object { $_.ToString() }) -contains "Replaced '$licensePath' with the published MIT license.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder $script:defaultCopyrightHolder | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add MIT license' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder $script:defaultCopyrightHolder
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			$expectedLicensePath = Join-Path $testDirectory 'LICENSE'
		(@($output | ForEach-Object { $_.ToString() }) -contains "'$expectedLicensePath' already matches the published MIT license.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

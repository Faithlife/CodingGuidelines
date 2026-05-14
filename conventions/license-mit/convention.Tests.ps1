#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'license-mit convention' {
	BeforeAll {
		# Cache convention paths, defaults, and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:templateLicensePath = Join-Path $PSScriptRoot 'files' 'LICENSE'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		$script:defaultCopyrightHolder = 'Faithlife'
		. $script:testHelpersPath

		function script:InvokeLicenseMitConvention {
			# Invoke the convention script with optional copyright settings.
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
			# Render the template license text for the current UTC year.
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
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an empty initialized repository.
			Initialize-TestRepository -Path $testDirectory

			# Assert the convention fails without the required setting.
			{ InvokeLicenseMitConvention -TestDirectory $testDirectory } | Should -Throw "The 'copyright-holder' setting is required."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'creates LICENSE when it is missing' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an empty initialized repository.
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention and collect the created license state.
			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder $script:defaultCopyrightHolder
			$licensePath = Join-Path $testDirectory 'LICENSE'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the rendered MIT license was created and reported.
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
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with a committed non-template license.
			Initialize-TestRepository -Path $testDirectory
			$licensePath = Join-Path $testDirectory 'LICENSE'
			[System.IO.File]::WriteAllText($licensePath, "Old license text`n", $utf8)

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add old license' | Out-Null
			}
			finally {
				Pop-Location
			}

			# Apply the convention with a replacement copyright holder.
			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder 'Contoso'
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the existing license was replaced and reported.
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
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository after a successful first convention run.
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

			# Apply the convention a second time and capture repository state.
			$output = InvokeLicenseMitConvention -TestDirectory $testDirectory -CopyrightHolder $script:defaultCopyrightHolder
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the second run reported no content changes.
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

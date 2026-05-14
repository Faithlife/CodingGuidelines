#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'prettierignore-section convention' {
	BeforeAll {
		# Cache convention paths and load shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokePrettierignoreSectionConvention {
			# Invoke the convention script with caller-provided section settings.
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[Parameter(Mandatory = $true)]
				[hashtable] $Settings
			)

			$inputPath = New-ConventionInputFile -Settings $Settings

			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}

		function script:GetDefaultSettings {
			# Provide the default managed section used by most scenarios.
			return @{
				name = 'build-output'
				text = "coverage/`ndist/"
			}
		}
	}

	It 'does nothing when Prettier is not detected' {
		$testDirectory = New-TestDirectory

		try {
			# Apply the convention in a directory without Prettier markers.
			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)
			$prettierignorePath = Join-Path $testDirectory '.prettierignore'

			# Assert no prettierignore file was created.
			(Test-Path -LiteralPath $prettierignorePath) | Should -Be $false
			$output[-1].ToString() | Should -Be "Prettier was not detected; leaving '.prettierignore' unchanged."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when .prettierignore already exists and is idempotent' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange an existing prettierignore file.
			$prettierignorePath = Join-Path $testDirectory '.prettierignore'
			Write-Utf8NoBomFile -Path $prettierignorePath -Content "existing-entry/`n"

			# Apply the convention once and assert it appends the managed section.
			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)

			(Get-Content -LiteralPath $prettierignorePath -Raw) | Should -Be "existing-entry/`n`n# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should -Be "Updated 'build-output' section in '.prettierignore'."

			# Apply the convention again and assert it reports idempotence.
			$secondOutput = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)

			(Get-Content -LiteralPath $prettierignorePath -Raw) | Should -Be "existing-entry/`n`n# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
			$secondOutput[-1].ToString() | Should -Be "'.prettierignore' already contains the 'build-output' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when .prettierrc exists' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a Prettier config marker file.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.prettierrc') -Content "{}"

			# Apply the convention after Prettier detection succeeds.
			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			# Assert the configured section was written to prettierignore.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when prettier.config.js exists' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a JavaScript Prettier config marker file.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'prettier.config.js') -Content "module.exports = {};`n"

			# Apply the convention after Prettier detection succeeds.
			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			# Assert the configured section was written to prettierignore.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when package.json has a top-level prettier property' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a package manifest with top-level Prettier settings.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{"prettier":{"singleQuote":true}}'

			# Apply the convention after Prettier detection succeeds.
			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			# Assert the configured section was written to prettierignore.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when package.json has a prettier devDependency' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a package manifest with a Prettier dev dependency.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{"devDependencies":{"prettier":"^3.0.0"}}'

			# Apply the convention after Prettier detection succeeds.
			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			# Assert the configured section was written to prettierignore.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not treat a lockfile-only transitive prettier reference as detection' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a lockfile-only transitive Prettier reference.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package-lock.json') -Content '{"packages":{"node_modules/prettier":{"version":"3.0.0"}}}'

			# Apply the convention where direct Prettier detection should fail.
			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)

			# Assert no prettierignore file was created.
			(Test-Path -LiteralPath (Join-Path $testDirectory '.prettierignore')) | Should -Be $false
			$output[-1].ToString() | Should -Be "Prettier was not detected; leaving '.prettierignore' unchanged."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'fails clearly when package.json is malformed' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a malformed package manifest.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{'

			# Assert malformed JSON is reported during Prettier detection.
			{ InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) } | Should -Throw "Failed to parse 'package.json' while detecting Prettier."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes through configured section settings to config text section logic' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a Prettier config marker file.
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.prettierrc') -Content "{}"

			# Apply the convention with custom section settings.
			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings @{ name = 'custom'; text = "tmp/`ncache/" } | Out-Null

			# Assert custom settings were passed through to the managed section.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: custom convention`ntmp/`ncache/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

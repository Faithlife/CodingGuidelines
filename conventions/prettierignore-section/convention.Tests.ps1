#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'prettierignore-section convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokePrettierignoreSectionConvention {
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
			return @{
				name = 'build-output'
				text = "coverage/`ndist/"
			}
		}
	}

	It 'does nothing when Prettier is not detected' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)
			$prettierignorePath = Join-Path $testDirectory '.prettierignore'

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
			$prettierignorePath = Join-Path $testDirectory '.prettierignore'
			Write-Utf8NoBomFile -Path $prettierignorePath -Content "existing-entry/`n"

			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)

			(Get-Content -LiteralPath $prettierignorePath -Raw) | Should -Be "existing-entry/`n`n# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should -Be "Updated 'build-output' section in '.prettierignore'."

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
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.prettierrc') -Content "{}"

			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when prettier.config.js exists' {
		$testDirectory = New-TestDirectory

		try {
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'prettier.config.js') -Content "module.exports = {};`n"

			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when package.json has a top-level prettier property' {
		$testDirectory = New-TestDirectory

		try {
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{"prettier":{"singleQuote":true}}'

			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'applies the configured section when package.json has a prettier devDependency' {
		$testDirectory = New-TestDirectory

		try {
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{"devDependencies":{"prettier":"^3.0.0"}}'

			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) | Out-Null

			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: build-output convention`ncoverage/`ndist/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not treat a lockfile-only transitive prettier reference as detection' {
		$testDirectory = New-TestDirectory

		try {
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package-lock.json') -Content '{"packages":{"node_modules/prettier":{"version":"3.0.0"}}}'

			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings)

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
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{'

			{ InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings (GetDefaultSettings) } | Should -Throw "Failed to parse 'package.json' while detecting Prettier."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes through configured section settings to config text section logic' {
		$testDirectory = New-TestDirectory

		try {
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.prettierrc') -Content "{}"

			InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings @{ name = 'custom'; text = "tmp/`ncache/" } | Out-Null

			(Get-Content -LiteralPath (Join-Path $testDirectory '.prettierignore') -Raw) | Should -Be "# DO NOT EDIT: custom convention`ntmp/`ncache/`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes through commit settings to config text section logic' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'package.json') -Content '{"devDependencies":{"prettier":"^3.0.0"}}'

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add package manifest' | Out-Null
			}
			finally {
				Pop-Location
			}

			$headBeforeRun = Get-CommitId -TestDirectory $testDirectory

			$output = InvokePrettierignoreSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'build-output'
				text = "coverage/`ndist/"
				commit = @{ message = 'Update prettierignore' }
			}

			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $headBeforeRun
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Update prettierignore'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "Committed convention changes with message 'Update prettierignore'.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
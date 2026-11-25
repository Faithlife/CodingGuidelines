#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'gitignore-section convention' {
	BeforeAll {
		# Load the convention script and shared test helpers for temporary repositories and convention execution.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention script directly with temporary JSON input for each scenario.
		function script:InvokeGitIgnoreSectionConvention {
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
	}

	It 'creates .gitignore with the configured managed section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Apply the convention under test directly against a temporary repository.
			{ InvokeGitIgnoreSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'build-output'
				text = "bin/`nobj/`n"
			} } | Should -Not -Throw

			# Assert the configured managed section was written exactly.
			$gitIgnorePath = Join-Path $testDirectory '.gitignore'
			$content = Get-Content -LiteralPath $gitIgnorePath -Raw
			(Test-Path -LiteralPath $gitIgnorePath) | Should -Be $true
			$content | Should -Match "(?m)^# DO NOT EDIT: build-output convention\r?$"
			$content | Should -Match "(?m)^bin/\r?$"
			$content | Should -Match "(?m)^obj/\r?$"
			$content | Should -Match "(?m)^# END DO NOT EDIT\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'removes redundant unmanaged patterns after writing the managed section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with unmanaged patterns duplicated by the managed section.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.gitignore'), @"
bin/
obj/
*.user

# local Visual Studio state
.vs/
"@, $utf8)
			$settings = @{
				name = 'build-output'
				text = "bin/`nobj/`n"
			}

			# Apply the convention under test twice to verify cleanup idempotency.
			{ InvokeGitIgnoreSectionConvention -TestDirectory $testDirectory -Settings $settings } | Should -Not -Throw
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.gitignore') -Raw
			$secondOutput = InvokeGitIgnoreSectionConvention -TestDirectory $testDirectory -Settings $settings

			# Assert duplicate unmanaged patterns were removed but unrelated content remained.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.gitignore') -Raw) | Should -Be $content
			([regex]::Matches($content, '(?m)^bin/\r?$')).Count | Should -Be 1
			([regex]::Matches($content, '(?m)^obj/\r?$')).Count | Should -Be 1
			$content | Should -Match "(?m)^\*\.user\r?$"
			$content | Should -Match "(?m)^# local Visual Studio state\r?$"
			$content | Should -Match "(?m)^\.vs/\r?$"
			@($secondOutput).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not remove redundant unmanaged patterns when the managed section is unchanged' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository whose managed section is already current.
			$expectedContent = @"
# DO NOT EDIT: build-output convention
bin/
obj/
# END DO NOT EDIT

bin/
obj/
"@
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.gitignore'), $expectedContent, $utf8)

			# Apply the convention under test.
			$output = InvokeGitIgnoreSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'build-output'
				text = "bin/`nobj/`n"
			}

			# Assert the redundant unmanaged patterns remain because the managed section did not change.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.gitignore') -Raw) | Should -Be $expectedContent
			@($output).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not remove redundant patterns inside other managed sections' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with another managed section that overlaps the configured patterns.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.gitignore'), @"
# DO NOT EDIT: other convention
bin/
# END DO NOT EDIT
"@, $utf8)

			# Apply the convention under test.
			{ InvokeGitIgnoreSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'build-output'
				text = "bin/`nobj/`n"
			} } | Should -Not -Throw

			# Assert the preexisting managed section remains intact.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.gitignore') -Raw
			$content | Should -Match "(?s)# DO NOT EDIT: other convention\r?\nbin/\r?\n# END DO NOT EDIT"
			([regex]::Matches($content, '(?m)^bin/\r?$')).Count | Should -Be 2
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

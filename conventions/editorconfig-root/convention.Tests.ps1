#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'editorconfig-root convention' {
	BeforeAll {
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the default root section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with the root editorconfig convention enabled.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-root
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the generated editorconfig for assertions.
			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw

			# Assert the generated file contains the managed root section.
			(Test-Path -LiteralPath $editorConfigPath) | Should -Be $true
			$content | Should -Match "(?m)^root = true\r?$"
			$content | Should -Match "(?m)^# DO NOT EDIT: root convention\r?$"
			$content | Should -Match "(?m)^\[\*\]\r?$"
			$content | Should -Match "(?m)^charset = utf-8\r?$"
			$content | Should -Match "(?m)^end_of_line = lf\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = true\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates the managed root section and preserves unrelated content' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with stale managed root settings and unrelated content.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-root
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
# DO NOT EDIT: root convention
root = true

[*]
charset = latin1
# END DO NOT EDIT

[*.md]
trim_trailing_whitespace = false

[*]
indent_size = 2
indent_style = space
tab_width = 2
insert_final_newline = true
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Read the updated editorconfig for assertions.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw

			# Assert the root section changed while unrelated settings remained.
			$content | Should -Match "(?m)^charset = utf-8\r?$"
			$content | Should -Match "(?m)^end_of_line = lf\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = true\r?$"
			$content | Should -Match "(?m)^\[\*\.md\]\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = false\r?$"
			$content | Should -Not -Match '(?m)^indent_size = 2\r?$'
			$content | Should -Not -Match '(?m)^indent_style = space\r?$'
			$content | Should -Not -Match '(?m)^tab_width = 2\r?$'
			$content | Should -Not -Match '(?m)^insert_final_newline = true\r?$'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not leave a trailing blank line when removing a final root-wide section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with a final unmanaged root-wide section delegated to the convention.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-root
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
# DO NOT EDIT: root convention
root = true

[*]
charset = latin1
# END DO NOT EDIT

[*.md]
trim_trailing_whitespace = false

[*]
indent_size = 2
indent_style = space
tab_width = 2
insert_final_newline = true
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the removed final section did not leave an extra blank line at the end of the file.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$content | Should -Be "# DO NOT EDIT: root convention`nroot = true`n`n[*]`ncharset = utf-8`nend_of_line = lf`ntrim_trailing_whitespace = true`n# END DO NOT EDIT`n`n[*.md]`ntrim_trailing_whitespace = false`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'removes legacy root template markers without leaving a trailing blank line' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with legacy template markers and unmanaged root rules.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-root
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), ([string]::Join("`n", @(
				'# DO NOT EDIT - This file is a template managed at https://github.com/LogosBible/actions#templates',
				'# template-source: LogosBible/actions/editorconfig-template',
				'',
				'root = true',
				'',
				'[*]',
				'charset = utf-8',
				'end_of_line = lf',
				'trim_trailing_whitespace = true',
				'',
				'[*.fsd]',
				'indent_size = tab'
			))), $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert legacy markers were deleted and the moved root block did not leave a blank tail.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$content | Should -Be "# DO NOT EDIT: root convention`nroot = true`n`n[*]`ncharset = utf-8`nend_of_line = lf`ntrim_trailing_whitespace = true`n# END DO NOT EDIT`n`n[*.fsd]`nindent_size = tab`n"
			$content | Should -Not -Match '(?m)^# DO NOT EDIT -'
			$content | Should -Not -Match '(?m)^# template-source:'
			$content.EndsWith("`n`n", [System.StringComparison]::Ordinal) | Should -Be $false
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

Describe 'editorconfig-section convention' {
	BeforeAll {
		# Load the convention script and shared test helpers for temporary repositories and convention execution.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention script directly with temporary JSON input for unit scenarios.
		function script:InvokeEditorConfigSectionConvention {
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

	It 'creates .editorconfig with the configured managed section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Apply the convention under test directly against a temporary repository.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'files'
				text = "[*.txt]`nindent_style = space`ntrim_trailing_whitespace = false`n"
			} } | Should -Not -Throw

			# Read the generated editorconfig for assertions.
			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw

			# Assert the configured managed section was written exactly.
			(Test-Path -LiteralPath $editorConfigPath) | Should -Be $true
			$content | Should -Match "(?m)^# DO NOT EDIT: files convention\r?$"
			$content | Should -Match "(?m)^\[\*\.txt\]\r?$"
			$content | Should -Match "(?m)^indent_style = space\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = false\r?$"
			$content | Should -Match "(?m)^# END DO NOT EDIT\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'removes redundant unmanaged rules after writing the managed section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with unmanaged rules duplicated by the managed section.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.md]
trim_trailing_whitespace = false

[*.txt]
indent_size = 2
"@, $utf8)

			# Apply the convention under test.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'files'
				text = "[*.md]`ntrim_trailing_whitespace = false`n"
			} } | Should -Not -Throw

			# Assert the duplicate unmanaged Markdown section was removed but unrelated content remained.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			([regex]::Matches($content, '(?m)^trim_trailing_whitespace = false\r?$')).Count | Should -Be 1
			$content | Should -Not -Match '(?m)^\[\*\.md\]\r?$\ntrim_trailing_whitespace = false\r?$\n\r?$\n\[\*\.txt\]'
			$content | Should -Match "(?m)^\[\*\.txt\]\r?$"
			$content | Should -Match "(?m)^indent_size = 2\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not remove redundant unmanaged rules when the managed section is unchanged' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository whose managed section is already current.
			$expectedContent = @"
# DO NOT EDIT: files convention
[*.md]
trim_trailing_whitespace = false
# END DO NOT EDIT

[*.md]
trim_trailing_whitespace = false
"@
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), $expectedContent, $utf8)

			# Apply the convention under test.
			$output = InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'files'
				text = "[*.md]`ntrim_trailing_whitespace = false`n"
			}

			# Assert the redundant unmanaged rule remains because the managed section did not change.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw) | Should -Be $expectedContent
			@($output).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'removes redundant unmanaged rules from covered subset sections' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a duplicate rule in a narrower unmanaged section.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.cs]
trim_trailing_whitespace = false

[*.vb]
trim_trailing_whitespace = false
"@, $utf8)
			$settings = @{
				name = 'csharp-files'
				text = "[*.{cs,cshtml,razor}]`ntrim_trailing_whitespace = false`n"
			}

			# Apply the convention under test twice to verify subset cleanup idempotency.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings $settings } | Should -Not -Throw
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$secondOutput = InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings $settings

			# Assert the covered subset section was removed while the uncovered duplicate remains.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw) | Should -Be $content
			$content | Should -Match '(?m)^\[\*\.\{cs,cshtml,razor\}\]\r?$'
			$content | Should -Not -Match '(?m)^\[\*\.cs\]\r?$'
			$content | Should -Match '(?m)^\[\*\.vb\]\r?$'
			([regex]::Matches($content, '(?m)^trim_trailing_whitespace = false\r?$')).Count | Should -Be 2
			@($secondOutput).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'keeps covered subset sections with remaining unmanaged rules' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a brace-list subset that has one duplicated rule.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.{cs,razor}]
trim_trailing_whitespace = false
indent_size = 4
"@, $utf8)

			# Apply the convention under test.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'csharp-files'
				text = "[*.{cs,cshtml,razor}]`ntrim_trailing_whitespace = false`n"
			} } | Should -Not -Throw

			# Assert only the redundant rule was removed from the subset section.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$content | Should -Match '(?m)^\[\*\.\{cs,razor\}\]\r?$'
			([regex]::Matches($content, '(?m)^trim_trailing_whitespace = false\r?$')).Count | Should -Be 1
			$content | Should -Match '(?m)^indent_size = 4\r?$'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'compacts unmanaged blank lines after deleting redundant rules' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with repeated blank lines exposed by rule cleanup.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.md]
trim_trailing_whitespace = false


indent_size = 2

[*.txt]
indent_size = 4
"@, $utf8)
			$settings = @{
				name = 'markdown-files'
				text = "[*.md]`ntrim_trailing_whitespace = false`n"
			}

			# Apply the convention under test twice to verify blank cleanup idempotency.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings $settings } | Should -Not -Throw
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$secondOutput = InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings $settings

			# Assert redundant cleanup left only single blank separators outside managed sections.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw) | Should -Be $content
			$content | Should -Match "(?m)^\[\*\.md\]\r?$"
			$content | Should -Match "(?s)\[\*\.md\]\r?\n\r?\nindent_size = 2"
			$content | Should -Not -Match "(?s)\r?\n\r?\n\r?\nindent_size = 2"
			$content | Should -Match "(?m)^\[\*\.txt\]\r?$"
			@($secondOutput).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not treat wildcard managed sections as covering narrower sections' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a root-wide managed rule duplicated in a narrower section.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.cs]
trim_trailing_whitespace = false
"@, $utf8)

			# Apply the convention under test.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'all-files'
				text = "[*]`ntrim_trailing_whitespace = false`n"
			} } | Should -Not -Throw

			# Assert the narrower section remains because wildcard coverage is intentionally not inferred.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$content | Should -Match '(?m)^\[\*\.cs\]\r?$'
			([regex]::Matches($content, '(?m)^trim_trailing_whitespace = false\r?$')).Count | Should -Be 2
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not remove redundant rules inside other managed sections' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with another managed section that overlaps the configured rules.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
# DO NOT EDIT: other convention
[*.md]
trim_trailing_whitespace = false
# END DO NOT EDIT
"@, $utf8)

			# Apply the convention under test.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings @{
				name = 'files'
				text = "[*.md]`ntrim_trailing_whitespace = false`n"
			} } | Should -Not -Throw

			# Assert the preexisting managed section remains intact.
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$content | Should -Match "(?s)# DO NOT EDIT: other convention\r?\n\[\*\.md\]\r?\ntrim_trailing_whitespace = false\r?\n# END DO NOT EDIT"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'normalizes inferred root section placement and configured root-wide rules' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with root settings duplicated outside the managed section.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.md]
trim_trailing_whitespace = false

root = true

[*]
charset = utf-8
end_of_line = lf
trim_trailing_whitespace = true
indent_size = 2
indent_style = space
tab_width = 2
insert_final_newline = true
"@, $utf8)
			$settings = @{
				name = 'foundation'
				text = "root = true`n`n[*]`ncharset = utf-8`nend_of_line = lf`ntrim_trailing_whitespace = true`n"
				'remove-root-rules' = @('indent_size', 'tab_width')
			}

			# Apply the convention under test twice to verify cleanup idempotency.
			{ InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings $settings } | Should -Not -Throw
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			$secondOutput = InvokeEditorConfigSectionConvention -TestDirectory $testDirectory -Settings $settings

			# Assert root is first, unmanaged root-wide rules were removed, and unrelated content remains.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw) | Should -Be $content
			$content.StartsWith("# DO NOT EDIT: foundation convention`n", [System.StringComparison]::Ordinal) | Should -Be $true
			([regex]::Matches($content, '(?m)^root = true\r?$')).Count | Should -Be 1
			([regex]::Matches($content, '(?m)^\[\*\]\r?$')).Count | Should -Be 2
			$content | Should -Not -Match '(?m)^indent_size = 2\r?$'
			$content | Should -Not -Match '(?m)^tab_width = 2\r?$'
			$content | Should -Match '(?m)^indent_style = space\r?$'
			$content | Should -Match '(?m)^insert_final_newline = true\r?$'
			$content | Should -Match "(?m)^\[\*\.md\]\r?$"
			$content | Should -Match "(?m)^trim_trailing_whitespace = false\r?$"
			@($secondOutput).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses native commit settings when it changes .editorconfig' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a configured commit message.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), '{"conventions":[{"path":"../conventions/editorconfig-section","commit":{"message":"Add editorconfig"},"settings":{"name":"files","text":"[*.md]\ntrim_trailing_whitespace = false\n"}}]}', $utf8)
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and allow it to create the configured commit.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the configured commit message and clean working tree.
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Add editorconfig'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

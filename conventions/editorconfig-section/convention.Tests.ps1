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
		# Load shared test helpers for temporary repositories and convention execution.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates .editorconfig with the configured managed section' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a configured editorconfig section.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: files
    text: |
      [*.txt]
      indent_style = space
      trim_trailing_whitespace = false
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

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
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: files
    text: |
      [*.md]
      trim_trailing_whitespace = false
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.md]
trim_trailing_whitespace = false

[*.txt]
indent_size = 2
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

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

	It 'removes redundant unmanaged rules from covered subset sections' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a duplicate rule in a narrower unmanaged section.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: csharp-files
    text: |
      [*.{cs,cshtml,razor}]
      trim_trailing_whitespace = false
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.cs]
trim_trailing_whitespace = false

[*.vb]
trim_trailing_whitespace = false
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test twice to verify subset cleanup idempotency.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

			# Assert the covered subset section was removed while the uncovered duplicate remains.
			(Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw) | Should -Be $content
			$content | Should -Match '(?m)^\[\*\.\{cs,cshtml,razor\}\]\r?$'
			$content | Should -Not -Match '(?m)^\[\*\.cs\]\r?$'
			$content | Should -Match '(?m)^\[\*\.vb\]\r?$'
			([regex]::Matches($content, '(?m)^trim_trailing_whitespace = false\r?$')).Count | Should -Be 2
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'keeps covered subset sections with remaining unmanaged rules' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a brace-list subset that has one duplicated rule.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: csharp-files
    text: |
      [*.{cs,cshtml,razor}]
      trim_trailing_whitespace = false
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.{cs,razor}]
trim_trailing_whitespace = false
indent_size = 4
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

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

	It 'does not treat wildcard managed sections as covering narrower sections' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an isolated repository with a root-wide managed rule duplicated in a narrower section.
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: all-files
    text: |
      [*]
      trim_trailing_whitespace = false
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
[*.cs]
trim_trailing_whitespace = false
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

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
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: files
    text: |
      [*.md]
      trim_trailing_whitespace = false
"@, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.editorconfig'), @"
# DO NOT EDIT: other convention
[*.md]
trim_trailing_whitespace = false
# END DO NOT EDIT
"@, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

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
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			[System.IO.File]::WriteAllText((Join-Path $testDirectory '.github/conventions.yml'), @"
conventions:
- path: ../conventions/editorconfig-section
  settings:
    name: foundation
    text: |
      root = true

      [*]
      charset = utf-8
      end_of_line = lf
      trim_trailing_whitespace = true
    remove-root-rules:
      - indent_size
      - tab_width
"@, $utf8)
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
			Initialize-TestRepository -Path $testDirectory

			# Apply the convention under test twice to verify cleanup idempotency.
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw
			$content = Get-Content -LiteralPath (Join-Path $testDirectory '.editorconfig') -Raw
			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should -Not -Throw

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
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
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

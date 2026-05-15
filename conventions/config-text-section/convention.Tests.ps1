#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the config-text-section convention.
Describe 'config-text-section convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention with temporary JSON input for each scenario.
		function script:InvokeConfigTextSectionConvention {
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

	It 'creates a repository-root-relative file with a managed section and is idempotent' {
		# Set up an empty repository for managed section creation.
		$testDirectory = New-TemporaryDirectory

		try {
			# Run the convention and capture the created target path.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }
			$targetPath = Join-Path $testDirectory '.editorconfig'

			# Assert the file was created with the expected managed section.
			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should -Be "Updated 'general-editorconfig' section in '.editorconfig'."

			# Re-run the convention and assert it is idempotent.
			$secondOutput = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$secondOutput[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'resolves relative paths from the repository root' {
		# Set up an empty repository for relative path resolution.
		$testDirectory = New-TemporaryDirectory

		try {
			# Run the convention with a repository-root-relative path.
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = 'workflows/ci.yml'; name = 'ci'; text = 'name: CI'; 'comment-prefix' = '#' }
			$targetPath = Join-Path $testDirectory 'workflows' 'ci.yml'

			# Assert the file is written under the repository root.
			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: ci convention`nname: CI`n# END DO NOT EDIT`n"
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'replaces an existing managed section with the same name' {
		# Set up a repository with an outdated managed section.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			[System.IO.File]::WriteAllText($targetPath, "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n", $utf8)

			# Run the convention with replacement section text.
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8`nend_of_line = lf"; 'comment-prefix' = '#' }

			# Assert the managed section was replaced in place.
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`nend_of_line = lf`n# END DO NOT EDIT`n"
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not rewrite a correct managed section or surrounding spacing' {
		# Set up a repository with compliant content and a fixed timestamp.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$expectedContent = "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"
			$expectedWriteTime = [datetime]::SpecifyKind([datetime]::Parse('2001-02-03T04:05:06Z'), [System.DateTimeKind]::Utc)
			[System.IO.File]::WriteAllText($targetPath, $expectedContent, $utf8)
			[System.IO.File]::SetLastWriteTimeUtc($targetPath, $expectedWriteTime)

			# Run the convention against the already-compliant file.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			# Assert content, timestamp, and compliance output are unchanged.
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be $expectedContent
			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should -Be $expectedWriteTime
			$output[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'preserves content outside the managed section when replacing it' {
		# Set up a file with unmanaged content around an outdated section.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			[System.IO.File]::WriteAllText($targetPath, "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n", $utf8)

			# Run the convention to replace only the managed section.
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			# Assert surrounding content is preserved exactly.
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'supports comment suffixes for managed sections' {
		# Set up an empty repository for HTML-style comments.
		$testDirectory = New-TemporaryDirectory

		try {
			# Run the convention with prefix and suffix comment markers.
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/docs/example.html'; name = 'snippet'; text = '<div>Example</div>'; 'comment-prefix' = '<!--'; 'comment-suffix' = '-->' }
			$targetPath = Join-Path $testDirectory 'docs' 'example.html'

			# Assert the managed section uses both comment markers.
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "<!-- DO NOT EDIT: snippet convention -->`n<div>Example</div>`n<!-- END DO NOT EDIT -->`n"
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'fails on duplicate managed sections for the same name' {
		# Set up a file with two managed sections that share one name.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			[System.IO.File]::WriteAllText($targetPath, "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`nindent_style = space`n# END DO NOT EDIT`n", $utf8)

			# Assert duplicate managed sections are rejected.
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = '[*]'; 'comment-prefix' = '#' } } | Should -Throw "Found multiple managed sections named 'general-editorconfig' in '$targetPath'."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'preserves CRLF files when appending a managed section' {
		# Set up a CRLF file before appending a managed section.
		$testDirectory = New-TemporaryDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			[System.IO.File]::WriteAllText($targetPath, "root = true`r`n", $utf8)

			# Run the convention against the CRLF file.
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			# Assert the appended managed section preserves CRLF endings.
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`r`n`r`n# DO NOT EDIT: general-editorconfig convention`r`n[*]`r`ncharset = utf-8`r`n# END DO NOT EDIT`r`n"
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'requires top-level section settings' {
		# Set up an empty repository for required-setting validation.
		$testDirectory = New-TemporaryDirectory

		try {
			# Assert each missing required setting produces the expected error.
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; text = '[*]'; 'comment-prefix' = '#' } } | Should -Throw "The 'name' setting is required."
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; name = 'general-editorconfig'; 'comment-prefix' = '#' } } | Should -Throw "The 'text' setting is required."
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; name = 'general-editorconfig'; text = '[*]' } } | Should -Throw "The 'comment-prefix' setting is required."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

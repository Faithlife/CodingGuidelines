#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

	AfterEach {
		# Clear global Copilot stubs and counters between tests.
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
		Remove-Variable -Name CopilotCallCount -Scope Global -ErrorAction SilentlyContinue
		Remove-Variable -Name CopilotInstructions -Scope Global -ErrorAction SilentlyContinue
	}

	It 'creates a repository-root-relative file with a managed section and is idempotent' {
		# Set up an empty repository for managed section creation.
		$testDirectory = New-TestDirectory

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

	It 'runs Copilot with configured agent instructions when the file changes' {
		# Set up an empty repository and expected Copilot instructions.
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$expectedInstructions = @'
Make sure the code still builds successfully, e.g. by running `./build.ps1 build` or `dotnet build`.
If the code doesn't build successfully, read the error messages, read the affected files, and fix the issues by editing the code.
DO NOT suppress warnings by adding `<NoWarn>` properties or `#pragma warning` directives.
If you make changes, build the code again and keep fixing issues until it builds successfully.
DO NOT commit any changes to the git repository. Leave your changes unstaged.
'@
			$global:CopilotCallCount = 0
			$global:CopilotInstructions = ''

			# Stub Copilot to capture the instructions piped into it.
			function global:copilot {
				$global:CopilotCallCount++
				$global:CopilotInstructions = (@($input) -join '')
			}

			# Run the convention with agent instructions configured.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = $expectedInstructions }
			}

			# Assert Copilot ran once with the expected instruction text.
			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			$global:CopilotCallCount | Should -Be 1
			$global:CopilotInstructions | Should -Be $expectedInstructions
			(@($output | ForEach-Object { $_.ToString() }) -contains "'.editorconfig' changed; starting Copilot with configured agent instructions.") | Should -Be $true
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not run Copilot when the file is already compliant' {
		# Set up a repository that already contains the managed section.
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$global:CopilotCallCount = 0

			# Stub Copilot so any unexpected invocation is observable.
			function global:copilot {
				$global:CopilotCallCount++
			}

			# Run the convention with agent instructions against compliant content.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = 'Build the code.' }
			}

			# Assert Copilot was skipped and the output reports compliance.
			$global:CopilotCallCount | Should -Be 0
			$output[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'restores the configured managed section after Copilot edits it' {
		# Set up a repository and a target path that Copilot will mutate.
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$global:CopilotCallCount = 0

			# Stub Copilot to corrupt the managed section after the convention writes it.
			function global:copilot {
				$global:CopilotCallCount++
				Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n"
			}

			# Run the convention with agent instructions configured.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = 'Review the file.' }
			}

			# Assert the convention restores the configured managed section.
			$global:CopilotCallCount | Should -Be 1
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			(@($output | ForEach-Object { $_.ToString() }) -contains "'.editorconfig' changed; starting Copilot with configured agent instructions.") | Should -Be $true
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'commits changed files with the configured commit message after running Copilot' {
		# Set up a repository for commit-producing agent changes.
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$notesPath = Join-Path $testDirectory 'notes.md'
			$global:CopilotCallCount = 0

			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Stub Copilot to create an additional changed file.
			function global:copilot {
				$global:CopilotCallCount++
				Write-Utf8NoBomFile -Path $notesPath -Content "Created by Copilot.`n"
			}

			# Run the convention with both agent and commit settings.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = 'Create notes.' }
				commit = @{ message = 'Add editorconfig' }
			}

			# Assert the convention committed all resulting changes.
			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Test-Path -LiteralPath $notesPath) | Should -Be $true
			$global:CopilotCallCount | Should -Be 1
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Add editorconfig'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "Committed convention changes with message 'Add editorconfig'.") | Should -Be $true
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not create a commit when the file is already compliant' {
		# Set up a repository with compliant content already committed.
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Initialize-TestRepository -Path $testDirectory
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"

			# Commit the compliant baseline before invoking the convention.
			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add editorconfig' | Out-Null
			}
			finally {
				Pop-Location
			}

			$headBeforeRun = Get-CommitId -TestDirectory $testDirectory

			# Run the convention with commit settings against compliant content.
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				commit = @{ message = 'Normalize editorconfig.' }
			}

			# Assert no new commit or working tree change was created.
			(Get-CommitId -TestDirectory $testDirectory) | Should -Be $headBeforeRun
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			$output[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not run Copilot when agent instructions are missing, null, empty, or whitespace' {
		# Set up reusable state for agent settings cases.
		$testDirectory = New-TestDirectory

		try {
			$global:CopilotCallCount = 0

			# Stub Copilot so any unexpected invocation is observable.
			function global:copilot {
				$global:CopilotCallCount++
			}

			# Enumerate missing and blank instruction settings.
			$agentSettingsCases = @(
				@{},
				@{ instructions = $null },
				@{ instructions = '' },
				@{ instructions = '   ' }
			)

			foreach ($agentSettings in $agentSettingsCases) {
				# Run each case in its own repository directory.
				$caseDirectory = Join-Path $testDirectory ([guid]::NewGuid().ToString('N'))
				[System.IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
				$targetPath = Join-Path $caseDirectory '.editorconfig'

				$output = InvokeConfigTextSectionConvention -TestDirectory $caseDirectory -Settings @{
					path = '.editorconfig'
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
					agent = $agentSettings
				}

				# Assert each case updates the file without calling Copilot.
				(Test-Path -LiteralPath $targetPath) | Should -Be $true
				$output[-1].ToString() | Should -Be "Updated 'general-editorconfig' section in '.editorconfig'."
			}

			# Assert none of the blank-instruction cases invoked Copilot.
			$global:CopilotCallCount | Should -Be 0
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'resolves relative paths from the repository root' {
		# Set up an empty repository for relative path resolution.
		$testDirectory = New-TestDirectory

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
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n"

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
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$expectedContent = "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"
			$expectedWriteTime = [datetime]::SpecifyKind([datetime]::Parse('2001-02-03T04:05:06Z'), [System.DateTimeKind]::Utc)
			Write-Utf8NoBomFile -Path $targetPath -Content $expectedContent
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
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"

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
		$testDirectory = New-TestDirectory

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
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`nindent_style = space`n# END DO NOT EDIT`n"

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
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`r`n"

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
		$testDirectory = New-TestDirectory

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

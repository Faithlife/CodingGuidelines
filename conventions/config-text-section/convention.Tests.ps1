#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'config-text-section convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

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
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
		Remove-Variable -Name CopilotCallCount -Scope Global -ErrorAction SilentlyContinue
		Remove-Variable -Name CopilotInstructions -Scope Global -ErrorAction SilentlyContinue
	}

	It 'creates a repository-root-relative file with a managed section and is idempotent' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }
			$targetPath = Join-Path $testDirectory '.editorconfig'

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should -Be "Updated 'general-editorconfig' section in '.editorconfig'."

			$secondOutput = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$secondOutput[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'runs Copilot with configured agent instructions when the file changes' {
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

			function global:copilot {
				$global:CopilotCallCount++
				$global:CopilotInstructions = (@($input) -join '')
			}

			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = $expectedInstructions }
			}

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			$global:CopilotCallCount | Should -Be 1
			$global:CopilotInstructions | Should -Be $expectedInstructions
			(@($output | ForEach-Object { $_.ToString() }) -contains "'.editorconfig' changed; starting Copilot with configured agent instructions.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not run Copilot when the file is already compliant' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$global:CopilotCallCount = 0

			function global:copilot {
				$global:CopilotCallCount++
			}

			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = 'Build the code.' }
			}

			$global:CopilotCallCount | Should -Be 0
			$output[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'restores the configured managed section after Copilot edits it' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$global:CopilotCallCount = 0

			function global:copilot {
				$global:CopilotCallCount++
				Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n"
			}

			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = 'Review the file.' }
			}

			$global:CopilotCallCount | Should -Be 1
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			(@($output | ForEach-Object { $_.ToString() }) -contains "'.editorconfig' changed; starting Copilot with configured agent instructions.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'commits changed files with the configured commit message after running Copilot' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$notesPath = Join-Path $testDirectory 'notes.md'
			$global:CopilotCallCount = 0

			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			function global:copilot {
				$global:CopilotCallCount++
				Write-Utf8NoBomFile -Path $notesPath -Content "Created by Copilot.`n"
			}

			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				agent = @{ instructions = 'Create notes.' }
				commit = @{ message = 'Add editorconfig' }
			}

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Test-Path -LiteralPath $notesPath) | Should -Be $true
			$global:CopilotCallCount | Should -Be 1
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Add editorconfig'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "Committed convention changes with message 'Add editorconfig'.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not create a commit when the file is already compliant' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Initialize-TestRepository -Path $testDirectory
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add editorconfig' | Out-Null
			}
			finally {
				Pop-Location
			}

			$headBeforeRun = Get-CommitId -TestDirectory $testDirectory

			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
				'comment-prefix' = '#'
				commit = @{ message = 'Normalize editorconfig.' }
			}

			(Get-CommitId -TestDirectory $testDirectory) | Should -Be $headBeforeRun
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			$output[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not run Copilot when agent instructions are missing, null, empty, or whitespace' {
		$testDirectory = New-TestDirectory

		try {
			$global:CopilotCallCount = 0

			function global:copilot {
				$global:CopilotCallCount++
			}

			$agentSettingsCases = @(
				@{},
				@{ instructions = $null },
				@{ instructions = '' },
				@{ instructions = '   ' }
			)

			foreach ($agentSettings in $agentSettingsCases) {
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

				(Test-Path -LiteralPath $targetPath) | Should -Be $true
				$output[-1].ToString() | Should -Be "Updated 'general-editorconfig' section in '.editorconfig'."
			}

			$global:CopilotCallCount | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'resolves relative paths from the repository root' {
		$testDirectory = New-TestDirectory

		try {
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = 'workflows/ci.yml'; name = 'ci'; text = 'name: CI'; 'comment-prefix' = '#' }
			$targetPath = Join-Path $testDirectory 'workflows' 'ci.yml'

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: ci convention`nname: CI`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'replaces an existing managed section with the same name' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n"

			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8`nend_of_line = lf"; 'comment-prefix' = '#' }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`nend_of_line = lf`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not rewrite a correct managed section or surrounding spacing' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			$expectedContent = "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"
			$expectedWriteTime = [datetime]::SpecifyKind([datetime]::Parse('2001-02-03T04:05:06Z'), [System.DateTimeKind]::Utc)
			Write-Utf8NoBomFile -Path $targetPath -Content $expectedContent
			[System.IO.File]::SetLastWriteTimeUtc($targetPath, $expectedWriteTime)

			$output = InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be $expectedContent
			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should -Be $expectedWriteTime
			$output[-1].ToString() | Should -Be "'.editorconfig' already contains the 'general-editorconfig' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'preserves content outside the managed section when replacing it' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"

			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'supports comment suffixes for managed sections' {
		$testDirectory = New-TestDirectory

		try {
			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/docs/example.html'; name = 'snippet'; text = '<div>Example</div>'; 'comment-prefix' = '<!--'; 'comment-suffix' = '-->' }
			$targetPath = Join-Path $testDirectory 'docs' 'example.html'

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "<!-- DO NOT EDIT: snippet convention -->`n<div>Example</div>`n<!-- END DO NOT EDIT -->`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'fails on duplicate managed sections for the same name' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`nindent_style = space`n# END DO NOT EDIT`n"

			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = '[*]'; 'comment-prefix' = '#' } } | Should -Throw "Found multiple managed sections named 'general-editorconfig' in '$targetPath'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'preserves CRLF files when appending a managed section' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`r`n"

			InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; name = 'general-editorconfig'; text = "[*]`ncharset = utf-8"; 'comment-prefix' = '#' }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`r`n`r`n# DO NOT EDIT: general-editorconfig convention`r`n[*]`r`ncharset = utf-8`r`n# END DO NOT EDIT`r`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'requires top-level section settings' {
		$testDirectory = New-TestDirectory

		try {
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; text = '[*]'; 'comment-prefix' = '#' } } | Should -Throw "The 'name' setting is required."
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; name = 'general-editorconfig'; 'comment-prefix' = '#' } } | Should -Throw "The 'text' setting is required."
			{ InvokeConfigTextSectionConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; name = 'general-editorconfig'; text = '[*]' } } | Should -Throw "The 'comment-prefix' setting is required."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
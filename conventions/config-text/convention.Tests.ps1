#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'config-text convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeConfigTextConvention {
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

	It 'creates a repository-root-relative file and is idempotent' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; lines = @('bin/', 'obj/') }
			$gitignorePath = Join-Path $testDirectory '.gitignore'

			(Test-Path -LiteralPath $gitignorePath) | Should -Be $true
			(Get-Content -LiteralPath $gitignorePath -Raw) | Should -Be "bin/`nobj/`n"
			$output[-1].ToString() | Should -Be "Added 2 lines to '$gitignorePath'."

			$secondOutput = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; lines = @('bin/', 'obj/') }

			(Get-Content -LiteralPath $gitignorePath -Raw) | Should -Be "bin/`nobj/`n"
			$secondOutput[-1].ToString() | Should -Be "'$gitignorePath' already contains all configured lines."
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

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				'new-file-text' = 'root = true'
				agent = @{ instructions = $expectedInstructions }
			}

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			$global:CopilotCallCount | Should -Be 1
			$global:CopilotInstructions | Should -Be $expectedInstructions
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$targetPath' changed; starting Copilot with configured agent instructions.") | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not run Copilot when the file is already compliant' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content 'root = true'
			$global:CopilotCallCount = 0

			function global:copilot {
				$global:CopilotCallCount++
			}

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				'new-file-text' = 'root = true'
				agent = @{ instructions = 'Build the code.' }
			}

			$global:CopilotCallCount | Should -Be 0
			$output[-1].ToString() | Should -Be "'$targetPath' already exists."
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
				Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n"
			}

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				'new-file-text' = 'root = true'
				agent = @{ instructions = 'Review the file.' }
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}

			$global:CopilotCallCount | Should -Be 1
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			(@($output | ForEach-Object { $_.ToString() }) -contains "'$targetPath' changed; starting Copilot with configured agent instructions.") | Should -Be $true
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

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				'new-file-text' = 'root = true'
				agent = @{ instructions = 'Create notes.' }
				commit = @{ message = 'Add editorconfig.' }
			}

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Test-Path -LiteralPath $notesPath) | Should -Be $true
			$global:CopilotCallCount | Should -Be 1
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should -Be 'Add editorconfig.'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			(@($output | ForEach-Object { $_.ToString() }) -contains "Committed convention changes with message 'Add editorconfig.'.") | Should -Be $true
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
			Write-Utf8NoBomFile -Path $targetPath -Content 'root = true'

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add editorconfig.' | Out-Null
			}
			finally {
				Pop-Location
			}

			$headBeforeRun = Get-CommitId -TestDirectory $testDirectory

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '.editorconfig'
				'new-file-text' = 'root = true'
				commit = @{ message = 'Normalize editorconfig.' }
			}

			(Get-CommitId -TestDirectory $testDirectory) | Should -Be $headBeforeRun
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
			$output[-1].ToString() | Should -Be "'$targetPath' already exists."
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

				$output = InvokeConfigTextConvention -TestDirectory $caseDirectory -Settings @{
					path = '.editorconfig'
					'new-file-text' = 'root = true'
					agent = $agentSettings
				}

				(Test-Path -LiteralPath $targetPath) | Should -Be $true
				$output[-1].ToString() | Should -Be "Initialized '$targetPath'."
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
			InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = 'workflows/ci.yml'; lines = @('name: CI') }
			$targetPath = Join-Path $testDirectory 'workflows\ci.yml'

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "name: CI`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'appends only lines that are not already present' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content 'root = true'

			InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; lines = @('root = true', '[*]') }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`n[*]`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not touch the target file when all configured lines already exist' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.gitignore'
			Write-Utf8NoBomFile -Path $targetPath -Content "bin/`nobj/`n"
			$expectedWriteTime = [datetime]::SpecifyKind([datetime]::Parse('2001-02-03T04:05:06Z'), [System.DateTimeKind]::Utc)
			[System.IO.File]::SetLastWriteTimeUtc($targetPath, $expectedWriteTime)

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '.gitignore'; lines = @('bin/', 'obj/') }

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "bin/`nobj/`n"
			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should -Be $expectedWriteTime
			$output[-1].ToString() | Should -Be "'$targetPath' already contains all configured lines."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not create the target file when the configured lines list is empty' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.gitignore'

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '.gitignore'; lines = @() }

			(Test-Path -LiteralPath $targetPath) | Should -Be $false
			$output[-1].ToString() | Should -Be "No configured lines to add for '$targetPath'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'initializes a missing file from new-file-text' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; 'new-file-text' = 'root = true' }

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be 'root = true'
			$output[-1].ToString() | Should -Be "Initialized '$targetPath'."

			$secondOutput = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '.editorconfig'; 'new-file-text' = 'root = true' }
			$secondOutput[-1].ToString() | Should -Be "'$targetPath' already exists."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'rejects lines that contain newlines' {
		$testDirectory = New-TestDirectory

		try {
			{ InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; lines = @("bin/`nobj/") } } | Should -Throw "Each line in 'lines' must be a single line."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'creates a managed section when the file is missing' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}
			$targetPath = Join-Path $testDirectory '.editorconfig'

			(Test-Path -LiteralPath $targetPath) | Should -Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should -Be "Updated 'general-editorconfig' section in '$targetPath'."
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

			InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8`nend_of_line = lf"
					'comment-prefix' = '#'
				}
			}

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

			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be $expectedContent
			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should -Be $expectedWriteTime
			$output[-1].ToString() | Should -Be "'$targetPath' already contains the 'general-editorconfig' section."
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

			InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n[*.cs]`nindent_style = space`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'supports combined new-file-text and section behavior' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				'new-file-text' = 'root = true'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}
			$targetPath = Join-Path $testDirectory '.editorconfig'

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should -Be "Updated configured text and the 'general-editorconfig' section in '$targetPath'."

			$secondOutput = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				'new-file-text' = 'root = true'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}

			$secondOutput[-1].ToString() | Should -Be "'$targetPath' already contains the 'general-editorconfig' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'supports comment suffixes for managed sections' {
		$testDirectory = New-TestDirectory

		try {
			InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/docs/example.html'
				section = @{
					name = 'snippet'
					text = '<div>Example</div>'
					'comment-prefix' = '<!--'
					'comment-suffix' = '-->'
				}
			}
			$targetPath = Join-Path $testDirectory 'docs\example.html'

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

			{ InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; section = @{ name = 'general-editorconfig'; text = '[*]'; 'comment-prefix' = '#' } } } | Should -Throw "Found multiple managed sections named 'general-editorconfig' in '$targetPath'."
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

			InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should -Be "root = true`r`n`r`n# DO NOT EDIT: general-editorconfig convention`r`n[*]`r`ncharset = utf-8`r`n# END DO NOT EDIT`r`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeConfigTextConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory,

		[Parameter(Mandatory = $true)]
		[hashtable] $Settings
	)

	$inputPath = New-ConventionInputFile -Settings $Settings

	try {
		return Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
	}
	finally {
		Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
	}
}

Describe 'config-text convention' {
	It 'creates a repository-root-relative file and is idempotent' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; lines = @('bin/', 'obj/') }
			$gitignorePath = Join-Path $testDirectory '.gitignore'

			(Test-Path -LiteralPath $gitignorePath) | Should Be $true
			(Get-Content -LiteralPath $gitignorePath -Raw) | Should Be "bin/`nobj/`n"
			$output[-1].ToString() | Should Be "Added 2 lines to '$gitignorePath'."

			$secondOutput = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; lines = @('bin/', 'obj/') }

			(Get-Content -LiteralPath $gitignorePath -Raw) | Should Be "bin/`nobj/`n"
			$secondOutput[-1].ToString() | Should Be "'$gitignorePath' already contains all configured lines."
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

			(Test-Path -LiteralPath $targetPath) | Should Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "name: CI`n"
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

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n[*]`n"
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

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "bin/`nobj/`n"
			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should Be $expectedWriteTime
			$output[-1].ToString() | Should Be "'$targetPath' already contains all configured lines."
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

			(Test-Path -LiteralPath $targetPath) | Should Be $false
			$output[-1].ToString() | Should Be "No configured lines to add for '$targetPath'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'rejects lines that contain newlines' {
		$testDirectory = New-TestDirectory

		try {
			{ InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; lines = @("bin/`nobj/") } } | Should Throw "Each line in 'lines' must be a single line."
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

			(Test-Path -LiteralPath $targetPath) | Should Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should Be "Updated 'general-editorconfig' section in '$targetPath'."
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

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`nend_of_line = lf`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'supports combined lines and section behavior' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				lines = @('root = true')
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}
			$targetPath = Join-Path $testDirectory '.editorconfig'

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should Be "Updated configured lines and the 'general-editorconfig' section in '$targetPath'."

			$secondOutput = InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{
				path = '/.editorconfig'
				lines = @('root = true')
				section = @{
					name = 'general-editorconfig'
					text = "[*]`ncharset = utf-8"
					'comment-prefix' = '#'
				}
			}

			$secondOutput[-1].ToString() | Should Be "'$targetPath' already contains all configured lines and the 'general-editorconfig' section."
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
					'comment-suffix' = ' -->'
				}
			}
			$targetPath = Join-Path $testDirectory 'docs\example.html'

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "<!-- DO NOT EDIT: snippet convention -->`n<div>Example</div>`n<!-- END DO NOT EDIT -->`n"
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

			{ InvokeConfigTextConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; section = @{ name = 'general-editorconfig'; text = '[*]'; 'comment-prefix' = '#' } } } | Should Throw "Found multiple managed sections named 'general-editorconfig' in '$targetPath'."
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

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`r`n`r`n# DO NOT EDIT: general-editorconfig convention`r`n[*]`r`ncharset = utf-8`r`n# END DO NOT EDIT`r`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

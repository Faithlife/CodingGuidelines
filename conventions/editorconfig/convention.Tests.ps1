Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeEditorconfigConvention {
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

Describe 'editorconfig convention' {
	It 'creates .editorconfig with root true and the managed block when the file is missing' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
			}
			$targetPath = Join-Path $testDirectory '.editorconfig'

			(Test-Path -LiteralPath $targetPath) | Should Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
			$output[-1].ToString() | Should Be "Updated 'general-editorconfig' section in '$targetPath'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'appends a managed block without changing unrelated content' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n[*.cs]`nindent_size = 4`n"

			InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n`n[*.cs]`nindent_size = 4`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'replaces an existing managed block with the same name' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = latin1`n# END DO NOT EDIT`n"

			InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8`nend_of_line = lf"
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`nend_of_line = lf`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'preserves other managed blocks with different names' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: csharp convention`n[*.cs]`nindent_size = 4`n# END DO NOT EDIT`n"

			InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n`n# DO NOT EDIT: csharp convention`n[*.cs]`nindent_size = 4`n# END DO NOT EDIT`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'fails on duplicate blocks for the same name' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n# END DO NOT EDIT`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`nindent_style = space`n# END DO NOT EDIT`n"

			{ InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{ name = 'general-editorconfig'; text = '[*]' } } | Should Throw "Found multiple managed blocks named 'general-editorconfig' in '.editorconfig'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'fails on an unterminated managed block' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`n`n# DO NOT EDIT: general-editorconfig convention`n[*]`ncharset = utf-8`n"

			{ InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{ name = 'general-editorconfig'; text = '[*]' } } | Should Throw "Found an unterminated managed block for 'general-editorconfig' in '.editorconfig'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'supports multi-line text input and preserves CRLF files' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content "root = true`r`n`r`n[*.cs]`r`nindent_size = 4`r`n"

			InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8`ntrim_trailing_whitespace = true"
			}

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`r`n`r`n[*.cs]`r`nindent_size = 4`r`n`r`n# DO NOT EDIT: general-editorconfig convention`r`n[*]`r`ncharset = utf-8`r`ntrim_trailing_whitespace = true`r`n# END DO NOT EDIT`r`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent on a second run' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'

			InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
			}
			$expectedWriteTime = [datetime]::SpecifyKind([datetime]::Parse('2001-02-03T04:05:06Z'), [System.DateTimeKind]::Utc)
			[System.IO.File]::SetLastWriteTimeUtc($targetPath, $expectedWriteTime)

			$output = InvokeEditorconfigConvention -TestDirectory $testDirectory -Settings @{
				name = 'general-editorconfig'
				text = "[*]`ncharset = utf-8"
			}

			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should Be $expectedWriteTime
			$output[-1].ToString() | Should Be "'$targetPath' already contains the 'general-editorconfig' section."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

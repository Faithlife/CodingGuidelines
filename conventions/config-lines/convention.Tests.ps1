Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeConfigLinesConvention {
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

Describe 'config-lines convention' {
	It 'creates a repository-root-relative file and is idempotent' {
		$testDirectory = New-TestDirectory

		try {
			$output = InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; entries = @('bin/', 'obj/') }
			$gitignorePath = Join-Path $testDirectory '.gitignore'

			(Test-Path -LiteralPath $gitignorePath) | Should Be $true
			(Get-Content -LiteralPath $gitignorePath -Raw) | Should Be "bin/`nobj/`n"
			$output[-1].ToString() | Should Be "Added 2 entries to '$gitignorePath'."

			$secondOutput = InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; entries = @('bin/', 'obj/') }

			(Get-Content -LiteralPath $gitignorePath -Raw) | Should Be "bin/`nobj/`n"
			$secondOutput[-1].ToString() | Should Be "'$gitignorePath' already contains all configured entries."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'resolves relative paths from the repository root' {
		$testDirectory = New-TestDirectory

		try {
			InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = 'workflows/ci.yml'; entries = @('name: CI') }
			$targetPath = Join-Path $testDirectory 'workflows\ci.yml'

			(Test-Path -LiteralPath $targetPath) | Should Be $true
			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "name: CI`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'appends only entries that are not already present' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			Write-Utf8NoBomFile -Path $targetPath -Content 'root = true'

			InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; entries = @('root = true', '[*]') }

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n[*]`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not touch the target file when all configured entries already exist' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.gitignore'
			Write-Utf8NoBomFile -Path $targetPath -Content "bin/`nobj/`n"
			$expectedWriteTime = [datetime]::SpecifyKind([datetime]::Parse('2001-02-03T04:05:06Z'), [System.DateTimeKind]::Utc)
			[System.IO.File]::SetLastWriteTimeUtc($targetPath, $expectedWriteTime)

			$output = InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '.gitignore'; entries = @('bin/', 'obj/') }

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "bin/`nobj/`n"
			([System.IO.File]::GetLastWriteTimeUtc($targetPath)) | Should Be $expectedWriteTime
			$output[-1].ToString() | Should Be "'$targetPath' already contains all configured entries."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not create the target file when the configured entries list is empty' {
		$testDirectory = New-TestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.gitignore'

			$output = InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '.gitignore'; entries = @() }

			(Test-Path -LiteralPath $targetPath) | Should Be $false
			$output[-1].ToString() | Should Be "No configured entries to add for '$targetPath'."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'rejects entries that contain newlines' {
		$testDirectory = New-TestDirectory

		try {
			{ InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; entries = @("bin/`nobj/") } } | Should Throw "Each entry in 'entries' must be a single line."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

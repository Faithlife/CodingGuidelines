Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'

function NewTestDirectory {
	$path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
	[System.IO.Directory]::CreateDirectory($path) | Out-Null
	return $path
}

function WriteUtf8NoBomFile {
	param(
		[Parameter(Mandatory = $true)]
		[string] $Path,

		[Parameter(Mandatory = $true)]
		[string] $Content
	)

	$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
	[System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function InvokeConfigLinesConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory,

		[Parameter(Mandatory = $true)]
		[hashtable] $Settings
	)

	$inputPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
	$inputJson = @{ settings = $Settings } | ConvertTo-Json -Depth 10 -Compress
	WriteUtf8NoBomFile -Path $inputPath -Content $inputJson

	try {
		Push-Location $TestDirectory
		try {
			return @(& $conventionScriptPath $inputPath 6>&1)
		}
		finally {
			Pop-Location
		}
	}
	finally {
		Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
	}
}

Describe 'config-lines convention' {
	It 'creates a repository-root-relative file and is idempotent' {
		$testDirectory = NewTestDirectory

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
		$testDirectory = NewTestDirectory

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
		$testDirectory = NewTestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.editorconfig'
			WriteUtf8NoBomFile -Path $targetPath -Content 'root = true'

			InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '/.editorconfig'; entries = @('root = true', '[*]') }

			(Get-Content -LiteralPath $targetPath -Raw) | Should Be "root = true`n[*]`n"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not touch the target file when all configured entries already exist' {
		$testDirectory = NewTestDirectory

		try {
			$targetPath = Join-Path $testDirectory '.gitignore'
			WriteUtf8NoBomFile -Path $targetPath -Content "bin/`nobj/`n"
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
		$testDirectory = NewTestDirectory

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
		$testDirectory = NewTestDirectory

		try {
			{ InvokeConfigLinesConvention -TestDirectory $testDirectory -Settings @{ path = '/.gitignore'; entries = @("bin/`nobj/") } } | Should Throw "Each entry in 'entries' must be a single line."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

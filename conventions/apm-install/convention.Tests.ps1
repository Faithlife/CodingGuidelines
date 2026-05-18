#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the apm-install convention.
Describe 'apm-install convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Create a fake apm executable for the current platform.
		function script:NewFakeApmCommand {
			param(
				[Parameter(Mandatory = $true)]
				[string] $ToolDirectory,

				[Parameter(Mandatory = $true)]
				[string] $WindowsScript,

				[Parameter(Mandatory = $true)]
				[string] $BashScript
			)

			if ($IsWindows) {
				$commandPath = Join-Path $ToolDirectory 'apm.cmd'
				Set-Content -LiteralPath $commandPath -Value $WindowsScript -Encoding ascii
			}
			else {
				$commandPath = Join-Path $ToolDirectory 'apm'
				Set-Content -LiteralPath $commandPath -Value $BashScript
				& chmod +x $commandPath
				if ($LASTEXITCODE -ne 0) {
					throw 'Failed to mark fake apm script as executable.'
				}
			}
		}
	}

	It 'exits successfully without invoking apm when there is no apm.yml and no configured packages' {
		# Set up an empty repository and a fake apm invocation marker.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$apmInvocationPath = Join-Path $toolDirectory 'apm-invoked.txt'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange the fake apm command on PATH without any convention inputs.
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
> "%APM_INVOCATION_PATH%" echo invoked
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf 'invoked\n' > "$APM_INVOCATION_PATH"
exit 0
'@
			$env:APM_INVOCATION_PATH = $apmInvocationPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and verify it leaves the repository untouched.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Test-Path -LiteralPath $apmInvocationPath | Should -Be $false
			(Get-GitStatusLines -TestDirectory $testDirectory) | Should -BeNullOrEmpty
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_INVOCATION_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'runs apm install --update --target copilot' {
		# Set up a repository with apm.yml and a fake argument capture file.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that records its argument list.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$APM_ARGUMENTS_PATH"
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it invokes apm with the default arguments.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install --update --target copilot'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes configured packages to apm install --update --target copilot' {
		# Set up convention input that includes configured apm packages.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = Join-Path $testDirectory 'tools'
		$argumentsPath = Join-Path $testDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{
			packages = @(
				'richlander/dotnet-inspect/skills/dotnet-inspect'
				'microsoft/playwright-cli/skills/playwright-cli'
			)
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that records package arguments.
			New-Item -ItemType Directory -Path $toolDirectory | Out-Null
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$APM_ARGUMENTS_PATH"
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert configured packages are appended.
			{ & $conventionScriptPath $inputPath } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install --update --target copilot richlander/dotnet-inspect/skills/dotnet-inspect microsoft/playwright-cli/skills/playwright-cli'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'reverts apm.lock.yaml when it is the only changed file' {
		# Set up a repository where apm can only update the lock file.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH
		$originalLockContent = "packages:`n  sample: 1.0.0`n"

		try {
			# Arrange committed apm files and a fake command that modifies the lock file.
			[System.IO.File]::WriteAllText($lockFilePath, $originalLockContent, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`n", $utf8)
			Initialize-TestRepository -Path $testDirectory

			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%CD%\apm.lock.yaml" echo updated: true
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf 'updated: true\n' >> "$PWD/apm.lock.yaml"
exit 0
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert the lock-only change is reverted.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Be $originalLockContent
			(Get-GitStatusLines -TestDirectory $testDirectory) | Should -BeNullOrEmpty
		}
		finally {
			# Restore process state and remove temporary repositories.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'keeps apm.lock.yaml when apm also changes another file' {
		# Set up a repository where apm updates the lock file and package metadata.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$packageFilePath = Join-Path $testDirectory 'package.json'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange committed files and a fake command that modifies both files.
			[System.IO.File]::WriteAllText($lockFilePath, "packages:`n  sample: 1.0.0`n", $utf8)
			[System.IO.File]::WriteAllText($packageFilePath, "{}`n", $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`n", $utf8)
			Initialize-TestRepository -Path $testDirectory

			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%CD%\apm.lock.yaml" echo updated: true
>> "%CD%\package.json" echo // updated
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf 'updated: true\n' >> "$PWD/apm.lock.yaml"
printf '// updated\n' >> "$PWD/package.json"
exit 0
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it preserves meaningful apm changes.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Match 'updated: true'
			Get-GitStatusLines -TestDirectory $testDirectory | Should -Be @(' M apm.lock.yaml', ' M package.json')
		}
		finally {
			# Restore process state and remove temporary repositories.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

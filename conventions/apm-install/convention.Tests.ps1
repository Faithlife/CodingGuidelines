#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'apm-install convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath

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
		$testDirectory = New-TestDirectory
		$toolDirectory = New-TestDirectory
		$apmInvocationPath = Join-Path $toolDirectory 'apm-invoked.txt'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
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

			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Test-Path -LiteralPath $apmInvocationPath | Should -Be $false
			(Get-GitStatusLines -TestDirectory $testDirectory) | Should -BeNullOrEmpty
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item Env:APM_INVOCATION_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'ignores the input path and runs apm install --update' {
		$testDirectory = New-TestDirectory
		$toolDirectory = New-TestDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$originalPath = $env:PATH

		try {
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'apm.yml') -Content "packages: []`n"
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

			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath (Join-Path $testDirectory 'missing-input.json') } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install --update'
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes configured packages to apm install --update' {
		$testDirectory = New-TestDirectory
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

			{ & $conventionScriptPath $inputPath } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install --update richlander/dotnet-inspect/skills/dotnet-inspect microsoft/playwright-cli/skills/playwright-cli'
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'reverts apm.lock.yaml when it is the only changed file' {
		$testDirectory = New-TestDirectory
		$toolDirectory = New-TestDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$originalPath = $env:PATH
		$originalLockContent = "packages:`n  sample: 1.0.0`n"

		try {
			Write-Utf8NoBomFile -Path $lockFilePath -Content $originalLockContent
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'apm.yml') -Content "packages: []`n"
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

			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory } | Should -Not -Throw
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Be $originalLockContent
			(Get-GitStatusLines -TestDirectory $testDirectory) | Should -BeNullOrEmpty
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'keeps apm.lock.yaml when apm also changes another file' {
		$testDirectory = New-TestDirectory
		$toolDirectory = New-TestDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$packageFilePath = Join-Path $testDirectory 'package.json'
		$originalPath = $env:PATH

		try {
			Write-Utf8NoBomFile -Path $lockFilePath -Content "packages:`n  sample: 1.0.0`n"
			Write-Utf8NoBomFile -Path $packageFilePath -Content "{}`n"
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'apm.yml') -Content "packages: []`n"
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

			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory } | Should -Not -Throw
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Match 'updated: true'
			Get-GitStatusLines -TestDirectory $testDirectory | Should -Be @(' M apm.lock.yaml', ' M package.json')
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'apm-install convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'exits successfully without invoking apm when there is no apm.yml and no configured packages' {
		$testDirectory = New-TestDirectory
		$toolDirectory = New-TestDirectory
		$apmCommandPath = Join-Path $toolDirectory 'apm.cmd'
		$apmInvocationPath = Join-Path $toolDirectory 'apm-invoked.txt'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			Initialize-TestRepository -Path $testDirectory
			$apmCommand = @"
@echo off
> "%APM_INVOCATION_PATH%" echo invoked
exit /b 0
"@
			Set-Content -LiteralPath $apmCommandPath -Value $apmCommand -Encoding ascii
			$env:APM_INVOCATION_PATH = $apmInvocationPath
			$env:PATH = "$toolDirectory;$originalPath"

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
		$toolDirectory = Join-Path $testDirectory 'tools'
		$argumentsPath = Join-Path $testDirectory 'apm-arguments.txt'
		$apmCommandPath = Join-Path $toolDirectory 'apm.cmd'
		$originalPath = $env:PATH

		try {
			New-Item -ItemType Directory -Path $toolDirectory | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'apm.yml') -Content "packages: []`n"
			$apmCommand = @"
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
"@
			Set-Content -LiteralPath $apmCommandPath -Value $apmCommand -Encoding ascii

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = "$toolDirectory;$originalPath"

			{ & $conventionScriptPath (Join-Path $testDirectory 'missing-input.json') } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install --update'
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes configured packages to apm install --update' {
		$testDirectory = New-TestDirectory
		$toolDirectory = Join-Path $testDirectory 'tools'
		$argumentsPath = Join-Path $testDirectory 'apm-arguments.txt'
		$apmCommandPath = Join-Path $toolDirectory 'apm.cmd'
		$inputPath = New-ConventionInputFile -Settings @{
			packages = @(
				'richlander/dotnet-inspect/skills/dotnet-inspect'
				'microsoft/playwright-cli/skills/playwright-cli'
			)
		}
		$originalPath = $env:PATH

		try {
			New-Item -ItemType Directory -Path $toolDirectory | Out-Null
			$apmCommand = @"
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
"@
			Set-Content -LiteralPath $apmCommandPath -Value $apmCommand -Encoding ascii

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = "$toolDirectory;$originalPath"

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
		$apmCommandPath = Join-Path $toolDirectory 'apm.cmd'
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$originalPath = $env:PATH
		$originalLockContent = "packages:`n  sample: 1.0.0`n"

		try {
			Write-Utf8NoBomFile -Path $lockFilePath -Content $originalLockContent
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'apm.yml') -Content "packages: []`n"
			Initialize-TestRepository -Path $testDirectory

			$apmCommand = @"
@echo off
setlocal
>> "%CD%\apm.lock.yaml" echo updated: true
exit /b 0
"@
			Set-Content -LiteralPath $apmCommandPath -Value $apmCommand -Encoding ascii
			$env:PATH = "$toolDirectory;$originalPath"

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
		$apmCommandPath = Join-Path $toolDirectory 'apm.cmd'
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$packageFilePath = Join-Path $testDirectory 'package.json'
		$originalPath = $env:PATH

		try {
			Write-Utf8NoBomFile -Path $lockFilePath -Content "packages:`n  sample: 1.0.0`n"
			Write-Utf8NoBomFile -Path $packageFilePath -Content "{}`n"
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'apm.yml') -Content "packages: []`n"
			Initialize-TestRepository -Path $testDirectory

			$apmCommand = @"
@echo off
setlocal
>> "%CD%\apm.lock.yaml" echo updated: true
>> "%CD%\package.json" echo // updated
exit /b 0
"@
			Set-Content -LiteralPath $apmCommandPath -Value $apmCommand -Encoding ascii
			$env:PATH = "$toolDirectory;$originalPath"

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

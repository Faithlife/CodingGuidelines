Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'

function NewTestDirectory {
	$path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
	[System.IO.Directory]::CreateDirectory($path) | Out-Null
	return $path
}

Describe 'apm-install-updates convention' {
	It 'ignores the input path and runs apm install --update' {
		$testDirectory = NewTestDirectory
		$toolDirectory = Join-Path $testDirectory 'tools'
		$argumentsPath = Join-Path $testDirectory 'apm-arguments.txt'
		$apmCommandPath = Join-Path $toolDirectory 'apm.cmd'
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

			{ & $conventionScriptPath (Join-Path $testDirectory 'missing-input.json') } | Should Not Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should Be 'install --update'
		}
		finally {
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

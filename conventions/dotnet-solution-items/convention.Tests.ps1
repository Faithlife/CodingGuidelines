#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the dotnet-solution-items convention.
Describe 'dotnet-solution-items convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Create a fake dnx executable for the current platform.
		function script:NewFakeDnxCommand {
			param(
				[Parameter(Mandatory = $true)]
				[string] $ToolDirectory,

				[Parameter(Mandatory = $true)]
				[string] $WindowsScript,

				[Parameter(Mandatory = $true)]
				[string] $BashScript
			)

			# Write the platform-specific fake command into the temporary tool directory.
			if ($IsWindows) {
				$commandPath = Join-Path $ToolDirectory 'dnx.cmd'
				Set-Content -LiteralPath $commandPath -Value $WindowsScript -Encoding ascii
			}
			else {
				$commandPath = Join-Path $ToolDirectory 'dnx'
				Set-Content -LiteralPath $commandPath -Value $BashScript
				& chmod +x $commandPath
				if ($LASTEXITCODE -ne 0) {
					throw 'Failed to mark fake dnx script as executable.'
				}
			}
		}

		# Invoke the convention against the supplied temporary repository.
		function script:InvokeDotnetSolutionItemsConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[Parameter(Mandatory = $true)]
				[hashtable] $Settings
			)

			# Create and clean up the RepoConventions input file for this invocation.
			$inputPath = New-ConventionInputFile -Settings $Settings
			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}
	}

	It 'runs dotnet-solution-items update by default' {
		# Set up a repository and fake argument capture file.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'dnx-arguments.txt'
		$originalPath = $env:PATH

		try {
			# Arrange a fake dnx command that records its argument list.
			NewFakeDnxCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%DNX_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$DNX_ARGUMENTS_PATH"
exit 0
'@
			$env:DNX_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it invokes the update command.
			$output = InvokeDotnetSolutionItemsConvention -TestDirectory $testDirectory -Settings @{}
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be '-y dotnet-solution-items update'
			$output[0].ToString() | Should -Be 'Running dnx -y dotnet-solution-items update.'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:DNX_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'adds configured solution items instead of updating' {
		# Set up configured items and a fake argument capture file.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'dnx-arguments.txt'
		$settings = @{
			items = @(
				'README.md'
				'.github/workflows/ci.yml'
			)
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake dnx command that records its argument list.
			NewFakeDnxCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%DNX_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$DNX_ARGUMENTS_PATH"
exit 0
'@
			$env:DNX_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it invokes the forced add command.
			$output = InvokeDotnetSolutionItemsConvention -TestDirectory $testDirectory -Settings $settings
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be '-y dotnet-solution-items add --force README.md .github/workflows/ci.yml'
			$output[0].ToString() | Should -Be 'Running dnx -y dotnet-solution-items add --force README.md .github/workflows/ci.yml.'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:DNX_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'fails when dnx returns a non-zero exit code' {
		# Set up a failing fake dnx command.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$originalPath = $env:PATH

		try {
			# Arrange a fake dnx command that simulates a tool failure.
			NewFakeDnxCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
exit /b 3
'@ -BashScript @'
#!/usr/bin/env bash
exit 3
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert the failure identifies the delegated command.
			{ InvokeDotnetSolutionItemsConvention -TestDirectory $testDirectory -Settings @{} } | Should -Throw 'dnx dotnet-solution-items update failed.'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

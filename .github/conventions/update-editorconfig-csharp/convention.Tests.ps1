#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the update-editorconfig-csharp convention.
Describe 'update-editorconfig-csharp convention' {
	BeforeAll {
		# Load shared test helpers used by the convention tests.
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates the published C# editorconfig source file from markdown' {
		# Create an isolated repository for the generation scenario.
		$testDirectory = New-TemporaryDirectory

		try {
			# Copy the convention and real source inputs into the isolated repository.
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github' 'conventions' 'update-editorconfig-csharp')) | Out-Null
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'convention.ps1') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/README.md') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'editorconfig-csharp') -Destination (Join-Path $testDirectory 'conventions' 'editorconfig-csharp') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'scripts') -Destination (Join-Path $testDirectory 'conventions' 'scripts') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'sections' 'csharp') -Destination (Join-Path $testDirectory 'sections' 'csharp') -Recurse
			Remove-Item -LiteralPath (Join-Path $testDirectory 'conventions' 'editorconfig-csharp' 'files' '.editorconfig') -Force -ErrorAction SilentlyContinue
			Initialize-TestRepository -Path $testDirectory

			# Run the convention against the isolated repository.
			{ Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory } | Should -Not -Throw

			# Compare the generated file with the checked-in expected output.
			$generatedPath = Join-Path $testDirectory 'conventions' 'editorconfig-csharp' 'files' '.editorconfig'
			$expectedPath = Join-Path ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..' '..')) ) 'conventions' 'editorconfig-csharp' 'files' '.editorconfig'

			(Test-Path -LiteralPath $generatedPath) | Should -Be $true
			(Test-FileContentMatches -ExpectedPath $expectedPath -ActualPath $generatedPath) | Should -Be $true
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'separates sections and sorts indentation settings first within each section' {
		# Create an isolated repository for the custom markdown scenario.
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange only the convention files needed for a focused markdown input.
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github' 'conventions' 'update-editorconfig-csharp')) | Out-Null
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory 'conventions' 'editorconfig-csharp' 'files')) | Out-Null
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory 'sections' 'csharp')) | Out-Null
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'convention.ps1') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'scripts') -Destination (Join-Path $testDirectory 'conventions' 'scripts') -Recurse

			# Write markdown that exercises section separation and indentation sorting.
			$markdownContent = (@(
				'# .editorconfig for C#'
				''
				'```editorconfig'
				'[*.props]'
				'zeta = true'
				'indent_style = space'
				'indent_size = 2'
				'```'
				''
				'```editorconfig'
				'[*.cs]'
				'beta = true'
				'tab_width = 4'
				'alpha = true'
				'indent_style = tab'
				'indent_size = 4'
				'```'
			) -join "`n") + "`n"
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'sections' 'csharp' 'editorconfig.md'), $markdownContent, $utf8)
			Initialize-TestRepository -Path $testDirectory

			# Run the convention against the isolated repository.
			{ Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory } | Should -Not -Throw

			# Assert the generated editorconfig preserves sections and sorts settings.
			$generatedPath = Join-Path $testDirectory 'conventions' 'editorconfig-csharp' 'files' '.editorconfig'
			$expectedContent = (@(
				'# generated from https://github.com/Faithlife/CodingGuidelines/blob/master/sections/csharp/editorconfig.md'
				'[*.props]'
				'indent_size = 2'
				'indent_style = space'
				'zeta = true'
				''
				'[*.cs]'
				'indent_size = 4'
				'indent_style = tab'
				'tab_width = 4'
				'alpha = true'
				'beta = true'
			) -join "`n") + "`n"

			Get-Content -LiteralPath $generatedPath -Raw | Should -Be $expectedContent
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the generated file is committed' {
		# Create an isolated repository for the idempotency scenario.
		$testDirectory = New-TemporaryDirectory

		try {
			# Copy the convention and real source inputs into the isolated repository.
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github' 'conventions' 'update-editorconfig-csharp')) | Out-Null
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'convention.ps1') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/README.md') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'editorconfig-csharp') -Destination (Join-Path $testDirectory 'conventions' 'editorconfig-csharp') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'conventions' 'scripts') -Destination (Join-Path $testDirectory 'conventions' 'scripts') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..' 'sections' 'csharp') -Destination (Join-Path $testDirectory 'sections' 'csharp') -Recurse
			Remove-Item -LiteralPath (Join-Path $testDirectory 'conventions' 'editorconfig-csharp' 'files' '.editorconfig') -Force -ErrorAction SilentlyContinue
			Initialize-TestRepository -Path $testDirectory

			# Generate the file once before committing the isolated repository.
			Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory | Out-Null

			# Commit the generated output so the second run can verify idempotency.
			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add generated editorconfig' | Out-Null
			}
			finally {
				# Restore the caller location after committing in the test repository.
				Pop-Location
			}

			# Run the convention again and verify it leaves no git changes.
			Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory | Out-Null

			@(Get-GitStatusLines -TestDirectory $testDirectory).Count | Should -Be 0
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

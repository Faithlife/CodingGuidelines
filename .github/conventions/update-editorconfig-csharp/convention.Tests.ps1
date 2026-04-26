#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'update-editorconfig-csharp convention' {
	BeforeAll {
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\..\..\conventions\scripts\TestHelpers.ps1'
		. $script:testHelpersPath
	}

	It 'creates the published C# editorconfig source file from markdown' {
		$testDirectory = New-TestDirectory

		try {
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github\conventions\update-editorconfig-csharp')) | Out-Null
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'convention.ps1') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/README.md') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\conventions\editorconfig-csharp') -Destination (Join-Path $testDirectory 'conventions\editorconfig-csharp') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\conventions\scripts') -Destination (Join-Path $testDirectory 'conventions\scripts') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\sections\csharp') -Destination (Join-Path $testDirectory 'sections\csharp') -Recurse
			Remove-Item -LiteralPath (Join-Path $testDirectory 'conventions\editorconfig-csharp\files\.editorconfig') -Force -ErrorAction SilentlyContinue
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory } | Should -Not -Throw

			$generatedPath = Join-Path $testDirectory 'conventions\editorconfig-csharp\files\.editorconfig'
			$expectedPath = Join-Path ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..')) ) 'conventions\editorconfig-csharp\files\.editorconfig'

			(Test-Path -LiteralPath $generatedPath) | Should -Be $true
			(Test-FileContentMatches -ExpectedPath $expectedPath -ActualPath $generatedPath) | Should -Be $true
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'separates sections and sorts indentation settings first within each section' {
		$testDirectory = New-TestDirectory

		try {
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github\conventions\update-editorconfig-csharp')) | Out-Null
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory 'conventions\editorconfig-csharp\files')) | Out-Null
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory 'sections\csharp')) | Out-Null
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'convention.ps1') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\conventions\scripts') -Destination (Join-Path $testDirectory 'conventions\scripts') -Recurse

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
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory 'sections\csharp\editorconfig.md') -Content $markdownContent
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory } | Should -Not -Throw

			$generatedPath = Join-Path $testDirectory 'conventions\editorconfig-csharp\files\.editorconfig'
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
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the generated file is committed' {
		$testDirectory = New-TestDirectory

		try {
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github\conventions\update-editorconfig-csharp')) | Out-Null
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'convention.ps1') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') -Destination (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/README.md') -Force
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\conventions\editorconfig-csharp') -Destination (Join-Path $testDirectory 'conventions\editorconfig-csharp') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\conventions\scripts') -Destination (Join-Path $testDirectory 'conventions\scripts') -Recurse
			Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\..\..\sections\csharp') -Destination (Join-Path $testDirectory 'sections\csharp') -Recurse
			Remove-Item -LiteralPath (Join-Path $testDirectory 'conventions\editorconfig-csharp\files\.editorconfig') -Force -ErrorAction SilentlyContinue
			Initialize-TestRepository -Path $testDirectory

			Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add generated editorconfig.' | Out-Null
			}
			finally {
				Pop-Location
			}

			Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory | Out-Null

			@(Get-GitStatusLines -TestDirectory $testDirectory).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
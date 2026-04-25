#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\..\..\conventions\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'update-editorconfig-csharp convention' {
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

			{ Invoke-ConventionScript -ScriptPath (Join-Path $testDirectory '.github/conventions/update-editorconfig-csharp/convention.ps1') -RepositoryRoot $testDirectory } | Should Not Throw

			$generatedPath = Join-Path $testDirectory 'conventions\editorconfig-csharp\files\.editorconfig'
			$expectedPath = Join-Path ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..')) ) 'conventions\editorconfig-csharp\files\.editorconfig'

			(Test-Path -LiteralPath $generatedPath) | Should Be $true
			(Test-FileContentMatches -ExpectedPath $expectedPath -ActualPath $generatedPath) | Should Be $true
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

			@(Get-GitStatusLines -TestDirectory $testDirectory).Count | Should Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
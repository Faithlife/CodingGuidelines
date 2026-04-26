#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'faithlife-build-library-project convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedBuildCsPath = Join-Path $PSScriptRoot 'files\Build.cs'
		$script:expectedBuildCsprojPath = Join-Path $PSScriptRoot 'files\Build.csproj.xml'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeFaithlifeBuildLibraryProjectConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			$inputPath = New-ConventionInputFile -Settings @{}

			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}

		function script:SetSolutionFileContent {
			param(
				[Parameter(Mandatory = $true)]
				[string] $Path
			)

			$solutionContent = @"
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Global
    GlobalSection(SolutionProperties) = preSolution
        HideSolutionNode = FALSE
    EndGlobalSection
EndGlobal
"@

			Write-Utf8NoBomFile -Path $Path -Content $solutionContent
		}

		function script:GetAllGitStatusLines {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			Push-Location $TestDirectory
			try {
				return @(& git status --short --untracked-files=all)
			}
			finally {
				Pop-Location
			}
		}
	}

	It 'creates both files, creates a root solution, and adds the project when they are missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeFaithlifeBuildLibraryProjectConvention -TestDirectory $testDirectory
			$solutionPaths = @(
				Get-ChildItem -LiteralPath $testDirectory -File |
					Where-Object { $_.Extension -in '.sln', '.slnx' }
			)
			$buildCsPath = Join-Path $testDirectory 'tools/Build/Build.cs'
			$buildCsprojPath = Join-Path $testDirectory 'tools/Build/Build.csproj'
			$status = @(GetAllGitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $buildCsPath) | Should -Be $true
			(Test-Path -LiteralPath $buildCsprojPath) | Should -Be $true
			$solutionPaths.Count | Should -Be 1
			(Get-Content -LiteralPath $buildCsPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedBuildCsPath -Raw)
			(Get-Content -LiteralPath $buildCsprojPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedBuildCsprojPath -Raw)
			$status.Count | Should -Be 3
			$status[0] | Should -Match '^\?\? .+\.slnx?$'
			$status[1] | Should -Match '^\?\? tools/Build/Build\.cs$'
			$status[2] | Should -Match '^\?\? tools/Build/Build\.csproj$'
			$output.Count | Should -Be 4
			$output[0].ToString() | Should -Match "Created '.+tools\\Build\\Build\.cs'\."
			$output[1].ToString() | Should -Match "Created '.+tools\\Build\\Build\.csproj'\."
			$output[2].ToString() | Should -Be 'Creating a root solution with dotnet new sln.'
			$output[3].ToString() | Should -Be "Adding './tools/Build' to the root solution."

			Push-Location $testDirectory
			try {
				$listedProjects = @(& dotnet sln list)
			}
			finally {
				Pop-Location
			}

			($listedProjects -join "`n") | Should -Match 'tools[/\\]Build[/\\]Build\.csproj'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'leaves existing files unchanged' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$buildDirectoryPath = Join-Path $testDirectory 'tools/Build'
			$buildCsPath = Join-Path $buildDirectoryPath 'Build.cs'
			$buildCsprojPath = Join-Path $buildDirectoryPath 'Build.csproj'
			New-Item -ItemType Directory -Path $buildDirectoryPath -Force | Out-Null
			Write-Utf8NoBomFile -Path $buildCsPath -Content "existing build cs`n"
			Write-Utf8NoBomFile -Path $buildCsprojPath -Content "existing build csproj`n"

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add build files.' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeFaithlifeBuildLibraryProjectConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			((Get-Content -LiteralPath $buildCsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'existing build cs'
			((Get-Content -LiteralPath $buildCsprojPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'existing build csproj'
			$status.Count | Should -Be 0
			@($output).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'adds tools/Build to an existing root solution when it copies Build.csproj' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$solutionPath = Join-Path $testDirectory 'Test.sln'
			$buildCsPath = Join-Path $testDirectory 'tools/Build/Build.cs'
			New-Item -ItemType Directory -Path (Split-Path -Parent $buildCsPath) -Force | Out-Null
			SetSolutionFileContent -Path $solutionPath
			Write-Utf8NoBomFile -Path $buildCsPath -Content (Get-Content -LiteralPath $expectedBuildCsPath -Raw)

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add solution and Build.cs.' | Out-Null
			}
			finally {
				Pop-Location
			}

			$output = InvokeFaithlifeBuildLibraryProjectConvention -TestDirectory $testDirectory
			$buildCsprojPath = Join-Path $testDirectory 'tools/Build/Build.csproj'
			$status = @(GetAllGitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath $buildCsprojPath) | Should -Be $true
			(Get-Content -LiteralPath $buildCsprojPath -Raw) | Should -Be (Get-Content -LiteralPath $expectedBuildCsprojPath -Raw)
			$status.Count | Should -Be 2
			$status[0] | Should -Match '^ M Test\.sln$'
			$status[1] | Should -Match '^\?\? tools/Build/Build\.csproj$'
			$output.Count | Should -Be 2
			$output[0].ToString() | Should -Match "Created '.+tools\\Build\\Build\.csproj'\."
			$output[1].ToString() | Should -Be "Adding './tools/Build' to the root solution."

			Push-Location $testDirectory
			try {
				$listedProjects = @(& dotnet sln list)
			}
			finally {
				Pop-Location
			}

			($listedProjects -join "`n") | Should -Match 'tools[/\\]Build[/\\]Build\.csproj'
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			InvokeFaithlifeBuildLibraryProjectConvention -TestDirectory $testDirectory | Out-Null

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add build library project.' | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
			}
			finally {
				Pop-Location
			}

			$output = InvokeFaithlifeBuildLibraryProjectConvention -TestDirectory $testDirectory
			$headAfterSecondRun = Get-CommitId -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
			@($output).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

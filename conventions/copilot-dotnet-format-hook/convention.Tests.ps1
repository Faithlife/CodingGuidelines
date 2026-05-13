#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'copilot-dotnet-format-hook convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:expectedHookScriptPath = Join-Path $PSScriptRoot 'dotnet-format.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory
		}

		function script:GetOutputText {
			param(
				[Parameter(Mandatory = $true)]
				[object[]] $Output
			)

			return (@($Output | ForEach-Object { $_.ToString() }) -join "`n")
		}

		function script:ReadHooksJson {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			$path = Join-Path $TestDirectory '.github' 'hooks' 'hooks.json'
			return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
		}

		$script:expectedHookEntry = @{
			type = 'command'
			bash = 'pwsh .github/hooks/scripts/dotnet-format.ps1'
			powershell = '.github/hooks/scripts/dotnet-format.ps1'
			cwd = '.'
			timeoutSec = 30
		}
	}

	It 'creates both files when neither exists' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeConvention -TestDirectory $testDirectory

			$hookScriptPath = Join-Path $testDirectory '.github' 'hooks' 'scripts' 'dotnet-format.ps1'
			$hooksJsonPath = Join-Path $testDirectory '.github' 'hooks' 'hooks.json'
			$hooksJson = ReadHooksJson -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)
			$outputText = GetOutputText -Output $output

			(Test-Path -LiteralPath $hookScriptPath) | Should -Be $true
			(Get-Content -LiteralPath $hookScriptPath -Raw) | Should -Be (Get-Content -LiteralPath $script:expectedHookScriptPath -Raw)
			(Test-Path -LiteralPath $hooksJsonPath) | Should -Be $true
			$hooksJson['hooks']['postToolUse'].Count | Should -Be 1
			$hooksJson['hooks']['postToolUse'][0]['powershell'] | Should -Be '.github/hooks/scripts/dotnet-format.ps1'
			$hooksJson['hooks']['postToolUse'][0]['bash'] | Should -Be 'pwsh .github/hooks/scripts/dotnet-format.ps1'
			$hooksJson['hooks']['postToolUse'][0]['timeoutSec'] | Should -Be 30
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^\?\? \.github/$'
			$outputText | Should -Match "Created '\.github/hooks/scripts/dotnet-format\.ps1'\."
			$outputText | Should -Match "Created '\.github/hooks/hooks\.json' with the dotnet-format hook\."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'merges the hook entry when hooks.json already has other entries' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$existingHooksDir = Join-Path $testDirectory '.github' 'hooks'
			[System.IO.Directory]::CreateDirectory($existingHooksDir) | Out-Null

			$existingHooksJson = @{
				version = 1
				hooks = @{
					postToolUse = @(
						@{
							type = 'command'
							bash = 'echo other-hook'
							powershell = 'Write-Host other-hook'
							cwd = '.'
							timeoutSec = 10
						}
					)
				}
			}

			$helpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'Helpers.ps1'
			. $helpersPath
			Write-Utf8NoBomFile -Path (Join-Path $existingHooksDir 'hooks.json') -Content ($existingHooksJson | ConvertTo-Json -Depth 10)

			$output = InvokeConvention -TestDirectory $testDirectory

			$hooksJson = ReadHooksJson -TestDirectory $testDirectory
			$postToolUse = $hooksJson['hooks']['postToolUse']
			$outputText = GetOutputText -Output $output

			$postToolUse.Count | Should -Be 2
			$postToolUse[0]['powershell'] | Should -Be 'Write-Host other-hook'
			$postToolUse[1]['powershell'] | Should -Be '.github/hooks/scripts/dotnet-format.ps1'
			$outputText | Should -Match "Updated '\.github/hooks/hooks\.json' with the dotnet-format hook\."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent when both files are already correct' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$null = InvokeConvention -TestDirectory $testDirectory
			$statusAfterFirst = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$null = & git -C $testDirectory add -A
			$null = & git -C $testDirectory commit -m 'Apply convention'

			$output = InvokeConvention -TestDirectory $testDirectory
			$statusAfterSecond = @(Get-GitStatusLines -TestDirectory $testDirectory)
			$outputText = GetOutputText -Output $output

			$statusAfterSecond.Count | Should -Be 0
			$outputText | Should -Match "'\.github/hooks/scripts/dotnet-format\.ps1' is already up to date\."
			$outputText | Should -Match "'\.github/hooks/hooks\.json' already contains the dotnet-format hook\."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'produces no changes on a second run after compliance' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$null = InvokeConvention -TestDirectory $testDirectory
			$null = & git -C $testDirectory add -A
			$null = & git -C $testDirectory commit -m 'Apply convention'

			$null = InvokeConvention -TestDirectory $testDirectory
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			$status.Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

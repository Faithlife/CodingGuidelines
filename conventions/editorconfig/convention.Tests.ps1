Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

Describe 'editorconfig convention' {
	It 'creates .editorconfig with the configured managed section' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig
  settings:
    name: files
    text: |
      [*.txt]
      indent_style = space
      trim_trailing_whitespace = false
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			$editorConfigPath = Join-Path $testDirectory '.editorconfig'
			$content = Get-Content -LiteralPath $editorConfigPath -Raw

			(Test-Path -LiteralPath $editorConfigPath) | Should Be $true
			$content | Should Match "(?m)^root = true\r?$"
			$content | Should Match "(?m)^# DO NOT EDIT: files convention\r?$"
			$content | Should Match "(?m)^\[\*\.txt\]\r?$"
			$content | Should Match "(?m)^indent_style = space\r?$"
			$content | Should Match "(?m)^trim_trailing_whitespace = false\r?$"
			$content | Should Match "(?m)^# END DO NOT EDIT\r?$"
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'forwards agent instructions when it changes .editorconfig' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			$testCopilot = New-TestCopilotCommand -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig
  settings:
    name: files
    text: |
      [*.md]
      trim_trailing_whitespace = false
    agent:
      instructions: |
        Validate editorconfig changes.
        Leave fixes unstaged.
"@
			Initialize-TestRepository -Path $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory -CopilotCommandDirectory $testCopilot.CommandDirectory } | Should Not Throw

			(Test-Path -LiteralPath $testCopilot.InputPath) | Should Be $true
			(((Get-Content -LiteralPath $testCopilot.InputPath -Raw) -replace "`r`n", "`n").TrimEnd("`n")) | Should Be "Validate editorconfig changes.`nLeave fixes unstaged."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'forwards commit settings when it changes .editorconfig' {
		$testDirectory = New-TestDirectory

		try {
			Copy-TestConventionAssets -TestDirectory $testDirectory
			[System.IO.Directory]::CreateDirectory((Join-Path $testDirectory '.github')) | Out-Null
			Write-Utf8NoBomFile -Path (Join-Path $testDirectory '.github/conventions.yml') -Content @"
conventions:
- path: ../conventions/editorconfig
  settings:
    name: files
    text: |
      [*.md]
      trim_trailing_whitespace = false
    commit:
      message: Add editorconfig.
"@
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			{ Invoke-RepoConventionsApply -TestDirectory $testDirectory } | Should Not Throw

			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should Be $initialHead
			(@(Get-CommitSubjects -TestDirectory $testDirectory -Count 1))[0] | Should Be 'Add editorconfig.'
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

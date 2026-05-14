#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'gitattributes-lf convention' {
	BeforeAll {
		# Cache convention paths and load shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeGitattributesLfConvention {
			# Invoke the convention script with an empty settings file.
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

		function script:InvokeGitattributesLfConventionWithoutInput {
			# Invoke the convention script without an input file.
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory
			)

			return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory
		}
	}

	BeforeEach {
		# Stub Copilot so tests can assert whether it was invoked.
		$global:CopilotCallCount = 0

		function global:copilot {
			$global:CopilotCallCount++
		}
	}

	AfterEach {
		# Remove the global Copilot stub after each scenario.
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
	}

	It 'creates .gitattributes when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange an empty initialized repository.
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and collect commit and status state.
			$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory
			$commitSubjects = @(Get-CommitSubjects -TestDirectory $testDirectory -Count 2)
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert LF attributes were created, committed, and did not invoke Copilot.
			(Test-Path -LiteralPath (Join-Path $testDirectory '.gitattributes')) | Should -Be $true
			((Get-Content -LiteralPath (Join-Path $testDirectory '.gitattributes') -Raw).TrimEnd("`r", "`n")) | Should -Be '* text=auto eol=lf'
			$global:CopilotCallCount | Should -Be 0
			$output[0].ToString() | Should -Be "Creating '.gitattributes' with LF normalization enabled."
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			$commitSubjects[0] | Should -Be 'Use LF'
			$status.Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses Copilot and removes redundant eol rules from an existing file' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a repository with noncompliant attributes and CRLF content.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			$scriptPath = Join-Path $testDirectory 'script.ps1'
			$notesPath = Join-Path $testDirectory 'notes.txt'
			Write-Utf8NoBomFile -Path $gitattributesPath -Content "* -text`n*.ps1 text eol=crlf`n*.png binary`n"
			[System.IO.File]::WriteAllText($scriptPath, "Write-Host 'test'`r`n", [System.Text.UTF8Encoding]::new($false))
			[System.IO.File]::WriteAllText($notesPath, "line one`r`nline two`r`n", [System.Text.UTF8Encoding]::new($false))

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add gitattributes' | Out-Null

				function global:copilot {
					# Simulate Copilot rewriting attributes to the compliant shape.
					$global:CopilotCallCount++
					Write-Utf8NoBomFile -Path $gitattributesPath -Content "* text=auto eol=lf`n*.png binary`n"
				}

				# Apply the convention while the Copilot stub is in scope.
				$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory
			}
			finally {
				Pop-Location
			}

			# Assert Copilot was used and the final repository history is correct.
			$global:CopilotCallCount | Should -Be 1
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should -Match "^\* text=auto eol=lf\n"
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should -Match "\.png binary"
			(@($output | ForEach-Object { $_.ToString() }) -contains ".gitattributes is not compliant; starting Copilot to update '.gitattributes'.") | Should -Be $true
			$commitSubjects = @(Get-CommitSubjects -TestDirectory $testDirectory -Count 4)
			$commitSubjects[0] | Should -Be 'Ignore CRLF to LF for git blame'
			$commitSubjects[1] | Should -Be 'Convert CRLF to LF'
			$commitSubjects[2] | Should -Be 'Use LF'
			$commitSubjects[3] | Should -Be 'Add gitattributes'
			$ignoreRevsFilePath = Join-Path $testDirectory '.git-blame-ignore-revs'
			(Test-Path -LiteralPath $ignoreRevsFilePath) | Should -Be $true
			$renormalizeCommitId = Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1'
			((Get-Content -LiteralPath $ignoreRevsFilePath -Raw).TrimEnd("`r", "`n")) | Should -Be $renormalizeCommitId
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not invoke Copilot when .gitattributes already conforms' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a repository with already-compliant attributes.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			$expectedContent = "* text=auto eol=lf`n*.ps1 text eol=crlf`n*.png binary`n"
			Write-Utf8NoBomFile -Path $gitattributesPath -Content $expectedContent

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add compliant gitattributes' | Out-Null
			}
			finally {
				Pop-Location
			}

			$beforeHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention to the compliant repository.
			$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory

			# Assert no Copilot call or commit occurred.
			$global:CopilotCallCount | Should -Be 0
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should -Be $expectedContent
			$output[0].ToString() | Should -Be "'.gitattributes' already starts with '* text=auto eol=lf'."
			(Get-CommitId -TestDirectory $testDirectory) | Should -Be $beforeHead
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			# Arrange a repository with noncompliant attributes for the first run.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			Write-Utf8NoBomFile -Path $gitattributesPath -Content "* -text`n"

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add noncompliant gitattributes' | Out-Null

				function global:copilot {
					# Simulate Copilot rewriting attributes to the compliant shape.
					$global:CopilotCallCount++
					Write-Utf8NoBomFile -Path $gitattributesPath -Content "* text=auto eol=lf`n"
				}

				# Apply the convention twice in the same repository.
				InvokeGitattributesLfConvention -TestDirectory $testDirectory | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
				InvokeGitattributesLfConvention -TestDirectory $testDirectory | Out-Null
				$headAfterSecondRun = & git rev-parse HEAD
				$status = @(& git status --short)
			}
			finally {
				Pop-Location
			}

			# Assert only the first run changed the repository.
			$global:CopilotCallCount | Should -Be 1
			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
		}
		finally {
			Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

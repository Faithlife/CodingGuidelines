#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

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

	It 'creates .gitattributes when it is missing' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange an empty initialized repository.
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			# Apply the convention and collect commit and status state.
			$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory
			$commitSubjects = @(Get-CommitSubjects -TestDirectory $testDirectory -Count 2)
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert LF attributes were created, committed, and left the repository clean.
			(Test-Path -LiteralPath (Join-Path $testDirectory '.gitattributes')) | Should -Be $true
			((Get-Content -LiteralPath (Join-Path $testDirectory '.gitattributes') -Raw).TrimEnd("`r", "`n")) | Should -Be '* text=auto eol=lf'
			$output[0].ToString() | Should -Be "Creating '.gitattributes' with LF normalization enabled."
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should -Be $initialHead
			$commitSubjects[0] | Should -Be 'Use LF'
			$status.Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'repairs eol attributes in an existing file' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with noncompliant attributes and CRLF content.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			$scriptPath = Join-Path $testDirectory 'script.ps1'
			$notesPath = Join-Path $testDirectory 'notes.txt'
			[System.IO.File]::WriteAllText($gitattributesPath, "# keep this comment`n* -text`n*.ps1 text eol=crlf`n*.cmd eol=crlf`n*.png binary`n", $utf8)
			[System.IO.File]::WriteAllText($scriptPath, "Write-Host 'test'`r`n", [System.Text.UTF8Encoding]::new($false))
			[System.IO.File]::WriteAllText($notesPath, "line one`r`nline two`r`n", [System.Text.UTF8Encoding]::new($false))

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add gitattributes' | Out-Null

				# Apply the convention to repair the attributes file deterministically.
				$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory
			}
			finally {
				Pop-Location
			}

			# Assert the deterministic repair stripped only line-ending policy and kept useful rules.
			$gitattributesContent = Get-Content -LiteralPath $gitattributesPath -Raw
			$gitattributesContent | Should -Match "^\* text=auto eol=lf\n"
			$gitattributesContent | Should -Match "# keep this comment"
			$gitattributesContent | Should -Match "\.ps1 text"
			$gitattributesContent | Should -Not -Match "\.cmd"
			$gitattributesContent | Should -Match "\.png binary"
			$gitattributesContent | Should -Not -Match "eol=crlf"
			(@($output | ForEach-Object { $_.ToString() }) -contains ".gitattributes is not compliant; updating '.gitattributes'.") | Should -Be $true
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
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not change .gitattributes when it already conforms' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with already-compliant attributes.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			$expectedContent = "* text=auto eol=lf`n*.ps1 text`n*.png binary`n"
			[System.IO.File]::WriteAllText($gitattributesPath, $expectedContent, $utf8)

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

			# Assert no commit occurred.
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should -Be $expectedContent
			$output[0].ToString() | Should -Be "'.gitattributes' already starts with '* text=auto eol=lf'."
			(Get-CommitId -TestDirectory $testDirectory) | Should -Be $beforeHead
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'removes duplicate required and obsolete repository-wide rules' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with duplicate and obsolete repository-wide newline rules.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			[System.IO.File]::WriteAllText($gitattributesPath, "* text=auto`n* text=auto eol=lf`n*.png binary`n", $utf8)

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add duplicate attributes' | Out-Null
			}
			finally {
				Pop-Location
			}

			# Apply the convention to collapse the repository-wide rules.
			InvokeGitattributesLfConvention -TestDirectory $testDirectory | Out-Null

			# Assert only the required rule and useful custom rules remain.
			$gitattributesContent = Get-Content -LiteralPath $gitattributesPath -Raw
			$gitattributesContent | Should -Be "* text=auto eol=lf`n*.png binary`n"
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TemporaryDirectory

		try {
			# Arrange a repository with noncompliant attributes for the first run.
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			[System.IO.File]::WriteAllText($gitattributesPath, "* -text`n", $utf8)

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add noncompliant gitattributes' | Out-Null

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
			$headAfterSecondRun | Should -Be $headAfterFirstRun
			$status.Count | Should -Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

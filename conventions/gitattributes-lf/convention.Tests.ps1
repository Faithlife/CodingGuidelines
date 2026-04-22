Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeGitattributesLfConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	$inputPath = New-ConventionInputFile -Settings @{}

	try {
		return Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
	}
	finally {
		Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
	}
}

function InvokeGitattributesLfConventionWithoutInput {
	param(
		[Parameter(Mandatory = $true)]
		[string] $TestDirectory
	)

	return Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $TestDirectory
}

Describe 'gitattributes-lf convention' {
	BeforeEach {
		$global:CopilotCallCount = 0

		function global:copilot {
			$global:CopilotCallCount++
		}
	}

	AfterEach {
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
	}

	It 'creates .gitattributes when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$initialHead = Get-CommitId -TestDirectory $testDirectory

			$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory
			$commitSubjects = @(Get-CommitSubjects -TestDirectory $testDirectory -Count 2)
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			(Test-Path -LiteralPath (Join-Path $testDirectory '.gitattributes')) | Should Be $true
			((Get-Content -LiteralPath (Join-Path $testDirectory '.gitattributes') -Raw).TrimEnd("`r", "`n")) | Should Be '* text=auto eol=lf'
			$global:CopilotCallCount | Should Be 0
			$output[0].ToString() | Should Match "Creating '.+\\.gitattributes' with LF normalization enabled\."
			(Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1') | Should Be $initialHead
			$commitSubjects[0] | Should Be 'Use LF.'
			$status.Count | Should Be 0
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'uses Copilot and removes redundant eol rules from an existing file' {
		$testDirectory = New-TestDirectory

		try {
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
				& git commit -m 'Add gitattributes.' | Out-Null

				function global:copilot {
					$global:CopilotCallCount++
					Write-Utf8NoBomFile -Path $gitattributesPath -Content "* text=auto eol=lf`n*.png binary`n"
				}

				$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory
			}
			finally {
				Pop-Location
			}

			$global:CopilotCallCount | Should Be 1
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should Match "^\* text=auto eol=lf\n"
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should Match "\.png binary"
			(@($output | ForEach-Object { $_.ToString() }) -contains ".gitattributes is not compliant; starting Copilot to update '$gitattributesPath'.") | Should Be $true
			$commitSubjects = @(Get-CommitSubjects -TestDirectory $testDirectory -Count 4)
			$commitSubjects[0] | Should Be 'Ignore CRLF to LF for git blame.'
			$commitSubjects[1] | Should Be 'Convert CRLF to LF.'
			$commitSubjects[2] | Should Be 'Use LF.'
			$commitSubjects[3] | Should Be 'Add gitattributes.'
			$ignoreRevsFilePath = Join-Path $testDirectory '.git-blame-ignore-revs'
			(Test-Path -LiteralPath $ignoreRevsFilePath) | Should Be $true
			$renormalizeCommitId = Get-CommitId -TestDirectory $testDirectory -Revision 'HEAD~1'
			((Get-Content -LiteralPath $ignoreRevsFilePath -Raw).TrimEnd("`r", "`n")) | Should Be $renormalizeCommitId
			(@(Get-GitStatusLines -TestDirectory $testDirectory)).Count | Should Be 0
		}
		finally {
			Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not invoke Copilot when .gitattributes already conforms' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			$expectedContent = "* text=auto eol=lf`n*.ps1 text eol=crlf`n*.png binary`n"
			Write-Utf8NoBomFile -Path $gitattributesPath -Content $expectedContent

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add compliant gitattributes.' | Out-Null
			}
			finally {
				Pop-Location
			}

			$beforeHead = Get-CommitId -TestDirectory $testDirectory

			$output = InvokeGitattributesLfConvention -TestDirectory $testDirectory

			$global:CopilotCallCount | Should Be 0
			(Get-Content -LiteralPath $gitattributesPath -Raw) | Should Be $expectedContent
			$output[0].ToString() | Should Match "'.+\\.gitattributes' already starts with '\* text=auto eol=lf'\."
			(Get-CommitId -TestDirectory $testDirectory) | Should Be $beforeHead
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'is idempotent after the first successful application' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$gitattributesPath = Join-Path $testDirectory '.gitattributes'
			Write-Utf8NoBomFile -Path $gitattributesPath -Content "* -text`n"

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add noncompliant gitattributes.' | Out-Null

				function global:copilot {
					$global:CopilotCallCount++
					Write-Utf8NoBomFile -Path $gitattributesPath -Content "* text=auto eol=lf`n"
				}

				InvokeGitattributesLfConvention -TestDirectory $testDirectory | Out-Null
				$headAfterFirstRun = & git rev-parse HEAD
				InvokeGitattributesLfConvention -TestDirectory $testDirectory | Out-Null
				$headAfterSecondRun = & git rev-parse HEAD
				$status = @(& git status --short)
			}
			finally {
				Pop-Location
			}

			$global:CopilotCallCount | Should Be 1
			$headAfterSecondRun | Should Be $headAfterFirstRun
			$status.Count | Should Be 0
		}
		finally {
			Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

}

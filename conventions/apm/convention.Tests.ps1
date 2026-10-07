#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

# Define the Pester suite for the apm convention.
Describe 'apm convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Create a fake apm executable for the current platform.
		function script:NewFakeApmCommand {
			param(
				[Parameter(Mandatory = $true)]
				[string] $ToolDirectory,

				[Parameter(Mandatory = $true)]
				[string] $WindowsScript,

				[Parameter(Mandatory = $true)]
				[string] $BashScript
			)

			if ($IsWindows) {
				$commandPath = Join-Path $ToolDirectory 'apm.cmd'
				Set-Content -LiteralPath $commandPath -Value $WindowsScript -Encoding ascii
			}
			else {
				$commandPath = Join-Path $ToolDirectory 'apm'
				Set-Content -LiteralPath $commandPath -Value $BashScript
				& chmod +x $commandPath
				if ($LASTEXITCODE -ne 0) {
					throw 'Failed to mark fake apm script as executable.'
				}
			}
		}
	}

	It 'exits successfully without invoking apm when there is no apm.yml and no configured packages' {
		# Set up an empty repository and a fake apm invocation marker.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$apmInvocationPath = Join-Path $toolDirectory 'apm-invoked.txt'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange the fake apm command on PATH without any convention inputs.
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
> "%APM_INVOCATION_PATH%" echo invoked
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf 'invoked\n' > "$APM_INVOCATION_PATH"
exit 0
'@
			$env:APM_INVOCATION_PATH = $apmInvocationPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and verify it leaves the repository untouched.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Test-Path -LiteralPath $apmInvocationPath | Should -Be $false
			(Get-GitStatusLines -TestDirectory $testDirectory) | Should -BeNullOrEmpty
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_INVOCATION_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'runs apm install by default' {
		# Set up a repository with apm.yml and a fake argument capture file.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that records its argument list.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$APM_ARGUMENTS_PATH"
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it invokes apm with the default arguments.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'adds a copilot target to apm.yml when targets are missing' {
		# Set up a repository with an apm.yml that does not declare targets yet.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that records its argument list.
			[System.IO.File]::WriteAllText($manifestPath, "packages: []`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$APM_ARGUMENTS_PATH"
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention twice and assert it adds the targets declaration only once.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be "packages: []`ntargets:`n- copilot`n"
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be "packages: []`ntargets:`n- copilot`n"
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'strips trailing blank lines before adding targets to apm.yml' {
		# Set up a repository with an apm.yml that ends with blank lines.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command and a manifest with trailing blank lines.
			[System.IO.File]::WriteAllText($manifestPath, "packages: []`n`n`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
exit 0
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert no blank line is left before targets.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be "packages: []`ntargets:`n- copilot`n"
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'runs apm update --yes after install when the update setting is true' {
		# Set up a repository with apm.yml and an explicit update request.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{
			update = $true
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that records its argument list.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APM_ARGUMENTS_PATH"
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert the update command is used after install.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Get-Content -LiteralPath $argumentsPath | Should -Be @('install', 'update --yes')
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'passes configured install packages to apm install' {
		# Set up convention input that includes configured apm packages.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @(
				'richlander/dotnet-inspect/skills/dotnet-inspect'
				'microsoft/playwright-cli/skills/playwright-cli'
			)
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that records package arguments.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$APM_ARGUMENTS_PATH"
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert configured packages are appended.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			((Get-Content -LiteralPath $argumentsPath -Raw).TrimEnd("`r", "`n")) | Should -Be 'install richlander/dotnet-inspect/skills/dotnet-inspect microsoft/playwright-cli/skills/playwright-cli'
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'initializes apm.yml before installing configured packages and updating' {
		# Set up convention input that needs a new APM manifest before install and update.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @(
				'richlander/dotnet-inspect/skills/dotnet-inspect'
			)
			update = $true
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake apm command that creates the generated manifest during init.
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%APM_ARGUMENTS_PATH%" echo %*
if "%1"=="init" (
  > "%CD%\apm.yml" echo name: Generated
  >> "%CD%\apm.yml" echo author: Generated Person
  >> "%CD%\apm.yml" echo dependencies: {}
)
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APM_ARGUMENTS_PATH"
if [ "$1" = "init" ]; then
cat > "$PWD/apm.yml" <<'EOF'
name: Generated
author: Generated Person
dependencies: {}
EOF
fi
exit 0
'@

			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it initializes, cleans, targets, installs, and updates in order.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Get-Content -LiteralPath $argumentsPath | Should -Be @('init --yes', 'install richlander/dotnet-inspect/skills/dotnet-inspect', 'update --yes')
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be "name: Generated`ndependencies: {}`ntargets:`n- copilot`n"
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'reverts apm.lock.yaml when it is the only changed file' {
		# Set up a repository where apm can only update the lock file.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH
		$originalLockContent = "packages:`n  sample: 1.0.0`n"

		try {
			# Arrange committed apm files and a fake command that modifies the lock file.
			[System.IO.File]::WriteAllText($lockFilePath, $originalLockContent, $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory

			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%CD%\apm.lock.yaml" echo updated: true
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf 'updated: true\n' >> "$PWD/apm.lock.yaml"
exit 0
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert the lock-only change is reverted.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Be $originalLockContent
			(Get-GitStatusLines -TestDirectory $testDirectory) | Should -BeNullOrEmpty
		}
		finally {
			# Restore process state and remove temporary repositories.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'keeps apm.lock.yaml when apm also changes another file' {
		# Set up a repository where apm updates the lock file and package metadata.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$packageFilePath = Join-Path $testDirectory 'package.json'
		$inputPath = New-ConventionInputFile -Settings @{}
		$originalPath = $env:PATH

		try {
			# Arrange committed files and a fake command that modifies both files.
			[System.IO.File]::WriteAllText($lockFilePath, "packages:`n  sample: 1.0.0`n", $utf8)
			[System.IO.File]::WriteAllText($packageFilePath, "{}`n", $utf8)
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "packages: []`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory

			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%CD%\apm.lock.yaml" echo updated: true
>> "%CD%\package.json" echo // updated
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf 'updated: true\n' >> "$PWD/apm.lock.yaml"
printf '// updated\n' >> "$PWD/package.json"
exit 0
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert it preserves meaningful apm changes.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Match 'updated: true'
			Get-GitStatusLines -TestDirectory $testDirectory | Should -Be @(' M apm.lock.yaml', ' M package.json')
		}
		finally {
			# Restore process state and remove temporary repositories.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'installs configured packages in development scope and migrates only matching APM references' {
		# Set up a manifest with production and development dependencies from several kinds.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @(
				'Faithlife/CodingGuidelines/conventions/apm'
				'LogosBible/already-in-development'
				'LogosBible/new-authoring-tool'
			)
			dev = $true
		}
		$originalPath = $env:PATH
		$originalManifest = @'
name: fixture
dependencies:
  apm:
  - Faithlife/CodingGuidelines/conventions/apm
  - LogosBible/already-in-development
  - LogosBible/consumer-runtime
  npm:
  - production-npm
devDependencies:
  apm:
  - existing-authoring-tool
  - LogosBible/already-in-development
  npm:
  - development-npm
targets:
- copilot
'@

		try {
			# Arrange a fake APM command that captures the install arguments.
			[System.IO.File]::WriteAllText($manifestPath, $originalManifest + "`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
>> "%APM_ARGUMENTS_PATH%" echo %*
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APM_ARGUMENTS_PATH"
exit 0
'@
			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention twice and verify that only the configured APM reference moves.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			$expectedManifest = @'
name: fixture
dependencies:
  apm:
  - LogosBible/consumer-runtime
  npm:
  - production-npm
devDependencies:
  apm:
  - existing-authoring-tool
  - LogosBible/already-in-development
  - Faithlife/CodingGuidelines/conventions/apm
  npm:
  - development-npm
targets:
- copilot
'@
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be ($expectedManifest + "`n")
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be ($expectedManifest + "`n")
			Get-Content -LiteralPath $argumentsPath | Should -Be @(
				'install --dev Faithlife/CodingGuidelines/conventions/apm LogosBible/already-in-development LogosBible/new-authoring-tool'
				'install --dev Faithlife/CodingGuidelines/conventions/apm LogosBible/already-in-development LogosBible/new-authoring-tool'
			)
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'updates existing development dependencies before a configured development install' {
		# Set up a migrated package whose upstream manifest may need refreshing before resolution.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$firstManifestPath = Join-Path $toolDirectory 'first-apm-manifest.yml'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @('LogosBible/bible-study-react-ui/skills/all')
			dev = $true
			update = $true
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake APM command that records the manifest seen by the first command.
			[System.IO.File]::WriteAllText($manifestPath, "name: fixture`ndependencies:`n  apm:`n  - LogosBible/bible-study-react-ui/skills/all`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%APM_ARGUMENTS_PATH%" echo %*
if not exist "%APM_FIRST_MANIFEST_PATH%" copy /Y "%CD%\apm.yml" "%APM_FIRST_MANIFEST_PATH%" >nul
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APM_ARGUMENTS_PATH"
if [ ! -e "$APM_FIRST_MANIFEST_PATH" ]; then
  cp "$PWD/apm.yml" "$APM_FIRST_MANIFEST_PATH"
fi
exit 0
'@
			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:APM_FIRST_MANIFEST_PATH = $firstManifestPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and assert update sees the migrated manifest before install.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Get-Content -LiteralPath $argumentsPath | Should -Be @('update --yes', 'install --dev LogosBible/bible-study-react-ui/skills/all')
			(Get-Content -LiteralPath $firstManifestPath -Raw) | Should -Be "name: fixture`ndependencies:`n  apm: []`ndevDependencies:`n  apm:`n  - LogosBible/bible-study-react-ui/skills/all`ntargets:`n- copilot`n"
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item Env:APM_FIRST_MANIFEST_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'keeps an intentional development refresh when only the APM lockfile changes' {
		# Set up a development dependency whose update changes only the lockfile.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$lockFilePath = Join-Path $testDirectory 'apm.lock.yaml'
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @('Faithlife/CodingGuidelines/conventions/apm')
			dev = $true
			update = $true
		}
		$originalPath = $env:PATH

		try {
			# Arrange a manifest that already has the package in development scope.
			[System.IO.File]::WriteAllText((Join-Path $testDirectory 'apm.yml'), "name: fixture`ndevDependencies:`n  apm:`n  - Faithlife/CodingGuidelines/conventions/apm`ntargets:`n- copilot`n", $utf8)
			[System.IO.File]::WriteAllText($lockFilePath, "packages:`n  fixture: 1.0.0`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
setlocal
>> "%APM_ARGUMENTS_PATH%" echo %*
if "%1"=="update" >> "%CD%\apm.lock.yaml" echo refreshed: true
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APM_ARGUMENTS_PATH"
if [ "$1" = "update" ]; then
  printf 'refreshed: true\n' >> "$PWD/apm.lock.yaml"
fi
exit 0
'@
			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Run the convention and retain the lock update needed by this development install.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Not -Throw
			Get-Content -LiteralPath $argumentsPath | Should -Be @('update --yes', 'install --dev Faithlife/CodingGuidelines/conventions/apm')
			(Get-Content -LiteralPath $lockFilePath -Raw) | Should -Be "packages:`n  fixture: 1.0.0`nrefreshed: true`n"
			Get-GitStatusLines -TestDirectory $testDirectory | Should -Be @(' M apm.lock.yaml')
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does not rewrite unsupported inline dependency mappings' {
		# Arrange a non-empty inline dependency mapping that cannot be migrated safely.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @('Faithlife/CodingGuidelines/conventions/apm')
			dev = $true
		}
		$originalPath = $env:PATH
		$originalManifest = "name: fixture`ndependencies: { apm: [Faithlife/CodingGuidelines/conventions/apm] }`ntargets:`n- copilot`n"

		try {
			# Arrange a fake APM command and preserve a clean manifest snapshot.
			[System.IO.File]::WriteAllText($manifestPath, $originalManifest, $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
exit 0
'@
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Assert the unsupported mapping fails before either the manifest or APM changes.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Throw "*Cannot safely migrate APM packages from the inline 'dependencies' value.*"
			(Get-Content -LiteralPath $manifestPath -Raw) | Should -Be $originalManifest
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'stops before install when a development refresh fails' {
		# Set up a development install whose required pre-install update will fail.
		$testDirectory = New-TemporaryDirectory
		$toolDirectory = New-TemporaryDirectory
		$argumentsPath = Join-Path $toolDirectory 'apm-arguments.txt'
		$manifestPath = Join-Path $testDirectory 'apm.yml'
		$inputPath = New-ConventionInputFile -Settings @{
			install = @('Faithlife/CodingGuidelines/conventions/apm')
			dev = $true
			update = $true
		}
		$originalPath = $env:PATH

		try {
			# Arrange a fake APM command that fails only for update.
			[System.IO.File]::WriteAllText($manifestPath, "name: fixture`ndependencies:`n  apm:`n  - Faithlife/CodingGuidelines/conventions/apm`ntargets:`n- copilot`n", $utf8)
			Initialize-TestRepository -Path $testDirectory
			NewFakeApmCommand -ToolDirectory $toolDirectory -WindowsScript @'
@echo off
>> "%APM_ARGUMENTS_PATH%" echo %*
if "%1"=="update" exit /b 7
exit /b 0
'@ -BashScript @'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APM_ARGUMENTS_PATH"
if [ "$1" = "update" ]; then
  exit 7
fi
exit 0
'@
			$env:APM_ARGUMENTS_PATH = $argumentsPath
			$env:PATH = $toolDirectory + [System.IO.Path]::PathSeparator + $originalPath

			# Assert the refresh error is surfaced and the convention never invokes install.
			{ Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath } | Should -Throw 'apm update failed.'
			Get-Content -LiteralPath $argumentsPath | Should -Be @('update --yes')
		}
		finally {
			# Restore process state and remove temporary files.
			$env:PATH = $originalPath
			Remove-Item Env:APM_ARGUMENTS_PATH -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath $inputPath -Force
			Remove-Item -LiteralPath $toolDirectory -Recurse -Force
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

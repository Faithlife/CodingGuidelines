#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Define the Pester suite for the copilot-lsp convention.
Describe 'copilot-lsp convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention with temporary JSON input for each scenario.
		function script:InvokeCopilotLspConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $TestDirectory,

				[Parameter(Mandatory = $true)]
				[hashtable] $Settings
			)

			$inputPath = New-ConventionInputFile -Settings $Settings

			try {
				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $TestDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
			}
		}

		# Read the LSP config as a hashtable for stable assertions.
		function script:ReadLspConfig {
			param(
				[Parameter(Mandatory = $true)]
				[string] $Path
			)

			return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
		}

		# Flatten convention output for regex assertions.
		function script:GetOutputText {
			param(
				[Parameter(Mandatory = $true)]
				[object[]] $Output
			)

			return (@($Output | ForEach-Object { $_.ToString() }) -join "`n")
		}
	}

	It 'creates .github/lsp.json when it is missing' {
		# Set up an empty repository with no existing LSP config.
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			# Run the convention with a configured Python server.
			$output = InvokeCopilotLspConvention -TestDirectory $testDirectory -Settings @{ servers = [ordered]@{ python = [ordered]@{ command = 'pyright-langserver'; args = @('--stdio'); fileExtensions = [ordered]@{ '.py' = 'python'; '.pyi' = 'python' } } } }
			$lspConfigPath = Join-Path $testDirectory '.github' 'lsp.json'
			$config = ReadLspConfig -Path $lspConfigPath
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the new config contains the requested server and output.
			(Test-Path -LiteralPath $lspConfigPath) | Should -Be $true
			$config.lspServers.python.command | Should -Be 'pyright-langserver'
			$config.lspServers.python.args | Should -Be @('--stdio')
			$config.lspServers.python.fileExtensions.'.py' | Should -Be 'python'
			$config.lspServers.python.fileExtensions.'.pyi' | Should -Be 'python'
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^\?\? \.github/$'
			(GetOutputText -Output $output) | Should -Match "Created '\.github/lsp\.json' with the configured Copilot LSP servers\."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'adds and replaces named servers without merging them or affecting other servers' {
		# Set up a repository with existing LSP servers and unrelated settings.
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$lspConfigPath = Join-Path $testDirectory '.github' 'lsp.json'
			[System.IO.Directory]::CreateDirectory((Split-Path -Parent $lspConfigPath)) | Out-Null
			Write-Utf8NoBomFile -Path $lspConfigPath -Content @'
{
  "lspServers": {
    "python": {
      "command": "old-python-lsp",
      "args": [],
      "fileExtensions": {
        ".py": "python"
      },
      "env": {
        "PYTHONPATH": "src"
      }
    },
    "ruby": {
      "command": "ruby-lsp",
      "args": [],
      "fileExtensions": {
        ".rb": "ruby"
      }
    }
  },
  "otherSetting": true
}
'@

			# Commit the existing config so later status checks show only convention changes.
			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add existing LSP config' | Out-Null
			}
			finally {
				Pop-Location
			}

			# Run the convention with replacement and added servers.
			$output = InvokeCopilotLspConvention -TestDirectory $testDirectory -Settings @{ servers = [ordered]@{
				python = [ordered]@{
					command = 'pyright-langserver'
					args = @('--stdio')
					fileExtensions = [ordered]@{
						'.py' = 'python'
						'.pyw' = 'python'
					}
				}
				typescript = [ordered]@{
					command = 'typescript-language-server'
					args = @('--stdio')
					fileExtensions = [ordered]@{
						'.ts' = 'typescript'
						'.tsx' = 'typescriptreact'
					}
				}
			} }
			$config = ReadLspConfig -Path $lspConfigPath
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert named servers are replaced wholesale and others are preserved.
			$config.lspServers.python.command | Should -Be 'pyright-langserver'
			$config.lspServers.python.args | Should -Be @('--stdio')
			$config.lspServers.python.fileExtensions.'.pyw' | Should -Be 'python'
			$config.lspServers.python.ContainsKey('env') | Should -Be $false
			$config.lspServers.ruby.command | Should -Be 'ruby-lsp'
			$config.lspServers.typescript.command | Should -Be 'typescript-language-server'
			$config.otherSetting | Should -Be $true
			$status.Count | Should -Be 1
			$status[0] | Should -Match '^ M \.github/lsp\.json$'
			(GetOutputText -Output $output) | Should -Match "Updated '\.github/lsp\.json' with the configured Copilot LSP servers\."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does nothing when the configured servers already match exactly' {
		# Set up a repository whose LSP config already matches the settings.
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory
			$lspConfigPath = Join-Path $testDirectory '.github' 'lsp.json'
			[System.IO.Directory]::CreateDirectory((Split-Path -Parent $lspConfigPath)) | Out-Null
			Write-Utf8NoBomFile -Path $lspConfigPath -Content @'
{
  "lspServers": {
    "python": {
      "command": "pyright-langserver",
      "args": [
        "--stdio"
      ],
      "fileExtensions": {
        ".py": "python",
        ".pyw": "python"
      }
    },
    "typescript": {
      "command": "typescript-language-server",
      "args": [
        "--stdio"
      ],
      "fileExtensions": {
        ".ts": "typescript",
        ".tsx": "typescriptreact"
      }
    },
    "ruby": {
      "command": "ruby-lsp",
      "args": [],
      "fileExtensions": {
        ".rb": "ruby"
      }
    }
  }
}
'@

			# Commit the matching config so status checks can verify idempotency.
			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add matching LSP config' | Out-Null
			}
			finally {
				Pop-Location
			}

			# Run the convention with the same configured servers.
			$output = InvokeCopilotLspConvention -TestDirectory $testDirectory -Settings @{ servers = [ordered]@{
				python = [ordered]@{
					command = 'pyright-langserver'
					args = @('--stdio')
					fileExtensions = [ordered]@{
						'.py' = 'python'
						'.pyw' = 'python'
					}
				}
				typescript = [ordered]@{
					command = 'typescript-language-server'
					args = @('--stdio')
					fileExtensions = [ordered]@{
						'.ts' = 'typescript'
						'.tsx' = 'typescriptreact'
					}
				}
			} }
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

			# Assert the convention reports compliance and leaves git clean.
			$status.Count | Should -Be 0
			(GetOutputText -Output $output) | Should -Match "'\.github/lsp\.json' already contains the configured Copilot LSP servers\."
		}
		finally {
			# Remove the isolated repository after the test completes.
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}

#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'copilot-lsp convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

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

		function script:ReadLspConfig {
			param(
				[Parameter(Mandatory = $true)]
				[string] $Path
			)

			return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
		}

		function script:GetOutputText {
			param(
				[Parameter(Mandatory = $true)]
				[object[]] $Output
			)

			return (@($Output | ForEach-Object { $_.ToString() }) -join "`n")
		}
	}

	It 'creates .github/lsp.json when it is missing' {
		$testDirectory = New-TestDirectory

		try {
			Initialize-TestRepository -Path $testDirectory

			$output = InvokeCopilotLspConvention -TestDirectory $testDirectory -Settings @{ servers = [ordered]@{ python = [ordered]@{ command = 'pyright-langserver'; args = @('--stdio'); fileExtensions = [ordered]@{ '.py' = 'python'; '.pyi' = 'python' } } } }
			$lspConfigPath = Join-Path $testDirectory '.github' 'lsp.json'
			$config = ReadLspConfig -Path $lspConfigPath
			$status = @(Get-GitStatusLines -TestDirectory $testDirectory)

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
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'adds and replaces named servers without merging them or affecting other servers' {
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

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add existing LSP config' | Out-Null
			}
			finally {
				Pop-Location
			}

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
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}

	It 'does nothing when the configured servers already match exactly' {
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

			Push-Location $testDirectory
			try {
				& git add -A
				& git commit -m 'Add matching LSP config' | Out-Null
			}
			finally {
				Pop-Location
			}

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

			$status.Count | Should -Be 0
			(GetOutputText -Output $output) | Should -Match "'\.github/lsp\.json' already contains the configured Copilot LSP servers\."
		}
		finally {
			Remove-Item -LiteralPath $testDirectory -Recurse -Force
		}
	}
}
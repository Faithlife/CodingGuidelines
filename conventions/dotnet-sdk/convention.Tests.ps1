#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'dotnet-sdk convention' {
	BeforeAll {
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
		. $script:testHelpersPath

		function script:InvokeDotnetSdkConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $InputJson,

				[object] $SdkVersion = '10.0.100'
			)

			$testDirectory = New-TestDirectory
			$inputPath = $null

			try {
				$inputPath = New-ConventionInputFile -InputJson $InputJson

				if ($null -ne $SdkVersion) {
					$globalJsonPath = Join-Path $testDirectory 'global.json'
					$globalJson = @{
						sdk = @{
							version = $SdkVersion
							rollForward = 'latestFeature'
						}
					} | ConvertTo-Json -Depth 3
					Write-Utf8NoBomFile -Path $globalJsonPath -Content $globalJson
				}

				return Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath
			}
			finally {
				Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
				Remove-Item -LiteralPath $testDirectory -Recurse -Force
			}
		}

		function script:GetOutputText {
			param(
				[object[]] $Output
			)

			return (@($Output | ForEach-Object { $_.ToString() }) -join "`n")
		}
	}

	AfterEach {
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
	}

	It 'accepts an integer major version when global.json already conforms' {
		$inputJson = '{"settings":{"version":10}}'

		$output = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '10.0.100'

		$outputText = GetOutputText -Output $output
		$outputText | Should -Match 'Starting dotnet-sdk convention\.'
		$outputText | Should -Match 'Checking global\.json for \.NET SDK major version 10\.'
		$outputText | Should -Match 'global\.json already requires SDK major version 10, which satisfies required major version 10\.'
		$outputText | Should -Match 'dotnet-sdk convention has nothing to do\.'
	}

	It 'accepts a string major version when global.json already conforms' {
		$inputJson = '{"settings":{"version":"10"}}'

		$output = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '11.0.100'

		GetOutputText -Output $output | Should -Match 'global\.json already requires SDK major version 11, which satisfies required major version 10\.'
	}

	It 'logs why it starts Copilot when global.json is missing' {
		$inputJson = '{"settings":{"version":10}}'

		function global:copilot {
			Write-Utf8NoBomFile -Path (Join-Path (Get-Location) 'global.json') -Content @'
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "latestFeature"
  }
}
'@
		}

		$output = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion $null

		$outputText = GetOutputText -Output $output
		$outputText | Should -Match 'global\.json is missing\.'
		$outputText | Should -Match 'global\.json does not conform; starting Copilot to update it\.'
		$outputText | Should -Match 'global\.json already requires SDK major version 10, which satisfies required major version 10\.'
	}

	It 'rejects a missing version setting' {
		$inputJson = '{"settings":{}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should -Throw "The 'version' setting is required."
	}

	It 'rejects a non-integer version string' {
		$inputJson = '{"settings":{"version":"10.0"}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should -Throw "The 'version' setting must be an integer or a string that parses to an integer."
	}

	It 'rejects a non-positive integer version' {
		$inputJson = '{"settings":{"version":0}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should -Throw "The 'version' setting must be a positive integer."
	}

}

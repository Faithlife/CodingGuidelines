#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Define the Pester suite for the dotnet-sdk convention.
Describe 'dotnet-sdk convention' {
	BeforeAll {
		# Load the convention script and shared test helpers.
		$script:conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
		$script:testHelpersPath = Join-Path $PSScriptRoot '..' 'scripts' 'TestHelpers.ps1'
		. $script:testHelpersPath

		# Invoke the convention against a temporary repository and input file.
		function script:InvokeDotnetSdkConvention {
			param(
				[Parameter(Mandatory = $true)]
				[string] $InputJson,

				[object] $SdkVersion = '10.0.100'
			)

			$testDirectory = New-TemporaryDirectory
			$inputPath = $null

			try {
				$inputPath = New-ConventionInputFile -InputJson $InputJson

				# Seed global.json when the scenario starts from an existing SDK version.
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

		# Flatten convention output for regex assertions.
		function script:GetOutputText {
			param(
				[object[]] $Output
			)

			return (@($Output | ForEach-Object { $_.ToString() }) -join "`n")
		}
	}

	AfterEach {
		# Clear the global Copilot stub between tests.
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
	}

	It 'accepts an integer major version when global.json already conforms' {
		# Arrange an integer required SDK major version.
		$inputJson = '{"settings":{"version":10}}'

		# Run the convention against a matching global.json.
		$output = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '10.0.100'

		# Assert the output reports compliance and no work.
		$outputText = GetOutputText -Output $output
		$outputText | Should -Match 'Checking global\.json for \.NET SDK major version 10\.'
		$outputText | Should -Match 'global\.json already requires SDK major version 10, which satisfies required major version 10\.'
		$outputText | Should -Match 'dotnet-sdk convention has nothing to do\.'
	}

	It 'accepts a string major version when global.json already conforms' {
		# Arrange a string required SDK major version.
		$inputJson = '{"settings":{"version":"10"}}'

		# Run the convention against a newer matching global.json.
		$output = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '11.0.100'

		# Assert the newer SDK still satisfies the required major version.
		GetOutputText -Output $output | Should -Match 'global\.json already requires SDK major version 11, which satisfies required major version 10\.'
	}

	It 'logs why it starts Copilot when global.json is missing' {
		# Arrange a required SDK version with no starting global.json.
		$inputJson = '{"settings":{"version":10}}'

		# Stub Copilot to create a conforming global.json.
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

		# Run the convention and capture its output.
		$output = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion $null

		# Assert the output explains both the missing file and the Copilot handoff.
		$outputText = GetOutputText -Output $output
		$outputText | Should -Match 'global\.json is missing\.'
		$outputText | Should -Match 'global\.json does not conform; starting Copilot to update it\.'
		$outputText | Should -Match 'global\.json already requires SDK major version 10, which satisfies required major version 10\.'
	}

	It 'rejects a missing version setting' {
		# Arrange input without the required version setting.
		$inputJson = '{"settings":{}}'

		# Assert the convention rejects the missing setting.
		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should -Throw "The 'version' setting is required."
	}

	It 'rejects a non-integer version string' {
		# Arrange a version string that is not a major version integer.
		$inputJson = '{"settings":{"version":"10.0"}}'

		# Assert the convention rejects non-integer version values.
		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should -Throw "The 'version' setting must be an integer or a string that parses to an integer."
	}

	It 'rejects a non-positive integer version' {
		# Arrange a non-positive required SDK major version.
		$inputJson = '{"settings":{"version":0}}'

		# Assert the convention rejects non-positive version values.
		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should -Throw "The 'version' setting must be a positive integer."
	}

}

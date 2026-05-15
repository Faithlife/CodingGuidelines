#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

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

				[object] $SdkVersion = '10.0.100',

				[string] $GlobalJsonContent
			)

			$testDirectory = New-TemporaryDirectory
			$inputPath = $null

			try {
				$inputPath = New-ConventionInputFile -InputJson $InputJson

				$globalJsonPath = Join-Path $testDirectory 'global.json'

				# Seed global.json from explicit test content when the scenario needs a custom shape.
				if ($PSBoundParameters.ContainsKey('GlobalJsonContent')) {
					[System.IO.File]::WriteAllText($globalJsonPath, $GlobalJsonContent, $utf8)
				}
				elseif ($null -ne $SdkVersion) {
					$globalJson = @{
						sdk = @{
							version = $SdkVersion
							rollForward = 'latestFeature'
						}
					} | ConvertTo-Json -Depth 3
					[System.IO.File]::WriteAllText($globalJsonPath, $globalJson, $utf8)
				}

				# Return both convention output and resulting global.json content before cleanup.
				$output = Invoke-ConventionScript -ScriptPath $script:conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath
				$resultingGlobalJson = if (Test-Path -LiteralPath $globalJsonPath -PathType Leaf) {
					Get-Content -LiteralPath $globalJsonPath -Raw
				}
				else {
					$null
				}

				return [pscustomobject]@{
					Output = $output
					GlobalJsonContent = $resultingGlobalJson
				}
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

	It 'accepts an integer major version when global.json already conforms' {
		# Arrange an integer required SDK major version.
		$inputJson = '{"settings":{"version":10}}'

		# Run the convention against a matching global.json.
		$result = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '10.0.100'

		# Assert the output reports compliance and no work.
		$outputText = GetOutputText -Output $result.Output
		$outputText | Should -Match 'Checking global\.json for \.NET SDK major version 10\.'
		$outputText | Should -Match 'global\.json already requires SDK major version 10, which satisfies required major version 10\.'
		$outputText | Should -Match 'dotnet-sdk convention has nothing to do\.'
	}

	It 'accepts a string major version when global.json already conforms' {
		# Arrange a string required SDK major version.
		$inputJson = '{"settings":{"version":"10"}}'

		# Run the convention against a newer matching global.json.
		$result = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '11.0.100'

		# Assert the newer SDK still satisfies the required major version.
		GetOutputText -Output $result.Output | Should -Match 'global\.json already requires SDK major version 11, which satisfies required major version 10\.'
	}

	It 'creates global.json when it is missing' {
		# Arrange a required SDK version with no starting global.json.
		$inputJson = '{"settings":{"version":10}}'

		# Run the convention and capture its output.
		$result = InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion $null

		# Assert the output explains both the missing file and the deterministic update.
		$outputText = GetOutputText -Output $result.Output
		$outputText | Should -Match 'global\.json is missing\.'
		$outputText | Should -Match 'global\.json does not conform; updating it\.'
		$outputText | Should -Match 'global\.json already requires SDK major version 10, which satisfies required major version 10\.'

		# Assert the generated JSON has the required two-space-indented SDK settings.
		$json = $result.GlobalJsonContent | ConvertFrom-Json -AsHashtable
		$json.sdk.version | Should -Be '10.0.100'
		$json.sdk.rollForward | Should -Be 'latestFeature'
		($result.GlobalJsonContent -split "`n")[1].TrimEnd("`r") | Should -Be '  "sdk": {'
	}

	It 'updates an older global.json while preserving unrelated properties' {
		# Arrange an older SDK file with unrelated top-level and SDK properties.
		$inputJson = '{"settings":{"version":10}}'
		$globalJsonContent = @'
{
  "name": "test-repository",
  "sdk": {
    "extra": true,
    "version": "8.0.100"
  }
}
'@

		# Run the convention against the older global.json.
		$result = InvokeDotnetSdkConvention -InputJson $inputJson -GlobalJsonContent $globalJsonContent

		# Assert the SDK settings changed without removing unrelated data.
		$json = $result.GlobalJsonContent | ConvertFrom-Json -AsHashtable
		$json.name | Should -Be 'test-repository'
		$json.sdk.extra | Should -Be $true
		$json.sdk.version | Should -Be '10.0.100'
		$json.sdk.rollForward | Should -Be 'latestFeature'
	}

	It 'replaces malformed global.json with required SDK settings' {
		# Arrange a malformed global.json that cannot be repaired structurally.
		$inputJson = '{"settings":{"version":10}}'

		# Run the convention against invalid JSON.
		$result = InvokeDotnetSdkConvention -InputJson $inputJson -GlobalJsonContent '{ invalid json'

		# Assert the convention writes a valid minimal SDK configuration.
		$json = $result.GlobalJsonContent | ConvertFrom-Json -AsHashtable
		$json.sdk.version | Should -Be '10.0.100'
		$json.sdk.rollForward | Should -Be 'latestFeature'
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

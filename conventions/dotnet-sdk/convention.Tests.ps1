#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'
$testHelpersPath = Join-Path $PSScriptRoot '..\scripts\TestHelpers.ps1'
. $testHelpersPath

function InvokeDotnetSdkConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $InputJson,

		[string] $SdkVersion = '10.0.100'
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

		Invoke-ConventionScript -ScriptPath $conventionScriptPath -RepositoryRoot $testDirectory -InputPath $inputPath | Out-Null
	}
	finally {
		Remove-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath $testDirectory -Recurse -Force
	}
}

Describe 'dotnet-sdk convention' {
	AfterEach {
		Remove-Item Function:\global:copilot -ErrorAction SilentlyContinue
	}

	It 'accepts an integer major version when global.json already conforms' {
		$inputJson = '{"settings":{"version":10}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '10.0.100' } | Should Not Throw
	}

	It 'accepts a string major version when global.json already conforms' {
		$inputJson = '{"settings":{"version":"10"}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson -SdkVersion '11.0.100' } | Should Not Throw
	}

	It 'rejects a missing version setting' {
		$inputJson = '{"settings":{}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should Throw "The 'version' setting is required."
	}

	It 'rejects a non-integer version string' {
		$inputJson = '{"settings":{"version":"10.0"}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should Throw "The 'version' setting must be an integer or a string that parses to an integer."
	}

	It 'rejects a non-positive integer version' {
		$inputJson = '{"settings":{"version":0}}'

		{ InvokeDotnetSdkConvention -InputJson $inputJson } | Should Throw "The 'version' setting must be a positive integer."
	}

}

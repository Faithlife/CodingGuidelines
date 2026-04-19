Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$conventionScriptPath = Join-Path $PSScriptRoot 'convention.ps1'

function New-TestDirectory {
	$path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
	[System.IO.Directory]::CreateDirectory($path) | Out-Null
	return $path
}

function Invoke-DotnetSdkConvention {
	param(
		[Parameter(Mandatory = $true)]
		[string] $InputJson,

		[string] $SdkVersion = '10.0.100'
	)

	$testDirectory = New-TestDirectory

	try {
		$inputPath = Join-Path $testDirectory 'input.json'
		Set-Content -LiteralPath $inputPath -Value $InputJson -Encoding utf8NoBOM

		if ($null -ne $SdkVersion) {
			$globalJsonPath = Join-Path $testDirectory 'global.json'
			$globalJson = @{
				sdk = @{
					version = $SdkVersion
					rollForward = 'latestFeature'
				}
			} | ConvertTo-Json -Depth 3
			Set-Content -LiteralPath $globalJsonPath -Value $globalJson -Encoding utf8NoBOM
		}

		Push-Location $testDirectory
		try {
			& $conventionScriptPath $inputPath
		}
		finally {
			Pop-Location
		}
	}
	finally {
		Remove-Item -LiteralPath $testDirectory -Recurse -Force
	}
}

Describe 'dotnet-sdk convention' {
	It 'accepts an integer major version when global.json already conforms' {
		$inputJson = '{"settings":{"version":10}}'

		{ Invoke-DotnetSdkConvention -InputJson $inputJson -SdkVersion '10.0.100' } | Should Not Throw
	}

	It 'accepts a string major version when global.json already conforms' {
		$inputJson = '{"settings":{"version":"10"}}'

		{ Invoke-DotnetSdkConvention -InputJson $inputJson -SdkVersion '11.0.100' } | Should Not Throw
	}

	It 'rejects a missing version setting' {
		$inputJson = '{"settings":{}}'

		{ Invoke-DotnetSdkConvention -InputJson $inputJson } | Should Throw "The 'version' setting is required."
	}

	It 'rejects a non-integer version string' {
		$inputJson = '{"settings":{"version":"10.0"}}'

		{ Invoke-DotnetSdkConvention -InputJson $inputJson } | Should Throw "The 'version' setting must be an integer or a string that parses to an integer."
	}

	It 'rejects a non-positive integer version' {
		$inputJson = '{"settings":{"version":0}}'

		{ Invoke-DotnetSdkConvention -InputJson $inputJson } | Should Throw "The 'version' setting must be a positive integer."
	}
}

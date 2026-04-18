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
		[string] $PayloadJson,

		[string] $SdkVersion = '10.0.100'
	)

	$testDirectory = New-TestDirectory

	try {
		$payloadPath = Join-Path $testDirectory 'payload.json'
		Set-Content -LiteralPath $payloadPath -Value $PayloadJson -Encoding utf8NoBOM

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
			& $conventionScriptPath $payloadPath
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
		$payloadJson = '{"settings":{"version":10}}'

		{ Invoke-DotnetSdkConvention -PayloadJson $payloadJson -SdkVersion '10.0.100' } | Should Not Throw
	}

	It 'accepts a string major version when global.json already conforms' {
		$payloadJson = '{"settings":{"version":"10"}}'

		{ Invoke-DotnetSdkConvention -PayloadJson $payloadJson -SdkVersion '11.0.100' } | Should Not Throw
	}

	It 'rejects a missing version setting' {
		$payloadJson = '{"settings":{}}'

		{ Invoke-DotnetSdkConvention -PayloadJson $payloadJson } | Should Throw "The 'version' setting is required."
	}

	It 'rejects a non-integer version string' {
		$payloadJson = '{"settings":{"version":"10.0"}}'

		{ Invoke-DotnetSdkConvention -PayloadJson $payloadJson } | Should Throw "The 'version' setting must be an integer or a string that parses to an integer."
	}

	It 'rejects a non-positive integer version' {
		$payloadJson = '{"settings":{"version":0}}'

		{ Invoke-DotnetSdkConvention -PayloadJson $payloadJson } | Should Throw "The 'version' setting must be a positive integer."
	}
}

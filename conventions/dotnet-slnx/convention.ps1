Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$solutionFiles = @(Get-ChildItem -Path . -Filter '*.sln' -File -Recurse | Sort-Object -Property FullName)

foreach ($solutionFile in $solutionFiles) {
	$slnPath = $solutionFile.FullName
	$slnxPath = [System.IO.Path]::ChangeExtension($slnPath, '.slnx')

	Write-Host "Migrating solution '$slnPath' to '$slnxPath'."
	& dotnet sln $slnPath migrate | Out-Null

	if ($LASTEXITCODE -ne 0) {
		throw "Failed to migrate solution '$slnPath'."
	}

	if (-not (Test-Path -LiteralPath $slnxPath -PathType Leaf)) {
		throw "Expected migrated solution '$slnxPath' was not created."
	}

	Write-Host "Removing migrated solution file '$slnPath'."
	Remove-Item -LiteralPath $slnPath
}

$dotSettingsFiles = @(Get-ChildItem -Path . -Filter '*.sln.DotSettings' -File -Recurse | Sort-Object -Property FullName)

foreach ($dotSettingsFile in $dotSettingsFiles) {
	$pathWithoutDotSettings = $dotSettingsFile.FullName.Substring(0, $dotSettingsFile.FullName.Length - '.sln.DotSettings'.Length)
	$slnxPath = "${pathWithoutDotSettings}.slnx"

	if (-not (Test-Path -LiteralPath $slnxPath -PathType Leaf)) {
		continue
	}

	$slnxDotSettingsPath = "${slnxPath}.DotSettings"

	if (Test-Path -LiteralPath $slnxDotSettingsPath -PathType Leaf) {
		throw "Cannot rename '$($dotSettingsFile.FullName)' because '$slnxDotSettingsPath' already exists."
	}

	Write-Host "Renaming '$($dotSettingsFile.FullName)' to '$slnxDotSettingsPath'."
	Move-Item -LiteralPath $dotSettingsFile.FullName -Destination $slnxDotSettingsPath
}

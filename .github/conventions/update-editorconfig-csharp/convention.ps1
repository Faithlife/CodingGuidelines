Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helpersPath = Join-Path $PSScriptRoot '..\..\..\conventions\scripts\Helpers.ps1'
. $helpersPath

$sourcePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\sections\csharp\editorconfig.md'))
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\conventions\editorconfig-csharp\.editorconfig'))

$markdown = Get-Content -LiteralPath $sourcePath -Raw
$matches = [System.Text.RegularExpressions.Regex]::Matches($markdown, '```editorconfig\s*(.*?)```', [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($matches.Count -eq 0) {
	throw "No editorconfig code fences were found in '$sourcePath'."
}

[string[]] $lines = [System.Text.RegularExpressions.Regex]::Split((-join ($matches | ForEach-Object { $_.Groups[1].Value })), '\r?\n')

if ($lines.Length -lt 4) {
	throw "Expected at least four generated lines in '$sourcePath', but found $($lines.Length)."
}

$sortedLines = if ($lines.Length -gt 4) {
	$lines[4..($lines.Length - 1)] | Where-Object { $_ -ne '' } | Sort-Object
}
	else {
	@()
}

$newContent = (($lines[0..3] + $sortedLines) -join "`n") + "`n"

if ((Test-Path -LiteralPath $destinationPath -PathType Leaf) -and (Get-Content -LiteralPath $destinationPath -Raw) -eq $newContent) {
	return
}

$destinationDirectory = Split-Path -Parent $destinationPath
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
Write-Utf8NoBomFile -Path $destinationPath -Content $newContent
Write-Host "Updated conventions/editorconfig-csharp/.editorconfig."
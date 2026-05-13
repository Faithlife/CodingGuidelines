#requires -PSEdition Core
#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
$toolArgs = $hookInput.toolArgs | ConvertFrom-Json
$toolName = $hookInput.toolName
$path = $toolArgs.path

if (($toolName -eq 'edit' -or $toolName -eq 'create') -and $path -and $path.EndsWith('.cs')) {
	$relativePath = [System.IO.Path]::GetRelativePath($PWD, $path)
	& dotnet format --include $relativePath
}

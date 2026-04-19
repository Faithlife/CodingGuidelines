Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Get-Command -Name apm -ErrorAction Stop | Out-Null

Write-Host 'Running apm install --update.'
& apm install --update

if ($LASTEXITCODE -ne 0) {
	throw 'apm install --update failed.'
}

$text = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot ".." "editorconfig.md"))
$code = [regex]::Split(-join [regex]::Matches($text, '```editorconfig\s*(.*?)```', 'SingleLine').foreach({$_.Groups[1].Value}), '\r?\n')
$code = $code[0..2] + ($code[3..($code.Length - 1)] | Where-Object { $_ -ne '' } | Sort-Object)
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ".editorconfig"), ($code -join "`n") + "`n")

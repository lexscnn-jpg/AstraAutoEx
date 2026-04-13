# AstraAutoEx development environment for PowerShell
# Usage: . .\env.ps1
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:Path = "$ProjectRoot\tools\elixir\bin;$ProjectRoot\tools\erlang\bin;$ProjectRoot\tools\erlang\erts-16.3.1\bin;C:\Program Files\PostgreSQL\17\bin;$env:Path"
$env:MAKE = "make"
$env:CC = "gcc"
Write-Host "AstraAutoEx env loaded. Run: mix phx.server" -ForegroundColor Green

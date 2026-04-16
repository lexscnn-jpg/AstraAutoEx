@echo off
chcp 65001 >nul 2>&1
title AstraAutoEx - Phoenix Server v0.9.1
color 0A
echo.
echo   AstraAutoEx Phoenix Server v0.9.1
echo   http://localhost:4000
echo.
cd /d "C:\Users\lexsc\Desktop\AstraAutoEx"

:: 绕过 Device Guard：把真实 Erlang OTP 目录放到 PATH 最前面
:: 避免走 Chocolatey shim (C:\ProgramData\chocolatey\bin\erl.exe 被策略阻止)
set "PATH=C:\Program Files\Erlang OTP\bin;%PATH%"

"C:\ProgramData\chocolatey\lib\Elixir\tools\bin\mix.bat" phx.server
pause

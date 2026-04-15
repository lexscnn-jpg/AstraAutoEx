@echo off
title AstraAutoEx - Phoenix Server
color 0A
echo.
echo  ╔══════════════════════════════════════════╗
echo  ║   AstraAutoEx Phoenix Server  v0.7.6    ║
echo  ║   http://localhost:4000                  ║
echo  ╚══════════════════════════════════════════╝
echo.
cd /d "C:\Users\lexsc\Desktop\AstraAutoEx"
"C:\ProgramData\chocolatey\lib\Elixir\tools\bin\mix.bat" phx.server
pause

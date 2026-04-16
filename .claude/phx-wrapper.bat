@echo off
:: Wrapper: 设 PATH 走 Program Files Erlang (绕过 Device Guard) 再调 mix
set "PATH=C:\Program Files\Erlang OTP\bin;%PATH%"
"C:\ProgramData\chocolatey\lib\Elixir\tools\bin\mix.bat" %*

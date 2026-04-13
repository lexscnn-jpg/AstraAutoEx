@echo off
REM AstraAutoEx dev runner
REM Usage: dev mix phx.server
set "DIR=%~dp0"
set "PATH=%DIR%tools\elixir\bin;%DIR%tools\erlang\bin;%DIR%tools\erlang\erts-16.3.1\bin;C:\Program Files\PostgreSQL\17\bin;%PATH%"
set MAKE=make
set CC=gcc
%*

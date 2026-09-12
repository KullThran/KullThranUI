@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Watch-Changelog.ps1" %*
endlocal

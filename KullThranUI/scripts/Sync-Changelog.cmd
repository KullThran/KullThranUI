@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Sync-Changelog.ps1" %*
endlocal
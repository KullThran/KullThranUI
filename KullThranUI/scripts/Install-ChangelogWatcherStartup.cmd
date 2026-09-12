@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Install-ChangelogWatcherStartup.ps1" %*
endlocal

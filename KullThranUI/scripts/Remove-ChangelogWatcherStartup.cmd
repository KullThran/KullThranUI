@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Remove-ChangelogWatcherStartup.ps1" %*
endlocal

@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Install-ChangelogWatcherTask.ps1" %*
endlocal

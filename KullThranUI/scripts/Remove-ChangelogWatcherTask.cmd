@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Remove-ChangelogWatcherTask.ps1" %*
endlocal

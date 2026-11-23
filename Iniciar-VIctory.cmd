@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0VIctory.ps1" -Acao Executar %*
set "resultado=%ERRORLEVEL%"
if not "%resultado%"=="0" if "%~1"=="" pause
exit /b %resultado%

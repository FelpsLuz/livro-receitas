@echo off
rem ============================================================
rem  REINO POR CONQUISTA - atalho para Windows (sem instalar nada)
rem  Abre o jogo em janela propria de aplicativo usando o
rem  Edge (vem em todo Windows 10/11) ou o Chrome.
rem ============================================================
set JOGO=%~dp0index.html

where msedge >nul 2>&1
if %errorlevel%==0 (
  start msedge --app="file:///%JOGO%"
  exit /b
)

if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
  start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app="file:///%JOGO%"
  exit /b
)

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" --app="file:///%JOGO%"
  exit /b
)

rem Sem Edge/Chrome: abre no navegador padrao
start "" "%JOGO%"

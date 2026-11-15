@echo off
rem Genera en la carpeta dist el .zip de Nexo y sus addons que se sube a CurseForge
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Empaquetar.ps1"
echo.
pause

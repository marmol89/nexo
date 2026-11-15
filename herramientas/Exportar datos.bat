@echo off
rem Guarda los datos de Nexo y sus addons en un .zip en el Escritorio
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Datos.ps1" exportar
echo.
pause

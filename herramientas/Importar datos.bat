@echo off
rem Pone en el juego los datos de un .zip exportado. Arrastra el .zip encima de este archivo,
rem o ejecutalo sin nada para usar el mas reciente del Escritorio o de Descargas.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Datos.ps1" importar %1
echo.
pause

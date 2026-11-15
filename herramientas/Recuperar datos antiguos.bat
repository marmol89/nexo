@echo off
rem Para quien actualizo a los addons Nexo_<nombre> borrando las carpetas antiguas y ve los addons vacios:
rem copia los datos guardados con los nombres antiguos a los nuevos. Con el juego cerrado.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Datos.ps1" migrar
echo.
pause

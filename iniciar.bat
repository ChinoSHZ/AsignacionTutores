@echo off
title Cargando Sistema de Tutorias...

:: 1. Entrar a la carpeta de PHP e iniciar el servidor en segundo plano
cd /d "%~dp0backend\php"
start "" /B php.exe -c php.ini ..\artisan serve --host=127.0.0.1 --port=8000

:: 2. Esperar 3 segundos
timeout /t 3 /nobreak >nul

:: 3. Volver a la raíz e iniciar el frontend
cd /d "%~dp0frontend"
start "" "vista_tutoria_flutter.exe"

exit
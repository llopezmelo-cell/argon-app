@echo off
chcp 65001 > nul
echo.
echo ============================================
echo   ARGon - Actualizar datos y subir online
echo ============================================
echo.

cd /d "%~dp0"

echo [1/3] Generando datos de clientes...
powershell -ExecutionPolicy Bypass -File "%~dp0generar-datos.ps1"
if %errorlevel% neq 0 (
    echo ERROR al generar datos.
    pause
    exit /b 1
)

echo.
echo [2/3] Subiendo a internet...
git add datos.json icon-192.png icon-512.png manifest.json
git diff --cached --quiet
if %errorlevel% equ 0 (
    echo    Sin cambios nuevos.
) else (
    git commit -m "Datos %date% %time:~0,5%"
    git push
    if %errorlevel% neq 0 (
        echo ERROR al subir. Verificá tu conexion o credenciales de GitHub.
        pause
        exit /b 1
    )
    echo    Subido OK.
)

echo.
echo [3/3] Listo!
echo    La app en el celular se actualiza automaticamente.
echo.
pause

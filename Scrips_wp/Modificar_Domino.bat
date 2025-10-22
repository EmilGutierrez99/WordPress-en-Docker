@echo off
setlocal enabledelayedexpansion

REM =============================
REM SOLICITAR NOMBRE DE ARCHIVO Y DOMINIO
REM =============================
set /p INPUT_ZIP=Ingrese el nombre del archivo ZIP de entrada (ej. wordpress1-Base-de-datos-1-20251020-1701.zip): 
set /p NEW_DOMAIN=Ingrese el nuevo dominio (ej. micompleto.com): 

REM =============================
REM COPIAR ARCHIVO DESDE DOCKER VOLUME
REM =============================
echo 📦 Copiando "%INPUT_ZIP%" desde el volumen de Docker "volumen_z" a la carpeta actual...
docker run --rm -v volumen_z:/origen -v "%cd%":/destino busybox sh -c "cp /origen/%INPUT_ZIP% /destino"

if not exist "%INPUT_ZIP%" (
    echo ❌ ERROR: No se pudo copiar "%INPUT_ZIP%" desde el volumen.
    pause
    exit /b
)

REM =============================
REM OBTENER NOMBRE BASE Y RUTAS
REM =============================
for %%I in ("%INPUT_ZIP%") do set BASENAME=%%~nI
set OUTPUT_ZIP=%BASENAME%-DominioModificado.zip

set TEMP_DIR=%~dp0temp_wp
set DB_DIR=%TEMP_DIR%\wordpress-DB

echo =============================
echo 📂 Archivo copiado: %INPUT_ZIP%
echo 🌐 Nuevo dominio: %NEW_DOMAIN%
echo 🧾 Archivo de salida: %OUTPUT_ZIP%
echo =============================

REM =============================
REM LIMPIAR TEMPORAL
REM =============================
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

REM =============================
REM 1. EXTRAER ZIP PRINCIPAL
REM =============================
echo 📂 Extrayendo %INPUT_ZIP%...
powershell -Command "Expand-Archive -LiteralPath '%INPUT_ZIP%' -DestinationPath '%TEMP_DIR%' -Force"

if not exist "%TEMP_DIR%\wordpress-DB.zip" (
    echo ❌ ERROR: No se encontró wordpress-DB.zip dentro del archivo.
    pause
    exit /b
)

REM =============================
REM 2. EXTRAER WORDPRESS-DB.ZIP
REM =============================
echo 📂 Extrayendo wordpress-DB.zip...
powershell -Command "Expand-Archive -LiteralPath '%TEMP_DIR%\wordpress-DB.zip' -DestinationPath '%DB_DIR%' -Force"

if not exist "%DB_DIR%\wp.sql" (
    echo ❌ ERROR: No se encontró wp.sql dentro de wordpress-DB.zip.
    pause
    exit /b
)

REM =============================
REM 3. REEMPLAZAR DOMINIO EN wp.sql
REM =============================
echo ✍️ Reemplazando 'localhost:8080' por '%NEW_DOMAIN%' en wp.sql...
powershell -Command "(Get-Content '%DB_DIR%\wp.sql') -replace 'localhost:8080', '%NEW_DOMAIN%' | Set-Content '%DB_DIR%\wp.sql'"

REM =============================
REM 4. VOLVER A COMPRIMIR wordpress-DB.zip
REM =============================
echo 🗜️ Creando nuevo wordpress-DB.zip...
del "%TEMP_DIR%\wordpress-DB.zip"
powershell -Command "Compress-Archive -Path '%DB_DIR%\*' -DestinationPath '%TEMP_DIR%\wordpress-DB.zip'"

REM =============================
REM 5. CREAR ZIP FINAL
REM =============================
echo 🧰 Empaquetando %OUTPUT_ZIP%...
if exist "%OUTPUT_ZIP%" del "%OUTPUT_ZIP%"
powershell -Command "Compress-Archive -Path '%TEMP_DIR%\wordpress-DB.zip','%TEMP_DIR%\wordpress-ficheros.zip' -DestinationPath '%OUTPUT_ZIP%'"

REM =============================
REM 6. COPIAR RESULTADO AL VOLUMEN DOCKER
REM =============================
echo 📤 Copiando "%OUTPUT_ZIP%" al volumen de Docker "volumen_z"...
docker run --rm -v volumen_z:/destino -v "%cd%":/origen busybox sh -c "cp /origen/%OUTPUT_ZIP% /destino"

REM =============================
REM LIMPIEZA FINAL
REM =============================
rmdir /s /q "%TEMP_DIR%"

echo =============================
echo ✅ Proceso completado con éxito.
echo 📂 Archivo generado: %OUTPUT_ZIP%
echo 📤 También guardado en el volumen: volumen_z
echo =============================
pause

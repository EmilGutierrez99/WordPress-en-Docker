@echo off
setlocal enabledelayedexpansion

:: ===========================
:: CONFIGURACIÓN Y PARÁMETROS
:: ===========================
set /p ZIP_ORIG="Nombre del archivo ZIP original (con extensión): "
set /p OLD_DOMAIN="Dominio anterior: "
set /p NEW_DOMAIN="Dominio nuevo: "
set /p VOL_SRC="Nombre del volumen Docker origen: "
set /p VOL_DST="Nombre del volumen Docker destino: "
set /p TMP_DIR="Ruta temporal (por defecto C:\temp\backup_wp): "

if "%TMP_DIR%"=="" set TMP_DIR=C:\temp\backup_wp
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"

set LOG_FILE=%TMP_DIR%\log.txt
echo [%date% %time%] Iniciando proceso >> "%LOG_FILE%"

:: ===========================
:: VALIDACIONES INICIALES
:: ===========================
docker version >nul 2>&1
if errorlevel 1 (
    echo Docker no está disponible. >> "%LOG_FILE%"
    echo ❌ Docker no está disponible.
    exit /b 1
)

if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"

:: ===========================
:: COPIA DESDE VOLUMEN ORIGEN
:: ===========================
echo 📦 Copiando archivo desde volumen origen...
docker run --rm -v %VOL_SRC%:/data -v //c/temp:/backup alpine sh -c "cp /data/%ZIP_ORIG% /backup/" 2>>"%LOG_FILE%"
if errorlevel 1 (
    echo ❌ Error al copiar desde el volumen origen. >> "%LOG_FILE%"
    exit /b 1
)

:: ===========================
:: DESCOMPRESIÓN NIVEL 1
:: ===========================
echo 🧰 Descomprimiendo archivo principal...
powershell -Command "Expand-Archive -Force 'C:\temp\%ZIP_ORIG%' '%TMP_DIR%\zip_ext'" 2>>"%LOG_FILE%"
if errorlevel 1 (
    echo ❌ Error al descomprimir ZIP principal. >> "%LOG_FILE%"
    exit /b 1
)

:: ===========================
:: DESCOMPRESIÓN wordpress-DB.zip
:: ===========================
echo 🧰 Descomprimiendo wordpress-DB.zip...
powershell -Command "Expand-Archive -Force '%TMP_DIR%\zip_ext\wordpress-DB.zip' '%TMP_DIR%\zip_db'" 2>>"%LOG_FILE%"

:: ===========================
:: REEMPLAZO DE DOMINIO
:: ===========================
echo ✍️ Reemplazando dominio en wordpress-DB.sql...
powershell -Command "(Get-Content '%TMP_DIR%\zip_db\wordpress-DB.sql') -replace '%OLD_DOMAIN%', '%NEW_DOMAIN%' | Set-Content '%TMP_DIR%\zip_db\wordpress-DB.sql'" 2>>"%LOG_FILE%"

:: ===========================
:: REEMPACAR wordpress-DB.zip
:: ===========================
echo 📦 Reempaquetando wordpress-DB.zip...
powershell -Command "Compress-Archive -Path '%TMP_DIR%\zip_db\*' -DestinationPath '%TMP_DIR%\zip_ext\wordpress-DB.zip' -Force" 2>>"%LOG_FILE%"

:: ===========================
:: REEMPACAR ARCHIVO FINAL
:: ===========================
set FINAL_ZIP=%ZIP_ORIG:.zip=-Modificado.zip%
echo 📦 Creando %FINAL_ZIP%...
powershell -Command "Compress-Archive -Path '%TMP_DIR%\zip_ext\*' -DestinationPath 'C:\temp\%FINAL_ZIP%' -Force" 2>>"%LOG_FILE%"

:: ===========================
:: SUBIR AL VOLUMEN DESTINO
:: ===========================
echo 🚀 Subiendo al volumen destino...
docker run --rm -v %VOL_DST%:/data -v //c/temp:/backup alpine sh -c "cp /backup/%FINAL_ZIP% /data/" 2>>"%LOG_FILE%"
if errorlevel 1 (
    echo ❌ Error al subir al volumen destino. >> "%LOG_FILE%"
    exit /b 1
)

:: ===========================
:: LIMPIEZA FINAL
:: ===========================
echo 🧹 Limpiando archivos temporales...
rmdir /s /q "%TMP_DIR%"

echo ✅ Proceso completado. Archivo final: %FINAL_ZIP%
echo [%date% %time%] Proceso completado con éxito >> "%LOG_FILE%"
exit /b 0

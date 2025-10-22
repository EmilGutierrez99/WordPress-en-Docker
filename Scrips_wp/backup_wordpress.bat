@echo off
setlocal EnableDelayedExpansion

:: ===================================================
:: BACKUP DOCKER WORDPRESS + MYSQL  (.ZIP version)
:: US-98 (Compatible con CMD ANSI - sin BOM)
:: ===================================================

title Backup Docker WP + MySQL
color 0A

echo.
echo ===============================================
echo   BACKUP DOCKER WORDPRESS + MYSQL  (US-98)
echo ===============================================
echo.

:: Verificar Docker
docker version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker no esta disponible.
    echo Abre Docker Desktop e intenta nuevamente.
    echo.
    pause
    exit /b
)

:: Solicitar datos al usuario
set "WP_CONTAINER="
set /p "WP_CONTAINER=Nombre del contenedor WordPress (ej: wordpress1): "
if "%WP_CONTAINER%"=="" (
    echo Debes ingresar un nombre valido.
    pause
    exit /b
)

set "DB_CONTAINER="
set /p "DB_CONTAINER=Nombre del contenedor de Base de Datos (ej: Base-de-datos-1): "
if "%DB_CONTAINER%"=="" (
    echo Debes ingresar un nombre valido.
    pause
    exit /b
)

set "TARGET_VOLUME="
set /p "TARGET_VOLUME=Nombre del volumen destino (ej: volumen_z): "
if "%TARGET_VOLUME%"=="" (
    echo Debes ingresar un nombre valido.
    pause
    exit /b
)

:: Validaciones
docker inspect "%WP_CONTAINER%" >nul 2>&1 || (
    echo [ERROR] El contenedor %WP_CONTAINER% no existe.
    pause
    exit /b
)
docker inspect "%DB_CONTAINER%" >nul 2>&1 || (
    echo [ERROR] El contenedor %DB_CONTAINER% no existe.
    pause
    exit /b
)
docker volume inspect "%TARGET_VOLUME%" >nul 2>&1 || (
    echo [ERROR] El volumen %TARGET_VOLUME% no existe.
    pause
    exit /b
)

:: Crear carpeta temporal
set "BASE_TMP=C:\temp\backup_wp"
if exist "%BASE_TMP%" rd /s /q "%BASE_TMP%" >nul 2>&1
mkdir "%BASE_TMP%" >nul 2>&1
echo [OK] Carpeta temporal creada: %BASE_TMP%

:: Obtener fecha y hora
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set ldt=%%i
set "STAMP=!ldt:~0,8!-!ldt:~8,4!"

:: Leer variables de entorno del contenedor DB
echo.
echo Detectando variables de entorno de la base de datos...
docker exec "%DB_CONTAINER%" sh -c "env" > "%BASE_TMP%\env.txt" 2>nul
if errorlevel 1 (
    echo [ERROR] No se pudo leer el entorno del contenedor de base de datos.
    pause
    exit /b
)

set "MYSQL_DATABASE="
set "MYSQL_ROOT_PASSWORD="
set "MYSQL_USER="
set "MYSQL_PASSWORD="

for /f "usebackq tokens=1,2 delims==" %%A in ("%BASE_TMP%\env.txt") do (
    if /I "%%A"=="MYSQL_DATABASE" set "MYSQL_DATABASE=%%B"
    if /I "%%A"=="MYSQL_ROOT_PASSWORD" set "MYSQL_ROOT_PASSWORD=%%B"
    if /I "%%A"=="MYSQL_USER" set "MYSQL_USER=%%B"
    if /I "%%A"=="MYSQL_PASSWORD" set "MYSQL_PASSWORD=%%B"
)

if "%MYSQL_DATABASE%"=="" set "MYSQL_DATABASE=wordpress"

if not "%MYSQL_ROOT_PASSWORD%"=="" (
    set "DB_USER=root"
    set "DB_PASS=%MYSQL_ROOT_PASSWORD%"
) else (
    if not "%MYSQL_USER%"=="" if not "%MYSQL_PASSWORD%"=="" (
        set "DB_USER=%MYSQL_USER%"
        set "DB_PASS=%MYSQL_PASSWORD%"
    ) else (
        echo [ERROR] No se encontraron credenciales de MySQL.
        pause
        exit /b
    )
)

echo [OK] DB=%MYSQL_DATABASE%  USER=%DB_USER%

:: Exportar base de datos
echo.
echo Exportando base de datos...
docker exec "%DB_CONTAINER%" sh -c "mysqldump -u%DB_USER% -p%DB_PASS% %MYSQL_DATABASE% > /tmp/wp.sql" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Error al exportar base de datos.
    pause
    exit /b
)

docker cp "%DB_CONTAINER%":/tmp/wp.sql "%BASE_TMP%\wp.sql" >nul 2>&1
docker exec "%DB_CONTAINER%" sh -c "rm -f /tmp/wp.sql" >nul 2>&1
echo [OK] Base de datos exportada correctamente.

:: Copiar ficheros de WordPress
echo.
echo Copiando ficheros desde %WP_CONTAINER%:/var/www/html ...
docker cp "%WP_CONTAINER%":/var/www/html "%BASE_TMP%\html" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se pudieron copiar los ficheros del sitio.
    pause
    exit /b
)
echo [OK] Ficheros copiados.

:: Crear ZIPs individuales
echo.
echo Creando archivos ZIP parciales...
powershell -Command "Compress-Archive -Path '%BASE_TMP%\html\*' -DestinationPath '%BASE_TMP%\wordpress-ficheros.zip' -Force" >nul 2>&1
powershell -Command "Compress-Archive -Path '%BASE_TMP%\wp.sql' -DestinationPath '%BASE_TMP%\wordpress-DB.zip' -Force" >nul 2>&1

if not exist "%BASE_TMP%\wordpress-ficheros.zip" (
    echo [ERROR] No se pudo crear wordpress-ficheros.zip
    pause
    exit /b
)
if not exist "%BASE_TMP%\wordpress-DB.zip" (
    echo [ERROR] No se pudo crear wordpress-DB.zip
    pause
    exit /b
)

:: Crear ZIP final
set "FINAL_ZIP=%BASE_TMP%\%WP_CONTAINER%-%DB_CONTAINER%-%STAMP%.zip"
echo.
echo Empaquetando backup final: %FINAL_ZIP%
powershell -Command "Compress-Archive -Path '%BASE_TMP%\wordpress-ficheros.zip','%BASE_TMP%\wordpress-DB.zip' -DestinationPath '%FINAL_ZIP%' -Force" >nul 2>&1

if not exist "%FINAL_ZIP%" (
    echo [ERROR] No se pudo generar el ZIP final.
    pause
    exit /b
)

:: Copiar al volumen destino (usando contenedor temporal)
echo.
echo Copiando backup al volumen %TARGET_VOLUME% ...
docker run --rm -d --name tmp_backup_copy -v "%TARGET_VOLUME%":/data alpine sleep 60 >nul 2>&1
docker cp "%FINAL_ZIP%" tmp_backup_copy:/data/ >nul 2>&1
docker rm -f tmp_backup_copy >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Fallo al copiar el ZIP dentro del volumen.
    pause
    exit /b
)

:: Limpiar
rd /s /q "%BASE_TMP%" >nul 2>&1

echo.
echo ===============================================
echo  PROCESO FINALIZADO CON EXITO
echo  Backup generado: %WP_CONTAINER%-%DB_CONTAINER%-%STAMP%.zip
echo  Guardado en volumen: %TARGET_VOLUME%
echo ===============================================
echo.
pause
exit /b

@echo off
setlocal enabledelayedexpansion

:: ===================================================
:: RESTORE DOCKER WORDPRESS + MYSQL (.ZIP)
:: US-99 - Version Final Estable y Robusta
:: ===================================================

title Restore Docker WP + MySQL
color 0A

echo.
echo ===============================================
echo   RESTORE DOCKER WORDPRESS + MYSQL  (US-99)
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

:: Pedir datos
set /p "WP_CONTAINER=Contenedor WordPress destino (ej: wordpress2): "
set /p "DB_CONTAINER=Contenedor Base de Datos destino (ej: Base-de-datos-2): "
set /p "TARGET_VOLUME=Volumen donde esta el backup (ej: volumen_z): "

if "%WP_CONTAINER%"=="" goto end
if "%DB_CONTAINER%"=="" goto end
if "%TARGET_VOLUME%"=="" goto end

:: Mostrar archivos disponibles
echo.
echo Backups disponibles en el volumen "%TARGET_VOLUME%":
docker run --rm -v "%TARGET_VOLUME%":/data alpine ls -1 /data/*.zip 2>nul

echo.
set /p "BACKUP_FILE=Nombre exacto del archivo de backup: "
if "%BACKUP_FILE%"=="" goto end

:: Carpeta temporal
set "BASE_TMP=C:\temp\restore_wp"
if exist "%BASE_TMP%" rd /s /q "%BASE_TMP%" >nul 2>&1
mkdir "%BASE_TMP%" >nul 2>&1

echo.
echo Copiando backup al sistema local...
docker run --rm -v "%TARGET_VOLUME%":/data -v "%BASE_TMP%":/dest alpine cp "/data/%BACKUP_FILE%" /dest/ 2>nul
if errorlevel 1 (
    echo [ERROR] No se pudo copiar el backup desde el volumen.
    pause
    exit /b
)
echo [OK] Copia realizada: %BASE_TMP%\%BACKUP_FILE%

:: Extraer contenido principal
echo.
echo Extrayendo contenido del backup...
powershell -Command "Expand-Archive -Path '%BASE_TMP%\%BACKUP_FILE%' -DestinationPath '%BASE_TMP%' -Force" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se pudo extraer el backup.
    pause
    exit /b
)

:: Extraer internos
powershell -Command "Expand-Archive -Path '%BASE_TMP%\wordpress-ficheros.zip' -DestinationPath '%BASE_TMP%\html' -Force" >nul 2>&1
powershell -Command "Expand-Archive -Path '%BASE_TMP%\wordpress-DB.zip' -DestinationPath '%BASE_TMP%' -Force" >nul 2>&1

if not exist "%BASE_TMP%\html" (
    echo [ERROR] No se encontro la carpeta html.
    pause
    exit /b
)
if not exist "%BASE_TMP%\wp.sql" (
    echo [ERROR] No se encontro el archivo wp.sql.
    pause
    exit /b
)

:: Detener contenedores destino
echo.
echo Deteniendo contenedores destino...
docker stop "%WP_CONTAINER%" >nul 2>&1
docker stop "%DB_CONTAINER%" >nul 2>&1

:: Iniciar contenedores antes de restaurar
echo Iniciando contenedores destino...
docker start "%DB_CONTAINER%" >nul 2>&1
docker start "%WP_CONTAINER%" >nul 2>&1

:: Esperar unos segundos para que ambos esten listos
echo Esperando a que los contenedores esten listos...
ping 127.0.0.1 -n 6 >nul

:: ==============================================
:: Restaurar archivos de WordPress (modo robusto)
:: ==============================================
echo.
echo Restaurando archivos de WordPress...

:: Confirmar que el contenedor esta realmente en ejecucion
for /f "tokens=*" %%i in ('docker inspect -f "{{.State.Running}}" %WP_CONTAINER% 2^>nul') do set "IS_RUNNING=%%i"

if /I NOT "%IS_RUNNING%"=="true" (
    echo [INFO] El contenedor "%WP_CONTAINER%" no esta corriendo. Intentando iniciarlo...
    docker start "%WP_CONTAINER%" >nul 2>&1
    ping 127.0.0.1 -n 6 >nul
)

:: Espera extra para asegurar inicializacion completa
echo Esperando que el contenedor "%WP_CONTAINER%" este completamente listo...
ping 127.0.0.1 -n 6 >nul

:: Crear /var/www/html incluso si no existe
echo Creando ruta /var/www/html en "%WP_CONTAINER%"...
mkdir "%BASE_TMP%\_empty" >nul 2>&1
docker cp "%BASE_TMP%\_empty" "%WP_CONTAINER%":/var/www/ >nul 2>&1
docker exec "%WP_CONTAINER%" sh -c "test -d /var/www/html" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se pudo crear /var/www/html dentro de "%WP_CONTAINER%".
    echo Verifica que el contenedor WordPress sea una imagen basada en WordPress o tenga /var/www/html.
    pause
    exit /b
)
rd /s /q "%BASE_TMP%\_empty" >nul 2>&1

:: Limpiar contenido anterior
docker exec "%WP_CONTAINER%" sh -c "rm -rf /var/www/html/*" >nul 2>&1

:: Copiar archivos restaurados
docker cp "%BASE_TMP%\html\." "%WP_CONTAINER%":/var/www/html/ >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se pudieron copiar los archivos al contenedor WordPress.
    echo Verifica que el contenedor "%WP_CONTAINER%" este en ejecucion y tenga /var/www/html.
    pause
    exit /b
)
echo [OK] Archivos restaurados correctamente en %WP_CONTAINER%.

:: ==============================================
:: Restaurar base de datos MySQL
:: ==============================================
echo.
echo Restaurando base de datos...
for /f "usebackq tokens=1,2 delims==" %%A in (`docker exec "%DB_CONTAINER%" sh -c "env"`) do (
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
        echo [ERROR] No se pudieron detectar las credenciales de MySQL.
        pause
        exit /b
    )
)

docker cp "%BASE_TMP%\wp.sql" "%DB_CONTAINER%":/tmp/wp.sql >nul 2>&1
docker exec "%DB_CONTAINER%" sh -c "mysql -u%DB_USER% -p%DB_PASS% %MYSQL_DATABASE% < /tmp/wp.sql" >nul 2>&1
docker exec "%DB_CONTAINER%" sh -c "rm -f /tmp/wp.sql" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Fallo al restaurar la base de datos.
    pause
    exit /b
)
echo [OK] Base de datos restaurada correctamente en %DB_CONTAINER%.

:: Reiniciar WordPress (asegurar servicio)
docker restart "%WP_CONTAINER%" >nul 2>&1

:: Limpiar archivos temporales
rd /s /q "%BASE_TMP%" >nul 2>&1

echo.
echo ===============================================
echo  RESTAURACION COMPLETADA CON EXITO
echo  Backup restaurado en:
echo     - WordPress: %WP_CONTAINER%
echo     - Base de Datos: %DB_CONTAINER%
echo ===============================================
echo.
pause
exit /b

:end
echo Operacion cancelada.
pause
exit /b

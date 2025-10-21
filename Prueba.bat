@echo off
title WordPress en Docker
color 0A

echo ================================
echo   GESTOR DE WORDPRESS EN DOCKER
echo ================================
echo.

:MENU
echo Selecciona una opcion:
echo 1. Iniciar WordPress y MySQL
echo 2. Detener contenedores
echo 3. Eliminar contenedores
echo 4. Salir
echo.
set /p opcion=Opcion: 

if "%opcion%"=="1" goto INICIAR
if "%opcion%"=="2" goto DETENER
if "%opcion%"=="3" goto ELIMINAR
if "%opcion%"=="4" goto SALIR

:INICIAR
echo Iniciando MySQL...
docker run -d --name mysql-wp -e MYSQL_ROOT_PASSWORD=12345 -e MYSQL_DATABASE=wordpress mysql

echo Iniciando WordPress...
docker run -d --name mi-wordpress -p 8080:80 -e WORDPRESS_DB_HOST=mysql-wp:3306 -e WORDPRESS_DB_USER=root -e WORDPRESS_DB_PASSWORD=12345 -e WORDPRESS_DB_NAME=wordpress --link mysql-wp:mysql wordpress

echo.
echo WordPress esta iniciando...
echo Abre http://localhost:8080 en tu navegador.
pause
goto MENU

:DETENER
echo Deteniendo contenedores...
docker stop mi-wordpress
docker stop mysql-wp
echo Contenedores detenidos.
pause
goto MENU

:ELIMINAR
echo Eliminando contenedores...
docker rm -f mi-wordpress
docker rm -f mysql-wp
echo Contenedores eliminados.
pause
goto MENU

:SALIR
echo Cerrando programa...
exit

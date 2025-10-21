# Imagen base con Apache y PHP
FROM php:8.2-apache

# Instalar extensiones necesarias para WordPress
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev zip unzip \
    mariadb-server wget \
    && docker-php-ext-install mysqli gd zip \
    && apt-get clean

# Descargar la última versión de WordPress
RUN wget https://wordpress.org/latest.tar.gz \
    && tar -xvzf latest.tar.gz \
    && rm latest.tar.gz \
    && mv wordpress/* /var/www/html/ \
    && chown -R www-data:www-data /var/www/html

# Exponer puerto de Apache
EXPOSE 80

# Iniciar MySQL y Apache al mismo tiempo
CMD service mysql start && apache2-foreground

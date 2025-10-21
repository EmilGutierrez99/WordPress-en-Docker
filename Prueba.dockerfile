# Imagen base
FROM ubuntu:22.04

# Evita prompts interactivos al instalar paquetes
ENV DEBIAN_FRONTEND=noninteractive

# Actualiza paquetes e instala Apache, PHP y MySQL
RUN apt-get update && apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    php-mysql \
    mysql-server \
    curl \
    unzip \
    && apt-get clean

# Habilita Apache y PHP
RUN a2enmod rewrite

# Crea un archivo de prueba PHP
RUN echo "<?php phpinfo(); ?>" > /var/www/html/index.php

# Ajusta permisos
RUN chown -R www-data:www-data /var/www/html

# Exponer el puerto 80
EXPOSE 80

# Comando para iniciar Apache y MySQL juntos
CMD service mysql start && apachectl -D FOREGROUND

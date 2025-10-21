# Imagen base
FROM ubuntu:22.04

# Evitar prompts
ENV DEBIAN_FRONTEND=noninteractive

# Instalar Apache y PHP
RUN apt-get update && apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    && apt-get clean

# Eliminar la página por defecto de Apache
RUN rm -f /var/www/html/index.html

# Crear un archivo PHP con phpinfo
RUN echo "<?php phpinfo(); ?>" > /var/www/html/index.php

# Dar permisos a Apache
RUN chown -R www-data:www-data /var/www/html

# Exponer puerto 80
EXPOSE 80

# Iniciar Apache
CMD ["apachectl", "-D", "FOREGROUND"]

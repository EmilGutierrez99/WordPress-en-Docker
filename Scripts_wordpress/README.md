# 🧾 Backup y Restore de Contenedores Docker (WordPress + MySQL)

## 📘 Descripción General

Este proyecto contiene dos scripts `.bat` para **Windows 10+** que automatizan la **creación y restauración de backups** de entornos WordPress en Docker.  
Permiten guardar y recuperar fácilmente tanto los **ficheros del sitio WordPress** como su **base de datos MySQL**, facilitando la migración o clonación de entornos.

Incluye:

- `backup_wp.bat` → Genera un archivo de backup comprimido.
- `restore_wp.bat` → Restaura un entorno WordPress desde un archivo de backup.

---

## ⚙️ Requisitos Previos

Antes de ejecutar cualquiera de los scripts, asegúrate de tener lo siguiente:

### 🧱 Software necesario

- **Windows 10 o superior**
- **Docker Desktop** instalado y en ejecución
- **Contenedores Docker** creados:
  - Uno para **WordPress**
  - Uno para **MySQL**
- **Volumen Docker** para almacenar los backups (por ejemplo: `volumen_z`)

### 📦 Ejemplo de `docker-compose.yml`

```yaml
version: "3.9"
services:
  db2:
    image: mysql:latest
    container_name: Base-de-datos-2
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 1234
      MYSQL_DATABASE: wordpress2
    volumes:
      - db2_data:/var/lib/mysql

  wordpress2:
    image: wordpress:latest
    container_name: wordpress-2
    restart: always
    ports:
      - "8090:80"
    environment:
      WORDPRESS_DB_HOST: db2:3306
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: 1234
      WORDPRESS_DB_NAME: wordpress2
    volumes:
      - wordpress2_data:/var/www/html
    depends_on:
      - db2

volumes:
  db2_data:
  wordpress2_data:
```

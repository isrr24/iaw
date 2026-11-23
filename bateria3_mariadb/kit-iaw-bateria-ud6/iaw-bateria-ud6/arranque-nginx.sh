#!/bin/sh
# Arranque del contenedor «nginx»: enlaza el sitio (que vive en servidor/nginx, dentro de Git) y arranca Nginx.
set -e
ln -sf /etc/nginx/sites-available/inventario.conf /etc/nginx/sites-enabled/inventario.conf
exec nginx -g 'daemon off;'

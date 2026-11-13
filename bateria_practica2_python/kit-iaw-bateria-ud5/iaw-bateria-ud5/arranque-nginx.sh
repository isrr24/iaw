#!/bin/sh
# Arranque del contenedor «nginx»: enlaza el sitio y arranca Nginx en primer plano.
set -e
ln -sf /etc/nginx/sites-available/polideportivo.conf /etc/nginx/sites-enabled/polideportivo.conf
exec nginx -g 'daemon off;'

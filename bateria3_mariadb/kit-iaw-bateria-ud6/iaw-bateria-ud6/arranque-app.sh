#!/bin/sh
# Arranque del contenedor «app»: lee las variables de servidor/inventario.env y arranca Gunicorn.
# Si cambias inventario.env o app.py: ./bateria.sh recargar
set -e
set -a; . /etc/inventario/inventario.env; set +a
mkdir -p /var/log/lab && chmod 777 /var/log/lab
cd /srv/app
exec gunicorn --bind 0.0.0.0:8000 --workers 3 --access-logfile /var/log/lab/gunicorn-acceso.log \
     --error-logfile /var/log/lab/gunicorn-errores.log app:app

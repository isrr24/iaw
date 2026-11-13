#!/bin/sh
# Arranque del contenedor «app»: lee las variables de config/polideportivo.env y arranca Gunicorn con config/gunicorn.conf.py.
# Si cambias algo (el .env, gunicorn.conf.py o el código): ./bateria.sh recargar
set -e
set -a; . /lab/config/polideportivo.env; set +a
mkdir -p /var/log/lab && chmod 777 /var/log/lab
cd /srv/polideportivo
exec gunicorn -c /lab/config/gunicorn.conf.py app:app

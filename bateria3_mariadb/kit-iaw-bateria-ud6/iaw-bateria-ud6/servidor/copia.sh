#!/bin/sh
# Copia de la base de datos del inventario. Se lanza con: ./bateria.sh copia
# (en un servidor de verdad, cron la lanzaría cada noche: 30 3 * * * /srv/servidor/copia.sh)
# Este script va a Git (bloque 5): por eso NO lleva ninguna contraseña escrita.
set -e

# ✍️ Paso 1 · Carga las variables de /srv/servidor/inventario.env (con el punto: . fichero). Así tienes $DB_HOST, $DB_USER…


# ✍️ Paso 2 · Una variable FECHA con la fecha y la hora: 20261123-033000 (date +%Y%m%d-%H%M%S)


# ✍️ Paso 3 · La copia con mysqldump, con los datos de inventario.env, en /copias/inventario-$FECHA.sql
#        Opciones: --single-transaction (una foto coherente sin bloquear la web) y --no-tablespaces.
#        Ojo: -p"$DB_PASS" va PEGADO, sin espacio.


# ✍️ Paso 4 · Borra las copias de más de 7 días: find /copias -name 'inventario-*.sql' -mtime +7 …


echo "Copia hecha: /copias/inventario-$FECHA.sql"

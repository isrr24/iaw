#!/usr/bin/env bash
# Batería UD6 · El inventario del aula (MariaDB + PHP + Python + Git). El mando a distancia: no hace falta escribir órdenes de Docker.
#   ./bateria.sh arrancar          levanta el inventario (la primera vez tarda: descarga las imágenes)
#   ./bateria.sh comprobar [N]     comprueba todo, o solo el bloque N, con pistas
#   ./bateria.sh sql               aplica sql/bloque1.sql como root, dentro del servidor de base de datos (bloque 1)
#   ./bateria.sh mariadb           abre la consola de MariaDB como root, dentro del servidor (para mirar; EXIT; para salir)
#   ./bateria.sh admin             abre una terminal en «admin», el ordenador del administrador (Git y mariadb -h db)
#   ./bateria.sh copia             lanza servidor/copia.sh en «admin» (bloque 4)
#   ./bateria.sh recargar          aplica tus cambios: nginx -t + recarga Nginx, y reinicia la API (Python)
#   ./bateria.sh logs              las últimas líneas de los logs (Nginx y Gunicorn)
#   ./bateria.sh parar             lo apaga todo (la base de datos se conserva)
#   ./bateria.sh desde-cero        borra la base de datos y la vuelve a crear como al principio (tus ficheros se quedan)
set -uo pipefail
cd "$(dirname "$0")"
V=$'\e[32m'; R=$'\e[31m'; N=$'\e[1m'; X=$'\e[0m'
ROOTPW=raiz-de-la-bateria      # la de compose.yaml: solo para la batería

command -v docker >/dev/null 2>&1 || { echo "${R}✘ No encuentro Docker.${X} Es el mismo de la práctica 1: instálalo (o arranca Docker Desktop) y vuelve a probar."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "${R}✘ Docker no responde.${X} ¿Está arrancado? (en Linux: sudo systemctl start docker)"; exit 1; }
esperar_db() { for _ in $(seq 1 60); do docker compose exec -T db healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1 && return 0; sleep 1; done; echo "${R}✘ MariaDB no arranca:${X} docker compose logs db"; exit 1; }

case "${1:-ayuda}" in
  arrancar)
    docker compose up -d --build || exit 1
    esperar_db
    echo
    echo "${V}✔ El inventario está en marcha:${X} https://localhost:8450  (el certificado es de prueba: acepta el aviso)"
    echo "  Ahora: ${N}./bateria.sh comprobar${X}  (al principio, solo los ejemplos 👀 en verde: 4 de 32)" ;;
  comprobar)
    bash comprobador/comprobar.sh "${2:-}" ;;
  sql)
    echo "Aplicando sql/bloque1.sql como root…"
    if docker compose exec -T db mariadb -uroot -p"$ROOTPW" < sql/bloque1.sql; then
        echo "${V}✔ Aplicado.${X} Ahora: ./bateria.sh comprobar 1"
    else
        echo "${R}✘ MariaDB ha parado en el error de arriba${X} («at line NN»: la línea de sql/bloque1.sql). Lo de antes de esa línea sí se ha aplicado."; exit 1
    fi ;;
  mariadb)
    docker compose exec db mariadb -uroot -p"$ROOTPW" inventario ;;
  admin)
    echo "Estás en «admin», en /srv/servidor (tu carpeta servidor/). Para entrar en MariaDB como inv_web: mariadb -h db -u inv_web -p inventario · exit para salir"
    docker compose exec admin bash ;;
  copia)
    docker compose exec -T admin timeout 20 sh /srv/servidor/copia.sh </dev/null
    [ $? = 124 ] && echo "${R}✘ copia.sh se ha quedado esperando una contraseña.${X} ¿Carga inventario.env? ¿-p\"\$DB_PASS\" va pegado?" ;;
  recargar)
    docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload && echo "${V}✔ Nginx recargado${X}" || exit 1
    docker compose restart app >/dev/null && echo "${V}✔ API reiniciada${X} (si no responde: ./bateria.sh logs)" ;;
  logs)
    for f in logs/inventario_error.log logs/gunicorn-errores.log; do
      [ -s "$f" ] && { echo "${N}── $f${X}"; tail -n 8 "$f"; }
    done
    echo "${N}── docker compose logs app${X}"; docker compose logs --tail 8 app ;;
  parar)
    docker compose down ;;
  desde-cero)
    docker compose down -v && docker compose up -d && esperar_db && echo "${V}✔ Base de datos nueva, como al principio.${X} Lo tuyo de sql/bloque1.sql: ./bateria.sh sql" ;;
  *)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' ;;
esac

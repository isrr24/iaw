#!/usr/bin/env bash
# Batería UD5 · Las reservas del polideportivo (Nginx + Gunicorn + Flask). El mando a distancia: no hace falta escribir órdenes de Docker.
#   ./bateria.sh arrancar          levanta el polideportivo (la primera vez tarda: descarga las imágenes)
#   ./bateria.sh comprobar [N]     comprueba todo, o solo el bloque N, con pistas
#   ./bateria.sh recargar          aplica tus cambios: nginx -t + recarga Nginx, y reinicia la app (Python)
#   ./bateria.sh llave             genera una SECRET_KEY nueva, al azar (para el bloque 4)
#   ./bateria.sh logs              las últimas líneas de los logs (Nginx y Gunicorn)
#   ./bateria.sh parar             lo apaga todo
set -uo pipefail
cd "$(dirname "$0")"
V=$'\e[32m'; R=$'\e[31m'; N=$'\e[1m'; X=$'\e[0m'

command -v docker >/dev/null 2>&1 || { echo "${R}✘ No encuentro Docker.${X} Es el mismo de la práctica 1: instálalo (o arranca Docker Desktop) y vuelve a probar."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "${R}✘ Docker no responde.${X} ¿Está arrancado? (en Linux: sudo systemctl start docker)"; exit 1; }

case "${1:-ayuda}" in
  arrancar)
    docker compose up -d --build || exit 1
    echo
    echo "${V}✔ El polideportivo está abierto:${X} https://localhost:8448  (el certificado es de prueba: acepta el aviso)"
    echo "  Ahora: ${N}./bateria.sh comprobar${X}  (al principio, solo los ejemplos 👀 en verde: 5 de 32)" ;;
  comprobar)
    bash comprobador/comprobar.sh "${2:-}" ;;
  recargar)
    docker compose exec -T nginx nginx -t && docker compose exec -T nginx nginx -s reload && echo "${V}✔ Nginx recargado${X}" || exit 1
    docker compose restart app >/dev/null && echo "${V}✔ App reiniciada${X} (si no responde: ./bateria.sh logs)" ;;
  llave)
    docker compose exec -T app python3 -c "import secrets; print(secrets.token_hex(32))" ;;
  logs)
    for f in logs/polideportivo_error.log logs/gunicorn-errores.log logs/gunicorn-acceso.log; do
      [ -s "$f" ] && { echo "${N}── $f${X}"; tail -n 8 "$f"; }
    done
    echo "${N}── docker compose logs app${X}"; docker compose logs --tail 8 app ;;
  parar)
    docker compose down ;;
  *)
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' ;;
esac

#!/usr/bin/env bash
# Comprobador de la batería UD5 (las reservas del polideportivo). Se lanza con: ./bateria.sh comprobar [N]
# El bloque 1 se comprueba con curl DESDE «cliente», como un usuario, pasando por Nginx. Los demás, hablando directamente
# con la app (app:8000, desde el contenedor de Nginx): así cada bloque se puede hacer sin haber terminado el 1.
# No da la solución: dice qué caso falla, qué ha salido y, si es una trampa conocida, cuál es.
set -u   # sin pipefail: «… | grep -q» corta la tubería al encontrar y daría falsos fallos
cd "$(dirname "$0")/.."
SOLO=${1:-}
URL=https://polideportivo.iaw.local
APP=http://app:8000
AYUDA=$(cat comprobador/ayuda.py)

V=$'\e[32m'; R=$'\e[31m'; A=$'\e[33m'; G=$'\e[90m'; N=$'\e[1m'; X=$'\e[0m'

# ── Acceso a los contenedores ────────────────────────────────────────────────
web()       { docker compose exec -T cliente curl -sk --max-time 12 "$@" 2>/dev/null; }      # como un usuario, por Nginx
app()       { docker compose exec -T nginx curl -s --max-time 12 "$@" 2>/dev/null; }         # directo a Gunicorn
codigo()    { "$1" -o /dev/null -w '%{http_code}' "${@:2}"; }                                # codigo web|app …
cabeceras() { "$1" -o /dev/null -D - "${@:2}" | tr -d '\r'; }
ayuda()     { docker compose exec -T app python3 -c "$AYUDA" "$@" 2>/dev/null; }
en_app()    { docker compose exec -T app sh -c "$1" 2>/dev/null; }
gconf()     { en_app "cd /tmp && python3 -c \"exec(open('/lab/config/gunicorn.conf.py').read()); print(globals().get('$1', ''))\""; }
entorno()   { en_app 'tr "\0" "\n" < /proc/1/environ' | sed -n "s/^$1=//p"; }                # lo que tiene Gunicorn DE VERDAD

# ── 0 · Que esté arrancado, y aplicar tus cambios (igual que ./bateria.sh recargar) ──
if ! docker compose ps --status running -q cliente 2>/dev/null | grep -q .; then
    echo "${R}✘ La batería no está arrancada.${X} Primero: ${N}./bateria.sh arrancar${X}"; exit 1
fi
if ! salida=$(docker compose exec -T nginx nginx -t 2>&1); then
    echo "${R}✘ polideportivo.conf tiene un error y Nginx no lo acepta (nginx -t):${X}"
    grep -E 'emerg|error' <<<"$salida" | sed 's/^/    /'
    echo "  ${A}💡 La línea que falla viene al final del mensaje («in …polideportivo.conf:NN»). Suele ser un «;» o una «}» que falta.${X}"
    exit 1
fi
docker compose exec -T nginx nginx -s reload >/dev/null 2>&1
DESDE=$(date +%s)
docker compose restart app >/dev/null 2>&1
arranca=0
for _ in $(seq 1 20); do [ "$(codigo app "$APP/")" = 200 ] && { arranca=1; break; }; sleep 0.5; done
if [ "$arranca" = 0 ]; then
    echo "${R}✘ La app no arranca después de reiniciarla.${X} Esto dice Python (docker compose logs app):"
    docker compose logs --no-log-prefix --since "$DESDE" app 2>&1 | grep -vE '\[INFO\]|<frozen|^Traceback|\[ERROR\]' | tail -n 6 | sed 's/^/    /'
    echo "  ${A}💡 La última línea dice qué pasa y la de «File …, line NN», dónde. Suele ser un error de sangría o de sintaxis en app.py,"
    echo "     o una línea mal escrita en config/ (KeyError: 'SECRET_KEY' = falta esa variable en polideportivo.env).${X}"
    exit 1
fi
echo "${G}→ nginx -t ✔ · Nginx recargado · app reiniciada (lo mismo que ./bateria.sh recargar)${X}"

# ── Resultados ────────────────────────────────────────────────────────────────
ok=0; total=0; bok=0; btot=0; primero_dado=0
MSG=""; TRAMPA=""
declare -A EMPEZAR=(
  [1.3]="En «location /», cambia =404 por @app. Y debajo, un bloque «location @app { … }» con proxy_pass y proxy_set_header Host (apartado 2.1 de la UD5)."
  [1.4]="Dentro de location @app: proxy_set_header X-Forwarded-For y la variable que añade la IP del cliente."
  [1.5]="Dentro de location @app: proxy_set_header X-Forwarded-Proto y la variable con el esquema (http o https)."
  [2.1]="if p is None: y dentro, abort(…) con el código que toca."
  [2.2]="methods=[…] con los dos métodos."
  [2.3]="if not nombre: errores.append(\"…\"). Para la hora: si es None o no está entre 9 y 21."
  [2.4]="Tres casos con if / elif / elif. Para el último: recorre RESERVAS y mira si alguna tiene la misma pista y la misma hora."
  [2.5]="if errores: return render_template(…), 422. Si no, RESERVAS.append({…}) y hecha con la pista de verdad."
  [3.1]="Busca |safe en templates/reservar.html."
  [3.2]="Busca |safe en templates/admin.html."
  [4.2]="Igual que en /socios del Club de Lectura: si \"usuario\" no está en session, redirect(url_for(\"entrar\"))."
  [4.3]="./bateria.sh llave te da una llave nueva: cópiala en SECRET_KEY= (sin espacios alrededor del =)."
  [4.4]="app.secret_key = os.environ[\"SECRET_KEY\"]"
  [5.2]="En config/polideportivo.env, FLASK_DEBUG a 0."
  [5.3]="workers = 2 × núcleos + 1, con los núcleos del servidor del enunciado."
  [5.4]="errorlog = \"/var/log/lab/gunicorn-errores.log\""
  [6.1]="return jsonify(PISTAS)"
  [6.2]="if request.args.get(\"libres\") == \"1\": y una lista solo con las que tienen disponible a True."
  [6.3]="Como el 2.1, pero en vez de abort: return jsonify({\"error\": \"…\"}), 404. Si existe: return jsonify(p)."
)

bloque() {  # bloque N "título"
    cierre_bloque
    ACTUAL=$1
    if [ -z "$SOLO" ] || [ "$SOLO" = "$1" ]; then echo; echo "${N}Bloque $1 · $2${X}"; fi
}
cierre_bloque() {
    if [ -n "${ACTUAL:-}" ] && { [ -z "$SOLO" ] || [ "$SOLO" = "$ACTUAL" ]; }; then
        echo "  ${G}— bloque $ACTUAL: $bok de $btot${X}"
    fi
    bok=0; btot=0
}
check() {  # check ID TIPO "nombre" funcion
    local id=$1 tipo=$2 nombre=$3; shift 3
    [ -n "$SOLO" ] && [ "$SOLO" != "$ACTUAL" ] && return 0
    total=$((total+1)); btot=$((btot+1)); MSG=""; TRAMPA=""
    if "$@"; then
        ok=$((ok+1)); bok=$((bok+1)); printf '  %s✔%s %-4s %s %s\n' "$V" "$X" "$id" "$tipo" "$nombre"
    else
        printf '  %s✘%s %-4s %s %s\n' "$R" "$X" "$id" "$tipo" "$nombre"
        [ -n "$MSG" ] && printf '         %s\n' "$MSG"
        [ -n "$TRAMPA" ] && printf '         %s⚠️  Error típico: %s%s\n' "$A" "$TRAMPA" "$X"
        if [ -n "${EMPEZAR[$id]:-}" ] && { [ -n "$SOLO" ] || [ "$primero_dado" = 0 ]; }; then
            printf '         %s💡 Para empezar: %s%s\n' "$A" "${EMPEZAR[$id]}" "$X"
            [ -z "$SOLO" ] && primero_dado=1
        fi
    fi
}
pred() {  # pred ID esperado "por qué"
    local id=$1 esperado=$2 porque=$3 resp norm
    resp=$(sed -n "s/^${id//./\\.}[[:space:]]*=[[:space:]]*//p" predicciones.txt 2>/dev/null | head -1)
    norm=$(tr '[:upper:]' '[:lower:]' <<<"$resp" | tr -d " '\"\r" | sed 's/^sí$/si/; s/^Sí$/si/')
    [ "$esperado" = sí ] && esperado=si
    if [ -z "$norm" ]; then MSG="Sin contestar: escribe tu respuesta en predicciones.txt, después de «$id =»."; return 1; fi
    if [ "$norm" = "$esperado" ]; then
        [ -n "$SOLO" ] && MSG_OK="$porque"
        return 0
    fi
    MSG="Has puesto «$resp»: no es eso."
    [ -n "$SOLO" ] && MSG="$MSG $porque"
    return 1
}
check_pred() {  # check_pred ID "pregunta" esperado "por qué"
    local id=$1 nombre=$2 esperado=$3 porque=$4
    MSG_OK=""
    check "$id" "🔮" "$nombre" pred "$id" "$esperado" "$porque"
    [ -n "$MSG_OK" ] && printf '         %s%s%s\n' "$G" "$MSG_OK" "$X"
    return 0
}

# ═════════════ Bloque 1 · Nginx le pasa la petición a Gunicorn ═════════════
PORTADA_H=$(cabeceras web "$URL/")
por_python() { grep -qi '^x-cocinero: gunicorn' <<<"$PORTADA_H"; }
b1_ok()   { docker compose exec -T nginx nginx -t >/dev/null 2>&1; }
b1_301()  { local r; r=$(web -o /dev/null -w '%{http_code} %{redirect_url}' http://polideportivo.iaw.local/x); MSG="Ha salido: $r"; [[ $r == "301 https://polideportivo.iaw.local/x" ]]; }
b1_txt()  { web "$URL/hola.txt" | grep -q 'estático' && ! cabeceras web "$URL/hola.txt" | grep -qi '^x-cocinero'; }
b1_app() {
    local c; c=$(head -1 <<<"$PORTADA_H" | awk '{print $2}')
    MSG="La portada ha dado el código $c."
    if por_python && web "$URL/" | grep -q 'Pistas (6)'; then return 0; fi
    case "$c" in
        404) TRAMPA="404: Nginx busca un fichero que no existe. No sabe que hay cocina (¿try_files … @app?)." ;;
        502) TRAMPA="502: el camarero llega a la cocina y no abre nadie. ¿proxy_pass apunta a http://app:8000?" ;;
        500) TRAMPA="500 de Nginx: try_files salta a @app, pero ¿existe el bloque «location @app»? Mira logs/polideportivo_error.log." ;;
    esac
    return 1
}
QUIEN=$(web "$URL/quien")
b1_xff() {
    por_python || { MSG="Primero tiene que ir el 1.3."; return 1; }
    local ip; ip=$(docker compose exec -T cliente hostname -i 2>/dev/null | awk '{print $1}')
    MSG="La app dice: «$(tr -d '\n' <<<"$QUIEN")» (el cliente es $ip)."
    grep -q "IP: $ip " <<<"$QUIEN"
}
b1_proto() {
    por_python || { MSG="Primero tiene que ir el 1.3."; return 1; }
    MSG="La app dice: «$(tr -d '\n' <<<"$QUIEN")»."
    grep -q 'entrado por: https' <<<"$QUIEN"
}
bloque 1 "Nginx le pasa la petición a Gunicorn"
check 1.0 "👀" "polideportivo.conf es válido (nginx -t)" b1_ok
check 1.1 "👀" "HTTP redirige a HTTPS (301)" b1_301
check 1.2 "👀" "hola.txt lo sirve Nginx, sin pasar por Python" b1_txt
check 1.3 "✍️" "La portada la cocina Python (X-Cocinero: gunicorn)" b1_app
check 1.4 "✍️" "La app ve la IP de verdad del cliente (X-Forwarded-For)" b1_xff
check 1.5 "✍️" "La app sabe que entraste por https (X-Forwarded-Proto)" b1_proto
check_pred 1.a "Sin @app en try_files, pides la portada" 404 "Nginx solo busca un fichero llamado así en root; como no existe, 404. A la app ni la llama."
check_pred 1.b "proxy_pass http://app:8001; (puerto mal)" 502 "502 Bad Gateway: en el 8001 no escucha nadie. En el log de Nginx: connect() failed (111: Connection refused)."
check_pred 1.c "Envías el formulario y la ruta solo acepta GET" 405 "405 Method Not Allowed: la ruta existe, pero no con ese método. Lo contesta Flask (la app), no Nginx."
check_pred 1.d "app.py con un error de sintaxis, y reinicias la app" 502 "La app no llega a arrancar: no hay nadie escuchando en el 8000, y Nginx da 502. El error de Python está en docker compose logs app."

# ═════════════ Bloque 2 · Flask: rutas, métodos y validación ═════════════
reservar() { app -X POST --data-urlencode "nombre=$1" --data-urlencode "pista=$2" --data-urlencode "hora=$3" --data-urlencode "comentario=$4" -w '\nCODIGO=%{http_code}' "$APP/reservar"; }
cod_de()   { sed -n 's/^CODIGO=//p' <<<"$1"; }
acepta_post() { [ "$(codigo app -X POST -d 'nombre=x&pista=3&hora=9' "$APP/reservar")" != 405 ]; }
b2_404() {
    local c2 c99; c2=$(codigo app "$APP/pista/2"); c99=$(codigo app "$APP/pista/99")
    MSG="/pista/2 da $c2 y /pista/99 da $c99."
    [ "$c99" = 200 ] && TRAMPA="la pista no existe y sale un 200 con la página vacía: hay que cortar antes con abort."
    [ "$c2" = 200 ] && app "$APP/pista/2" | ayuda texto pista | grep -qx 'Pádel 2' && [ "$c99" = 404 ]
}
b2_post() { acepta_post || { MSG="Con POST da 405."; TRAMPA="la ruta solo acepta GET: falta POST en methods (y reiniciar la app)."; return 1; }; }
b2_valida() {
    acepta_post || { MSG="Necesita el 2.2 (que la ruta acepte POST)."; return 1; }
    reservar "" 3 10 "" | ayuda errores | grep -qx 'Escribe tu nombre.' || { MSG="Con el nombre vacío no sale «Escribe tu nombre.»."; return 1; }
    local h
    for h in 8 22 abc 2.5; do
        reservar Ana 3 "$h" "" | ayuda errores | grep -qx 'La hora tiene que ser un número entero de 9 a 21.' \
            || { MSG="Con la hora «$h» no sale el aviso de la hora."; return 1; }
    done
}
b2_pista() {
    acepta_post || { MSG="Necesita el 2.2."; return 1; }
    reservar Ana 99 10 "" | ayuda errores | grep -qx 'Esa pista no existe.' || { MSG="Con la pista 99 no sale «Esa pista no existe.»."; return 1; }
    reservar Ana 4 10 "" | ayuda errores | grep -qx 'Esa pista está cerrada.' || { MSG="Con la pista 4 (en obras) no sale «Esa pista está cerrada.»."; return 1; }
    reservar Ana 1 18 "" | ayuda errores | grep -qx 'Esa pista ya está reservada a esa hora.' \
        || { MSG="La pista 1 a las 18 ya está reservada (mira RESERVAS) y no sale el aviso."; return 1; }
}
b2_hecha() {
    acepta_post || { MSG="Necesita el 2.2."; return 1; }
    local r c t
    r=$(reservar Ana 99 30 ""); c=$(cod_de "$r")
    MSG="Con datos malos ha dado el código $c."
    grep -q 'id="reserva"' <<<"$r" && { TRAMPA="con errores sigue saliendo «Reserva hecha»: la reserva solo se hace si no hay errores."; return 1; }
    [ "$c" = 422 ] || return 1
    r=$(reservar Ana 2 19 ""); c=$(cod_de "$r"); t=$(ayuda texto reserva <<<"$r")
    MSG="Ana reserva la Pádel 2 a las 19: código $c · «$t»."
    [ "$c" = 200 ] && [ "$t" = "Reserva hecha, Ana: Pádel 2 a las 19:00." ]
    # Que se guarde en RESERVAS no se puede comprobar desde fuera: con varios workers, cada uno tiene su lista.
}
bloque 2 "Flask: rutas, métodos y validación"
check 2.1 "✍️" "/pista/2 enseña la Pádel 2 · /pista/99 da 404" b2_404
check 2.2 "✍️" "El formulario se puede enviar (POST, no 405)" b2_post
check 2.3 "✍️" "Nombre vacío u hora 8, 22, «abc» o 2.5: su aviso" b2_valida
check 2.4 "✍️" "Pista que no existe, cerrada u ocupada: su aviso" b2_pista
check 2.5 "✍️" "Con errores, 422 · una reserva buena sale bien" b2_hecha

# ═════════════ Bloque 3 · Plantillas sin XSS ═════════════
admin_con_login() { docker compose exec -T nginx sh -c "rm -f /tmp/j; curl -s -c /tmp/j -d 'usuario=conserje&clave=pista2026' $APP/entrar -o /dev/null; curl -s -b /tmp/j $APP/admin" 2>/dev/null; }
b3_reserva() {
    acepta_post || { MSG="Necesita el 2.2."; return 1; }
    local r; r=$(reservar "<script>alert(1)</script>" 3 12 "")
    if grep -q '<script>alert(1)' <<<"$r"; then MSG="El nombre <script>… sale tal cual en la reserva."; TRAMPA="XSS: |safe desactiva el escape de {{ }}."; return 1; fi
    grep -q '&lt;script&gt;' <<<"$r" || { MSG="No veo el nombre escapado (&lt;script&gt;) en la reserva (¿sale «Reserva hecha»?)."; return 1; }
}
b3_admin() {
    local r; r=$(admin_con_login)
    grep -q 'Marta' <<<"$r" || { MSG="No veo la reserva de Marta en /admin (¿entra el conserje?)."; return 1; }
    if grep -q '<b>¡Gracias!</b>' <<<"$r"; then MSG="En /admin, el comentario de Marta sale en negrita: el navegador ejecuta su HTML."; TRAMPA="XSS en el comentario: otro |safe."; return 1; fi
    grep -q '&lt;b&gt;¡Gracias' <<<"$r"
}
bloque 3 "Plantillas sin XSS"
check 3.1 "✍️" "La reserva enseña el nombre escapado" b3_reserva
check 3.2 "✍️" "/admin enseña los comentarios escapados" b3_admin

# ═════════════ Bloque 4 · Sesiones y SECRET_KEY ═════════════
b4_login() {
    local h; h=$(cabeceras app -d 'usuario=conserje&clave=pista2026' "$APP/entrar")
    grep -q '^HTTP/[0-9.]* 302' <<<"$h" && grep -qi '^set-cookie: session=' <<<"$h"
}
b4_puerta() {
    local c l; c=$(codigo app "$APP/admin"); l=$(cabeceras app "$APP/admin" | sed -n 's/^[Ll]ocation: //p')
    MSG="/admin sin sesión da $c${l:+ y lleva a $l}."
    [ "$c" = 200 ] && TRAMPA="entra cualquiera: el login no protege nada si la página no comprueba la sesión."
    { [ "$c" = 302 ] && grep -q '/entrar$' <<<"$l"; } || [ "$c" = 401 ]
}
b4_llave() {
    local k; k=$(entorno SECRET_KEY)
    MSG="La app tiene SECRET_KEY de ${#k} caracteres$([ "$k" = cambiame ] && echo ' («cambiame», la de fábrica)')."
    [ "${#k}" -ge 32 ] && [ "$k" != cambiame ]
}
b4_entorno() {
    [ "$(codigo app "$APP/admin")" = 200 ] && { MSG="Necesita el 4.2 (si /admin está abierta, no hay nada que falsificar)."; return 1; }
    local galleta r; galleta=$(ayuda forjar polideportivo)
    r=$(app -b "session=$galleta" "$APP/admin")
    if grep -q 'Hola, conserje' <<<"$r"; then
        MSG="Una pulsera fabricada con la llave «polideportivo» entra en /admin."
        TRAMPA="la llave está en app.py: quien vea el código (en Git) puede fabricar sesiones de cualquiera."; return 1
    fi
    admin_con_login | grep -q 'Hola, conserje' || { MSG="Ahora el conserje de verdad tampoco entra: ¿lee app.secret_key la variable SECRET_KEY?"; return 1; }
}
bloque 4 "Sesiones y SECRET_KEY"
check 4.1 "👀" "El conserje entra (302 y cookie de sesión)" b4_login
check 4.2 "✍️" "/admin sin sesión: a la página de entrar" b4_puerta
check 4.3 "✍️" "SECRET_KEY propia (32 caracteres o más, no «cambiame»)" b4_llave
check 4.4 "✍️" "La llave sale del entorno: una pulsera falsa no entra" b4_entorno
check_pred 4.a "¿Se puede leer lo que hay en la cookie de sesión sin la llave?" sí "Los datos van en base64, que no es cifrado: echo … | base64 -d y se leen. Por eso no se guardan secretos en la sesión."
check_pred 4.b "¿Se puede cambiar «conserje» por otro nombre sin la llave?" no "La tercera parte de la cookie es el sello, hecho con la SECRET_KEY: si cambias los datos, no cuadra y Flask la rechaza."
check_pred 4.c "Cambias la SECRET_KEY y reinicias: ¿la sesión que tenías abierta sigue valiendo?" no "Su sello se hizo con la llave antigua: ya no cuadra. Todos tienen que volver a entrar (por eso se cambia si se filtra)."
check_pred 4.d "Cambias app.py y NO reinicias: ¿se nota el cambio?" no "Gunicorn cargó app.py al arrancar y sigue con la versión que tiene en memoria. Hay que reiniciar la app."

# ═════════════ Bloque 5 · Python en producción ═════════════
b5_timeout() { local t; t=$(gconf timeout); MSG="timeout = «$t»."; [ "$t" = 30 ]; }
b5_debug() {
    local d c r; d=$(entorno FLASK_DEBUG); c=$(codigo app "$APP/error"); r=$(app "$APP/error")
    MSG="FLASK_DEBUG vale «$d» en la app; /error da $c."
    if grep -qiE 'traceback|ZeroDivisionError|werkzeug' <<<"$r"; then TRAMPA="el error enseña el código y la consola del depurador, que ejecuta Python en el servidor."; return 1; fi
    [ "$c" = 500 ]
}
b5_workers() {
    local w n; w=$(gconf workers); n=$(en_app 'ps -o args= -C gunicorn' | grep -c gunicorn)
    MSG="workers = «$w» · hay $n procesos de Gunicorn (el jefe y $((n-1)) workers)."
    case "$w" in
        5) TRAMPA="5 es para 2 CPU (el Club de Lectura). Este servidor tiene 4." ;;
        1) TRAMPA="1 worker: si una petición tarda, las demás esperan." ;;
    esac
    [ "$w" = "$(( $(en_app nproc) * 2 + 1 ))" ] && [ "$w" != 9 ] && TRAMPA="has usado nproc: cuenta las CPU de TU ordenador, no las del servidor de producción."
    [ "$w" = 9 ] && [ "$n" = 10 ]
}
b5_log() {
    local e; e=$(gconf errorlog); MSG="errorlog = «$e»."
    [ "$e" = /var/log/lab/gunicorn-errores.log ] || return 1
    en_app ': > /var/log/lab/gunicorn-errores.log'
    app "$APP/error" >/dev/null; sleep 0.5
    if ! en_app 'grep -q ZeroDivisionError /var/log/lab/gunicorn-errores.log'; then
        MSG="El error de /error no ha llegado a logs/gunicorn-errores.log."
        [ "$(entorno FLASK_DEBUG)" = 1 ] && TRAMPA="con FLASK_DEBUG=1, el depurador se queda el error y no llega al log: primero el 5.2."
        return 1
    fi
}
bloque 5 "Python en producción"
check 5.1 "👀" "timeout = 30" b5_timeout
check 5.2 "✍️" "Un error NO enseña el código (500 sin traza)" b5_debug
check 5.3 "✍️" "Los workers calculados para 4 CPU (y arrancados)" b5_workers
check 5.4 "✍️" "…y el error queda en logs/gunicorn-errores.log" b5_log

# ═════════════ Bloque 6 · Integrador: la API de las pistas ═════════════
tipo() { cabeceras app "$1" | sed -n 's/^[Cc]ontent-[Tt]ype: //p'; }
b6_lista() {
    local t r; t=$(tipo "$APP/api/pistas"); r=$(app "$APP/api/pistas" | ayuda json)
    MSG="Content-Type «$t» · ha salido: $r (esperaba LISTA 6 4)."
    grep -q '^application/json' <<<"$t" && [ "$r" = "LISTA 6 4" ]
}
b6_libres() {
    local r; r=$(app "$APP/api/pistas?libres=1" | ayuda json)
    MSG="Con ?libres=1 ha salido: $r (esperaba LISTA 4 4)."
    [ "$r" = "LISTA 6 4" ] && TRAMPA="sale la lista entera: ¿comparas request.args.get(\"libres\") con el texto \"1\"?"
    [ "$r" = "LISTA 4 4" ]
}
b6_una() {
    local r c t; r=$(app "$APP/api/pistas/2" | ayuda json)
    MSG="/api/pistas/2 ha dado: $r."
    [ "$r" = "OBJETO Pádel 2" ] || return 1
    c=$(codigo app "$APP/api/pistas/99"); t=$(tipo "$APP/api/pistas/99"); r=$(app "$APP/api/pistas/99" | ayuda json)
    MSG="/api/pistas/99 ha dado $c, «$t» y $r."
    grep -q 'text/html' <<<"$t" && TRAMPA="el 404 sale en HTML (abort): un programa espera JSON también en los errores."
    [ "$c" = 404 ] && grep -q '^application/json' <<<"$t" && [[ $r == OBJETO-ERROR* ]]
}
bloque 6 "Integrador: la API de las pistas"
check 6.1 "✍️" "/api/pistas: JSON con las 6 pistas" b6_lista
check 6.2 "✍️" "?libres=1: solo las 4 disponibles" b6_libres
check 6.3 "✍️" "/api/pistas/2 en JSON · /api/pistas/99: 404 en JSON" b6_una
cierre_bloque

echo
if [ -n "$SOLO" ]; then
    echo "${N}Bloque $SOLO: $ok de $total${X}"
else
    echo "${N}Resultado: $ok de $total${X}  ${G}(los 👀 son ejemplos ya resueltos)${X}"
    [ "$ok" -lt "$total" ] && echo "${G}Para ver un bloque con más detalle: ./bateria.sh comprobar N · Pistas: «🆘 ¿Atascado?» en la página de la batería.${X}"
fi
[ "$ok" -eq "$total" ]

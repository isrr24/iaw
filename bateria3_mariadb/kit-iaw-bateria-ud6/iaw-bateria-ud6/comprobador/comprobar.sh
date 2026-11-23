#!/usr/bin/env bash
# Comprobador de la batería UD6 (el inventario del aula). Se lanza con: ./bateria.sh comprobar [N]
# La web y la API se comprueban con curl DESDE «cliente», como un usuario, pasando por Nginx. La base de datos, como root
# DENTRO de su servidor. Las copias y Git, desde «admin» (el ordenador del administrador).
# No da la solución: dice qué caso falla, qué ha salido y, si es una trampa conocida, cuál es.
set -u   # sin pipefail: «… | grep -q» corta la tubería al encontrar y daría falsos fallos
cd "$(dirname "$0")/.."
SOLO=${1:-}
URL=https://inventario.iaw.local
ROOTPW=raiz-de-la-bateria

V=$'\e[32m'; R=$'\e[31m'; A=$'\e[33m'; G=$'\e[90m'; N=$'\e[1m'; X=$'\e[0m'

# ── Acceso a los contenedores ────────────────────────────────────────────────
web()    { docker compose exec -T cliente curl -sk --max-time 12 "$@" 2>/dev/null; }     # como un usuario, por Nginx
codigo() { web -o /dev/null -w '%{http_code}' "$@"; }
sql()    { docker compose exec -T db mariadb -uroot -p"$ROOTPW" -N -B -e "$1" 2>/dev/null; }   # como root, en localhost
admin()  { docker compose exec -T admin sh -c "$1" 2>/dev/null; }
envvar() { sed -n "s/^$1=//p" servidor/inventario.env 2>/dev/null | tail -1 | tr -d '\r'; }
error_php() { sed -n 's/.*\(SQLSTATE\[[^]]*\] *\[[0-9]*\][^<]*\).*/\1/p; s/.*\(PHP \(Fatal\|Parse\) error\|Fatal error\|Parse error\)\(.*\)/\1\3/p' | sed 's/<[^>]*>//g' | head -1 | cut -c1-170; }
error_api() { grep -E 'pymysql\.err|KeyError|Error:' logs/gunicorn-errores.log 2>/dev/null | tail -1 | sed 's/^.*\(pymysql\.err\.\|KeyError\)/\1/' | cut -c1-170; }

# ── 0 · Que esté arrancado, y aplicar tus cambios (igual que ./bateria.sh recargar) ──
if ! docker compose ps --status running -q cliente 2>/dev/null | grep -q .; then
    echo "${R}✘ La batería no está arrancada.${X} Primero: ${N}./bateria.sh arrancar${X}"; exit 1
fi
if ! salida=$(docker compose exec -T nginx nginx -t 2>&1); then
    echo "${R}✘ inventario.conf tiene un error y Nginx no lo acepta (nginx -t):${X}"
    grep -E 'emerg|error' <<<"$salida" | sed 's/^/    /'
    echo "  ${A}💡 Ese fichero ya venía bien: ¿lo has cambiado? Con Git (bloque 5) lo ves en git diff y lo arreglas con git restore.${X}"
    exit 1
fi
docker compose exec -T nginx nginx -s reload >/dev/null 2>&1
DESDE=$(date +%s)
docker compose restart app >/dev/null 2>&1
arranca=0
for _ in $(seq 1 20); do [ "$(codigo "$URL/api/salud")" = 200 ] && { arranca=1; break; }; sleep 0.5; done
if [ "$arranca" = 0 ]; then
    echo "${R}✘ La API no arranca después de reiniciarla.${X} Esto dice Python (docker compose logs app):"
    docker compose logs --no-log-prefix --since "$DESDE" app 2>&1 | grep -vE '\[INFO\]|<frozen|^Traceback|\[ERROR\]' | tail -n 6 | sed 's/^/    /'
    echo "  ${A}💡 La última línea dice qué pasa y la de «File …, line NN», dónde. Suele ser un error de sangría o de sintaxis en app.py.${X}"
    exit 1
fi
echo "${G}→ nginx -t ✔ · Nginx recargado · API reiniciada (lo mismo que ./bateria.sh recargar)${X}"

# ── Resultados ────────────────────────────────────────────────────────────────
ok=0; total=0; bok=0; btot=0; primero_dado=0
MSG=""; TRAMPA=""
declare -A EMPEZAR=(
  [1.2]="Copia el ejemplo 👀 de inv_lector que hay arriba en sql/bloque1.sql: cambia el nombre, la contraseña y la lista de permisos (apartado 3 de la UD6). Después: ./bateria.sh sql"
  [1.3]="CREATE TABLE IF NOT EXISTS incidencias ( … ); con las cuatro columnas separadas por comas. Mira cómo está hecha la tabla equipos en sql/01-inventario.sql."
  [1.4]="DROP USER IF EXISTS y el root que entra desde cualquier sitio: 'root'@'%'."
  [2.1]="DB_USER=inv_web y DB_PASS= la contraseña que pusiste en el 1.2, sin espacios ni comillas."
  [2.2]="Dentro de conectar(): \$cfg = leer_env('/etc/inventario/inventario.env'); y después usa \$cfg['DB_HOST'], \$cfg['DB_USER']… donde ahora pone 'db', 'root'…"
  [2.3]="user=os.environ[\"DB_USER\"], password=os.environ[\"DB_PASS\"], igual que host y database."
  [2.4]="Busca 'raiz-de-la-bateria' y tu contraseña en web/ y en app/: no pueden aparecer, ni en un comentario."
  [3.1]="Copia la forma de equipo.php: \$st = \$pdo->prepare('… WHERE aula = ? …'); \$st->execute([\$aula]); \$resultado = \$st->fetchAll();"
  [3.2]="Copia la forma de equipo() en app.py: cur.execute(\"… WHERE aula = %s …\", (aula,)). La coma de (aula,) hace falta."
  [4.1]="Rellena los pasos de servidor/copia.sh en orden: . /srv/servidor/inventario.env, después FECHA=\$(date …) y el mysqldump. Pruébalo con ./bateria.sh copia"
  [4.3]="find /copias -name 'inventario-*.sql' -mtime +7 -delete"
  [4.4]="El script no lleva contraseñas: la saca de \$DB_PASS, que viene de inventario.env (el punto del paso 1)."
  [5.1]="./bateria.sh admin y, dentro (ya estás en /srv/servidor): git init, git config user.name …, git config user.email …, y antes del git add… el 5.2."
  [5.2]="Un fichero servidor/.gitignore con dos líneas: inventario.env y *.key. Créalo ANTES del primer git add."
  [5.3]="Cambia algo en nginx/inventario.conf, git commit -am \"…\", y después git revert HEAD (te abre el editor: guarda y sal)."
  [6.1]="if request.method == \"GET\": con conectar(), SELECT … FROM incidencias ORDER BY id DESC, y return jsonify(cur.fetchall())."
  [6.2]="datos = request.get_json(silent=True) or {}; INSERT INTO incidencias (equipo_id, descripcion) VALUES (%s, %s) con los datos en una tupla, c.commit() y return jsonify({\"id\": cur.lastrowid}), 201"
  [6.3]="Antes del INSERT: si la descripción está vacía, 422. Después, SELECT id FROM equipos WHERE id = %s: si fetchone() da None, 422."
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
toca() { [ -z "$SOLO" ] || [ "$SOLO" = "$1" ]; }
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
    resp=$(sed -n "s/^${id//./\\.}[[:space:]]*=[[:space:]]*//p" predicciones.txt 2>/dev/null | head -1 | tr -d '\r')
    norm=$(tr '[:upper:]' '[:lower:]' <<<"$resp" | tr -d " '\"" | sed 's/^sí$/si/; s/^Sí$/si/')
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
permisos() {  # permisos usuario → «INSERT,SELECT,UPDATE» en inventario (vacío si no tiene)
    sql "SELECT GROUP_CONCAT(PRIVILEGE_TYPE ORDER BY PRIVILEGE_TYPE) FROM information_schema.SCHEMA_PRIVILEGES
         WHERE GRANTEE = '''$1''@''%''' AND TABLE_SCHEMA='inventario'"
}
solo_en_inventario() {  # ni permisos globales ni en otras bases
    [ "$(sql "SELECT COUNT(*) FROM information_schema.USER_PRIVILEGES WHERE GRANTEE = '''$1''@''%''' AND PRIVILEGE_TYPE<>'USAGE'")" = 0 ] &&
    [ "$(sql "SELECT COUNT(*) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = '''$1''@''%''' AND TABLE_SCHEMA<>'inventario'")" = 0 ]
}

# ═════════════ Bloque 1 · Usuarios y permisos ═════════════
b1_base()   { [ "$(sql 'SELECT COUNT(*) FROM inventario.equipos')" -ge 8 ] 2>/dev/null; }
b1_lector() { [ "$(permisos inv_lector)" = SELECT ] && solo_en_inventario inv_lector; }
b1_web() {
    local hosts p
    hosts=$(sql "SELECT GROUP_CONCAT(Host) FROM mysql.user WHERE User='inv_web'")
    if [ -z "$hosts" ] || [ "$hosts" = NULL ]; then MSG="No existe el usuario inv_web. ¿Has aplicado el fichero? ./bateria.sh sql"; return 1; fi
    if ! grep -qw '%' <<<"$hosts"; then
        MSG="inv_web existe, pero desde: $hosts."
        TRAMPA="la web y la API están en OTROS ordenadores (php, app): con 'localhost' no pueden entrar. Tiene que ser 'inv_web'@'%'."
        return 1
    fi
    p=$(permisos inv_web)
    MSG="inv_web tiene en inventario: ${p:-ningún permiso}."
    if ! solo_en_inventario inv_web; then
        MSG="inv_web tiene permisos fuera de la base inventario."
        TRAMPA="ON *.* le da permiso en TODAS las bases del servidor. Tiene que ser ON inventario.*"
        return 1
    fi
    case ",$p," in
        *,DROP,*|*,DELETE,*|*,ALTER,*|*,CREATE,*) TRAMPA="GRANT ALL o de más: si alguien cuela una orden por la web, podría borrar. Solo SELECT, INSERT y UPDATE." ;;
    esac
    [ "$p" = "INSERT,SELECT,UPDATE" ]
}
b1_tabla() {
    local col
    if [ "$(sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='inventario' AND TABLE_NAME='incidencias'")" != 1 ]; then
        MSG="No existe la tabla incidencias en la base inventario. ¿Has aplicado el fichero? ./bateria.sh sql"; return 1
    fi
    col() { sql "SELECT CONCAT_WS(' ', DATA_TYPE, IFNULL(CHARACTER_MAXIMUM_LENGTH,''), IS_NULLABLE, COLUMN_KEY, EXTRA, IFNULL(COLUMN_DEFAULT,''))
                 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='inventario' AND TABLE_NAME='incidencias' AND COLUMN_NAME='$1'"; }
    grep -q '^int .*NO PRI auto_increment' <<<"$(col id)"           || { MSG="La columna id: «$(col id)». Tiene que ser INT AUTO_INCREMENT PRIMARY KEY."; return 1; }
    grep -q '^int .*NO' <<<"$(col equipo_id)"                        || { MSG="La columna equipo_id: «$(col equipo_id)». Tiene que ser INT NOT NULL."; return 1; }
    grep -q '^varchar 200 NO' <<<"$(col descripcion)"                || { MSG="La columna descripcion: «$(col descripcion)». Tiene que ser VARCHAR(200) NOT NULL."; return 1; }
    grep -qi '^datetime .*current_timestamp' <<<"$(col fecha)"       || { MSG="La columna fecha: «$(col fecha)». Tiene que ser DATETIME con DEFAULT CURRENT_TIMESTAMP."; return 1; }
}
b1_root() {
    local h; h=$(sql "SELECT GROUP_CONCAT(Host) FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1')")
    MSG="root sigue entrando desde: $h"
    [ -z "$h" ] || [ "$h" = NULL ]
}

bloque 1 "Usuarios y permisos"
check 1.0 "👀" "MariaDB responde: la base inventario, con sus 8 equipos" b1_base
check 1.1 "👀" "inv_lector solo puede leer (SELECT), y solo en inventario" b1_lector
check 1.2 "✍️" "inv_web: SELECT, INSERT y UPDATE en inventario.*, y nada más" b1_web
check 1.3 "✍️" "La tabla incidencias, con sus cuatro columnas" b1_tabla
check 1.4 "✍️" "root solo entra desde el propio servidor (sin root@'%')" b1_root
check_pred 1.a "inv_web intenta DROP TABLE equipos. ¿Qué error da?" 1142 "1142: el usuario existe y ha entrado, pero esa ORDEN no la tiene permitida (DROP command denied)."
check_pred 1.b "inventario.env con DB_PASS vacío. ¿Qué error da la web?" 1045 "1045 Access denied … (using password: NO): no ha mandado contraseña. Con una contraseña mal, también 1045, pero «using password: YES»."
check_pred 1.c "inventario.env con DB_NAME=almacen. ¿Qué error da?" 1044 "1044: el usuario y la contraseña están bien, pero no tiene permiso en ESA base."
check_pred 1.d "inventario.env con DB_HOST=bd (mal escrito). ¿Qué error da?" 2002 "2002: ni siquiera llega al servidor (getaddrinfo for bd failed: ese nombre no existe en la red)."

# ═════════════ Bloque 2 · La web y la API, conectadas con inventario.env ═════════════
b2_rutas() { web "$URL/salud.php" | grep -q 'PHP-FPM responde' && web "$URL/api/salud" | grep -q '"ok": *true'; }
b2_env() {
    local u p r
    u=$(envvar DB_USER); p=$(envvar DB_PASS)
    if grep -qE '^DB_(USER|PASS) +=|^DB_(USER|PASS)= ' servidor/inventario.env; then
        MSG="Hay espacios alrededor del = en inventario.env."; TRAMPA="CLAVE=valor, todo junto: el espacio pasa a formar parte del nombre o de la contraseña."; return 1
    fi
    [ -n "$u" ] || { MSG="DB_USER está vacío en servidor/inventario.env."; return 1; }
    [ "$u" = inv_web ] || { MSG="DB_USER=$u."; TRAMPA="la web y la API entran con SU usuario, el del 1.2 (inv_web), nunca con root."; return 1; }
    [ -n "$p" ] || { MSG="DB_PASS está vacío en servidor/inventario.env."; return 1; }
    r=$(docker compose exec -T admin mariadb -h db -u "$u" -p"$p" inventario -N -e 'SELECT 1' 2>&1)
    MSG="Con esos datos, MariaDB dice: $(tr -d '\n' <<<"$r" | cut -c1-150)"
    [ "$r" = 1 ]
}
EQUIPOS_HTML=$(web "$URL/equipos.php")
b2_php() {
    local yo n; yo=$(sed -n 's/.*como: \([^<]*\).*/\1/p' <<<"$EQUIPOS_HTML")
    n=$(grep -c '<li>' <<<"$EQUIPOS_HTML")
    if [ -z "$yo" ]; then
        MSG="equipos.php no carga. Dice: $(error_php <<<"$EQUIPOS_HTML")"
        grep -q '1045.*root' <<<"$EQUIPOS_HTML" && TRAMPA="la web sigue entrando como root, y root ya no entra desde fuera (1.4). Lo bueno es que no entre como root: arregla db.php."
        grep -q 'using password: NO' <<<"$EQUIPOS_HTML" && TRAMPA="no manda contraseña: ¿\$cfg['DB_PASS'] escrito igual que en inventario.env? ¿o DB_PASS vacío?"
        return 1
    fi
    MSG="equipos.php enseña $n equipos, conectada como: $yo."
    [[ $yo == inv_web@* ]] || { TRAMPA="db.php sigue entrando con el usuario escrito a mano: tiene que usar \$cfg['DB_USER'] y \$cfg['DB_PASS']."; return 1; }
    [ "$n" -ge 8 ]
}
API_EQUIPOS=$(web "$URL/api/equipos")
b2_api() {
    local yo; yo=$(sed -n 's/.*"conectado_como": *"\([^"]*\)".*/\1/p' <<<"$API_EQUIPOS")
    if [ -z "$yo" ]; then
        MSG="/api/equipos no contesta bien ($(codigo "$URL/api/equipos")). En logs/gunicorn-errores.log: $(error_api)"
        grep -q "using password: NO" logs/gunicorn-errores.log 2>/dev/null && TRAMPA="(using password: NO): conectar() no pasa password=, o DB_PASS está vacío."
        grep -q "Access denied for user ''@\|Access denied for user 'root'" logs/gunicorn-errores.log 2>/dev/null && TRAMPA="conectar() no dice con qué usuario entra (user=…)."
        return 1
    fi
    MSG="La API dice que está conectada como: $yo."
    [[ $yo == inv_web@* ]] && [ "$(grep -o '"codigo"' <<<"$API_EQUIPOS" | wc -l)" -ge 8 ]
}
b2_claves() {
    local p; p=$(envvar DB_PASS)
    if grep -rqF 'raiz-de-la-bateria' web app; then MSG="La contraseña de root está escrita en: $(grep -rlF 'raiz-de-la-bateria' web app | tr '\n' ' ')"; return 1; fi
    [ -n "$p" ] || { MSG="Primero el 2.1 (DB_PASS en inventario.env)."; return 1; }
    if grep -rqF -- "$p" web app; then
        MSG="Tu contraseña de inv_web está escrita en: $(grep -rlF -- "$p" web app | tr '\n' ' ')"
        TRAMPA="también cuenta si está en un comentario: el código acaba en Git."
        return 1
    fi
}

bloque 2 "La web y la API, conectadas con inventario.env"
check 2.0 "👀" "Nginx pasa los .php a PHP-FPM y /api/ a Gunicorn" b2_rutas
check 2.1 "✍️" "inventario.env: inv_web y su contraseña entran en MariaDB" b2_env
check 2.2 "✍️" "equipos.php: los 8 equipos, conectada como inv_web" b2_php
check 2.3 "✍️" "/api/equipos: los 8 equipos, conectada como inv_web" b2_api
check 2.4 "✍️" "Ninguna contraseña escrita en web/ ni en app/" b2_claves

# ═════════════ Bloque 3 · Consultas preparadas ═════════════
ATAQUE="x' UNION SELECT usuario, clave, email, 'x' FROM profesorado -- -"
fuga() { grep -q '@inventario.iaw.local'; }
b3_ficha() {
    local h; h=$(web "$URL/equipo.php?id=4")
    grep -q 'PRY-A12' <<<"$h" || { MSG="equipo.php?id=4 no enseña el proyector. Dice: $(error_php <<<"$h")"; grep -q SQLSTATE <<<"$h" && TRAMPA="la web no conecta con la base: es lo del bloque 2 (2.2)."; return 1; }
    [ "$(web "$URL/equipo.php" -G --data-urlencode 'id=4 OR 1=1' | grep -c '<li>')" -le 1 ]
}
b3_php() {
    local h n; h=$(web "$URL/buscar.php?aula=A12")
    grep -q SQLSTATE <<<"$h" && { MSG="buscar.php no conecta: $(error_php <<<"$h")"; TRAMPA="es lo del bloque 2 (2.2)."; return 1; }
    n=$(grep -c '<li>PC-A12\|<li>PRY-A12' <<<"$h")
    [ "$n" = 4 ] || { MSG="buscar.php?aula=A12 tiene que dar 4 equipos, y da $n. $(error_php <<<"$h")"; return 1; }
    if web "$URL/buscar.php" -G --data-urlencode "aula=$ATAQUE" | fuga; then
        MSG="Con aula=$ATAQUE salen los correos del profesorado."
        grep -q 'htmlspecialchars\|addslashes\|str_replace' web/buscar.php && TRAMPA="escapar o quitar comillas a mano no es la solución: consulta preparada (prepare + execute)."
        return 1
    fi
}
b3_api() {
    local j c; c=$(codigo "$URL/api/buscar?aula=A12"); j=$(web "$URL/api/buscar?aula=A12")
    [ "$c" = 200 ] || { MSG="/api/buscar?aula=A12 da $c. En logs/gunicorn-errores.log: $(error_api)"; grep -q "using password\|''@" logs/gunicorn-errores.log 2>/dev/null && TRAMPA="la API no conecta: es lo del 2.3."; return 1; }
    [ "$(grep -o '"codigo"' <<<"$j" | wc -l)" = 4 ] || { MSG="/api/buscar?aula=A12 tiene que dar 4 equipos: $(cut -c1-120 <<<"$j")"; return 1; }
    if web "$URL/api/buscar" -G --data-urlencode "aula=$ATAQUE" | fuga; then
        MSG="Con aula=$ATAQUE salen los correos del profesorado."
        grep -q "f\"SELECT\|f'SELECT\|% aula\|+ aula" app/app.py && TRAMPA="el dato sigue dentro del texto del SQL (f-string, % o +): va APARTE, como segundo argumento de execute."
        return 1
    fi
}

bloque 3 "Consultas preparadas"
check 3.0 "👀" "equipo.php?id=4: el proyector · ?id=4 OR 1=1 no enseña los demás" b3_ficha
check 3.1 "✍️" "buscar.php: A12 da 4 equipos · el ataque no saca al profesorado" b3_php
check 3.2 "✍️" "/api/buscar: A12 da 4 equipos · el ataque no saca al profesorado" b3_api
check_pred 3.a "¿htmlspecialchars(\$aula) evita la inyección SQL?" no "No: htmlspecialchars es para el HTML (XSS, UD4). Lo que evita la inyección es que el dato vaya APARTE del SQL."
check_pred 3.b "La web entra con inv_web (sin DELETE ni DROP). ¿Una inyección puede leer la tabla profesorado?" sí "Sí: inv_web tiene SELECT en inventario.*, y profesorado está ahí. El mínimo privilegio limita el daño, pero no evita la inyección."

# ═════════════ Bloque 4 · Copia y restauración ═════════════
COPIA=""; COPIA_SALIDA=""; VIEJA=/copias/inventario-20200101-000000.sql
if toca 4; then
    admin "touch -d '10 days ago' $VIEJA"
    antes=$(admin 'ls /copias' | sort)
    COPIA_SALIDA=$(docker compose exec -T admin timeout 20 sh /srv/servidor/copia.sh </dev/null 2>&1); COPIA_RC=$?
    COPIA=$(comm -13 <(echo "$antes") <(admin 'ls /copias' | sort) | grep '^inventario-.*\.sql$' | tail -1)
fi
b4_copia() {
    if [ "${COPIA_RC:-0}" = 124 ]; then
        MSG="copia.sh se ha quedado parado (más de 20 s)."
        TRAMPA="se queda esperando «Enter password:». ¿Cargas inventario.env (paso 1)? ¿-p\"\$DB_PASS\" pegado, sin espacio?"
        return 1
    fi
    local dice; dice=$(sed -n 's|.*Copia hecha: /copias/\(inventario-[0-9-]*\.sql\).*|\1|p' <<<"$COPIA_SALIDA")
    if [ -z "$COPIA" ] && [ -n "$dice" ] && grep -q 'mtime' servidor/copia.sh; then
        MSG="copia.sh dice que ha hecho copias/$dice, pero ya no está."
        TRAMPA="la borra el find del final: -mtime +7 = más de 7 días. Con -7 (o sin el +) borra también la de hoy."
        return 1
    fi
    if [ -z "$COPIA" ]; then
        MSG="copia.sh no ha dejado ninguna copia nueva en copias/. Ha dicho: $(tr '\n' ' ' <<<"$COPIA_SALIDA" | cut -c1-160)"
        return 1
    fi
    MSG="La copia nueva es copias/$COPIA."
    [[ $COPIA =~ ^inventario-[0-9]{8}-[0-9]{6}\.sql$ ]] || { TRAMPA="el nombre lleva la fecha y la hora: inventario-20261123-033000.sql (paso 2: FECHA=\$(date +%Y%m%d-%H%M%S))."; return 1; }
    admin "grep -q 'CREATE TABLE .equipos.' /copias/$COPIA" || { MSG="copias/$COPIA está vacía o no tiene la tabla equipos. Ha dicho: $(tr '\n' ' ' <<<"$COPIA_SALIDA" | cut -c1-160)"; return 1; }
}
b4_restaura() {
    [ -n "$COPIA" ] || { MSG="Primero el 4.1."; return 1; }
    local n
    sql 'DROP DATABASE IF EXISTS inventario_prueba; CREATE DATABASE inventario_prueba' || return 1
    admin "cat /copias/$COPIA" | docker compose exec -T db mariadb -uroot -p"$ROOTPW" inventario_prueba 2>/dev/null
    n=$(sql 'SELECT COUNT(*) FROM inventario_prueba.equipos'); sql 'DROP DATABASE inventario_prueba'
    MSG="Restaurada en una base de prueba, tiene ${n:-0} equipos."
    [ "${n:-0}" -ge 8 ]
}
b4_borra() {
    [ -n "$COPIA" ] || { MSG="Primero el 4.1."; return 1; }
    if admin "test -e $VIEJA"; then MSG="Una copia de hace 10 días (copias/$(basename $VIEJA)) sigue ahí."; admin "rm -f $VIEJA"; return 1; fi
    admin "test -e /copias/$COPIA" || { MSG="Ha borrado también la copia de hoy."; TRAMPA="-mtime +7 = más de 7 días. Sin el +, no es lo mismo."; return 1; }
}
b4_secretos() {
    local p; p=$(envvar DB_PASS)
    if grep -qF 'raiz-de-la-bateria' servidor/copia.sh || { [ -n "$p" ] && grep -qF -- "$p" servidor/copia.sh; }; then
        MSG="servidor/copia.sh tiene una contraseña escrita."; TRAMPA="el script va a Git: la contraseña sale de \$DB_PASS (inventario.env)."; return 1
    fi
    grep -qE '^[[:space:]]*(\.|source)[[:space:]]+[^#]*inventario\.env' servidor/copia.sh || { MSG="copia.sh no carga inventario.env (paso 1)."; return 1; }
    grep -q '\$DB_PASS\|\${DB_PASS}' servidor/copia.sh || { MSG="copia.sh no usa \$DB_PASS."; return 1; }
}

bloque 4 "Copia y restauración"
check 4.1 "✍️" "copia.sh deja una copia con fecha en copias/" b4_copia
check 4.2 "✍️" "…y esa copia se puede restaurar (8 equipos)" b4_restaura
check 4.3 "✍️" "Borra las copias de más de 7 días, y no la de hoy" b4_borra
check 4.4 "✍️" "Sin contraseñas en copia.sh: las lee de inventario.env" b4_secretos
check_pred 4.a "¿La copia de mysqldump guarda los usuarios (inv_web) y sus permisos?" no "No: copia la base inventario (sus tablas y sus datos). Los usuarios están en la base del sistema mysql: si reinstalas el servidor, hay que volver a crearlos."
check_pred 4.b "La copia es de las 3:30 y restauras a las 12:00. ¿Se pierden las incidencias de esa mañana?" sí "Sí: la copia es una foto de las 3:30. Restaurar es volver a ese momento: lo de después se pierde (por eso, copias frecuentes)."

# ═════════════ Bloque 5 · La configuración en Git ═════════════
GIT_ARCHIVOS=$(admin 'git ls-files 2>/dev/null')
b5_repo() {
    admin 'git rev-parse --git-dir' >/dev/null || { MSG="servidor/ no es un repositorio de Git."; return 1; }
    [ "$(admin 'git rev-list --count HEAD 2>/dev/null')" -ge 1 ] 2>/dev/null || { MSG="El repositorio no tiene ningún commit."; return 1; }
    MSG="En Git hay: $(tr '\n' ' ' <<<"$GIT_ARCHIVOS")"
    grep -qx 'nginx/inventario.conf' <<<"$GIT_ARCHIVOS" && grep -qx 'copia.sh' <<<"$GIT_ARCHIVOS"
}
b5_secretos() {
    local p; p=$(envvar DB_PASS)
    admin 'git rev-parse --git-dir' >/dev/null || { MSG="Primero el 5.1."; return 1; }
    if grep -qx 'inventario.env' <<<"$GIT_ARCHIVOS"; then
        MSG="inventario.env está DENTRO del repositorio."
        TRAMPA="hiciste git add antes de crear el .gitignore. git rm --cached inventario.env y commit… y la contraseña ya está en el historial: CÁMBIALA (ALTER USER en MariaDB y en inventario.env)."
        return 1
    fi
    admin 'git check-ignore -q inventario.env' || { MSG="Git no ignora inventario.env: falta en .gitignore."; return 1; }
    admin 'git check-ignore -q servidor.key' || { MSG="Git no ignora las claves (*.key)."; return 1; }
    if [ -n "$p" ] && admin 'git log -p --all' | grep -qF -- "$p"; then
        MSG="Tu contraseña de inv_web aparece en el historial de Git."
        TRAMPA="borrarla en otro commit no basta: sigue en los anteriores. Hay que cambiarla (ALTER USER 'inv_web'@'%' IDENTIFIED BY '…' e inventario.env)."
        return 1
    fi
}
b5_revert() {
    admin 'git rev-parse --git-dir' >/dev/null || { MSG="Primero el 5.1."; return 1; }
    admin 'git log --format=%s' | grep -q '^Revert "' || { MSG="No hay ningún commit hecho con git revert."; return 1; }
    admin 'git diff --quiet HEAD -- nginx/inventario.conf' || { MSG="nginx/inventario.conf tiene cambios sin guardar en Git (git diff)."; return 1; }
}

bloque 5 "La configuración en Git"
check 5.1 "✍️" "servidor/ en Git, con nginx/inventario.conf y copia.sh dentro" b5_repo
check 5.2 "✍️" "inventario.env y las claves, fuera de Git (y del historial)" b5_secretos
check 5.3 "✍️" "Un cambio deshecho con git revert, y Nginx como en el último commit" b5_revert

# ═════════════ Bloque 6 · Integrador: las incidencias ═════════════
post() { web -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "$1" "$URL/api/incidencias"; }
MARCA="Prueba del comprobador $$"
TRUCO="Teclado roto'); DROP TABLE equipos; -- $$"
b6_get() {
    local c t j
    c=$(codigo "$URL/api/incidencias"); t=$(web -o /dev/null -w '%{content_type}' "$URL/api/incidencias"); j=$(web "$URL/api/incidencias")
    MSG="GET /api/incidencias da $c ($t): $(cut -c1-100 <<<"$j")"
    [ "$c" = 501 ] && return 1
    [ "$c" = 500 ] && { MSG="$MSG · En logs/gunicorn-errores.log: $(error_api)"; grep -q "doesn't exist" logs/gunicorn-errores.log 2>/dev/null && TRAMPA="falta la tabla incidencias: es el 1.3."; return 1; }
    [ "$c" = 200 ] && [[ $t == application/json* ]] && [[ $(tr -d ' \n' <<<"$j") == \[* ]]
}
b6_post() {
    local c j
    post "{\"equipo_id\": 1, \"descripcion\": \"$MARCA (antes)\"}" >/dev/null
    c=$(post "{\"equipo_id\": 3, \"descripcion\": \"$MARCA\"}")
    MSG="POST con equipo 3 y una descripción da $c (tiene que ser 201)."
    [ "$c" = 500 ] && { MSG="$MSG En logs/gunicorn-errores.log: $(error_api)"; grep -q 'INSERT command denied' logs/gunicorn-errores.log 2>/dev/null && TRAMPA="inv_web no tiene INSERT (1.2)."; }
    [ "$c" = 201 ] || return 1
    j=$(web "$URL/api/incidencias")
    grep -qF "$MARCA" <<<"$j" || { MSG="Da 201, pero la incidencia no sale después en GET."; TRAMPA="sin c.commit() el INSERT no se guarda."; return 1; }
    [ "$(sed -n 's/^[^{]*{[^}]*"descripcion": *"\([^"]*\)".*/\1/p' <<<"$(tr -d '\n' <<<"$j")")" = "$MARCA" ] || { MSG="Sale en GET, pero no la primera: la más nueva va primero (ORDER BY id DESC)."; return 1; }
}
b6_422() {
    local a b c
    a=$(post '{"equipo_id": 3, "descripcion": ""}'); b=$(post '{"equipo_id": 999, "descripcion": "No enciende"}'); c=$(post '{"equipo_id": 3}')
    MSG="Descripción vacía: $a · equipo 999: $b · sin descripción: $c (los tres, 422)."
    [ "$b" = 201 ] && TRAMPA="se ha guardado una incidencia de un equipo que no existe: búscalo antes en equipos."
    [ "$c" = 500 ] && TRAMPA="datos[\"descripcion\"] falla si no viene: datos.get(\"descripcion\", \"\")."
    [ "$a" = 422 ] && [ "$b" = 422 ] && [ "$c" = 422 ]
}
b6_inyeccion() {
    local c guardado
    c=$(post "{\"equipo_id\": 3, \"descripcion\": \"$TRUCO\"}")
    guardado=$(sql "SELECT descripcion FROM inventario.incidencias WHERE descripcion LIKE 'Teclado roto%$$'")
    MSG="Con una descripción con comillas da $c y se ha guardado: «${guardado}»."
    [ "$(sql 'SELECT COUNT(*) FROM inventario.equipos')" -ge 8 ] 2>/dev/null || { MSG="¡La tabla equipos ha desaparecido!"; return 1; }
    [ "$c" = 500 ] && TRAMPA="la comilla rompe el SQL: el dato está pegado dentro. Va aparte (%s y una tupla)."
    [ "$c" = 201 ] && [ "$guardado" = "$TRUCO" ]
}

bloque 6 "Integrador: las incidencias"
check 6.1 "✍️" "GET /api/incidencias: una lista en JSON" b6_get
check 6.2 "✍️" "POST guarda una incidencia (201) y sale la primera" b6_post
check 6.3 "✍️" "Descripción vacía o equipo que no existe: 422" b6_422
check 6.4 "✍️" "Una descripción con comillas se guarda tal cual" b6_inyeccion
toca 6 && sql "DELETE FROM inventario.incidencias WHERE descripcion LIKE 'Prueba del comprobador%' OR descripcion LIKE 'Teclado roto%' OR descripcion = 'No enciende' AND equipo_id = 999" >/dev/null
cierre_bloque

echo
if [ -n "$SOLO" ]; then
    echo "${N}Bloque $SOLO: $ok de $total${X}"
else
    echo "${N}Resultado: $ok de $total${X}  ${G}(los 👀 son ejemplos ya resueltos)${X}"
    [ "$ok" -lt "$total" ] && echo "${G}Para ver un bloque con más detalle: ./bateria.sh comprobar N · Pistas: «🆘 ¿Atascado?» en la página de la batería.${X}"
fi
[ "$ok" -eq "$total" ]

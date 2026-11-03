#!/usr/bin/env bash
#
# lab.sh — Batería guiada de SAD · UD3 (cortafuegos) y UD4 (VPN), sobre el laboratorio de clase.
#
# No necesitas saber Docker: todo lo que hace falta está aquí.
#   ./lab.sh ayuda        -> lista de órdenes
#
set -uo pipefail
cd "$(dirname "$0")"

MAQUINAS="firewall pc web internet remoto"
c() { echo "sad-ud34-$1"; }

# ---------- colores ----------
if [ -t 1 ]; then
    R=$'\e[1;31m'; V=$'\e[1;32m'; A=$'\e[1;33m'; Z=$'\e[1;34m'; N=$'\e[1m'; X=$'\e[0m'
else
    R=""; V=""; A=""; Z=""; N=""; X=""
fi
info()  { echo "${Z}▶${X} $*"; }
bien()  { echo "${V}✔${X} $*"; }
aviso() { echo "${A}!${X} $*"; }
error() { echo "${R}✘ $*${X}" >&2; }

necesita_docker() {
    if ! command -v docker >/dev/null 2>&1; then error "Docker no está instalado en este equipo."; exit 1; fi
    if ! docker info >/dev/null 2>&1; then
        error "Docker está instalado pero no puedo usarlo."
        echo "  - ¿Está arrancado?           sudo systemctl start docker"
        echo "  - ¿Tu usuario está en el grupo docker?  sudo usermod -aG docker \$USER  (y cierra sesión)"
        exit 1
    fi
}
corriendo() { [ "$(docker inspect -f '{{.State.Running}}' "$(c "$1")" 2>/dev/null)" = "true" ]; }
necesita_lab() {
    necesita_docker
    for m in $MAQUINAS; do
        corriendo "$m" || { error "El laboratorio no está arrancado (falta «$m»)."; echo "  Arráncalo con:  ./lab.sh arrancar"; exit 1; }
    done
}
en() { local m=$1; shift; docker exec "$(c "$m")" "$@"; }

# Una prueba: descripción, máquina y orden. Si la orden sale bien, ✔; si no, ✘ y la pista.
OK=0; MAL=0
prueba() {
    local desc=$1 maq=$2 orden=$3 pista=${4:-}
    if en "$maq" bash -c "$orden" >/dev/null 2>&1; then bien "$desc"; OK=$((OK + 1))
    else echo "${R}✘${X} $desc"; [ -n "$pista" ] && echo "    ${A}pista:${X} $pista"; MAL=$((MAL + 1)); fi
}
# curl que espera poco: exit 0 = llega · 7 = rechazado (pasa el cortafuegos, pero no hay servicio) · 28 = no contesta (drop)
CURL="curl -s -o /dev/null --max-time 3"

ayuda() {
    cat <<EOF
${N}Laboratorio SAD · UD3 (cortafuegos nftables) y UD4 (VPN WireGuard)${X}

  «Internet» 203.0.113.0/24     DMZ 10.10.20.0/24     LAN 10.10.10.0/24
  internet .50 · remoto .60      web .10               pc .5
              \\__________ firewall .254 (wan · dmz · lan) + VPN wg0 10.200.200.1 __________/

${N}Arrancar y parar${X}
  ./lab.sh arrancar        crea y arranca las 5 máquinas (la primera vez tarda un par de minutos)
  ./lab.sh parar           las apaga (tus ficheros se quedan en esta carpeta)
  ./lab.sh reiniciar       las apaga y las vuelve a arrancar desde cero (si algo se ha liado)
  ./lab.sh estado          qué máquinas están en marcha

${N}Entrar en una máquina${X} (sales con exit)
  ./lab.sh firewall · pc · web · internet · remoto

${N}Cortafuegos (UD3)${X}
  Edita ${N}firewall/nftables.conf${X} en tu ordenador (o dentro del firewall: nano /etc/nftables.conf)
  ./lab.sh aplicar         comprueba la sintaxis y carga el cortafuegos
  ./lab.sh ver             enseña las reglas cargadas, con sus contadores
  ./lab.sh vaciar          quita todas las reglas (vuelve a dejar pasar todo)

${N}VPN (UD4)${X}
  Configuración en ${N}firewall/wireguard/wg0.conf${X} y ${N}remoto/wireguard/wg0.conf${X}
  ./lab.sh vpn             (re)levanta el túnel en los dos extremos y enseña «wg show»

${N}Batería guiada (UD3 + UD4)${X}
  ./lab.sh comprobar       todos los bloques (o uno: ./lab.sh comprobar 1 … 6)
  ./lab.sh averia N        bloque 6: te rompe algo (1, 2 o 3) para que lo encuentres
  ./lab.sh averia deshacer vuelve a como lo tenías antes de la avería
EOF
    [ -d solucion ] && echo -e "\n${N}Profesor${X}\n  ./lab.sh solucion        carga la solución de la batería (guarda antes una copia)"
}

arrancar() {
    necesita_docker
    info "Arrancando el laboratorio…"
    docker compose up -d --build >/dev/null 2>&1 || { error "No se pudo arrancar. Prueba:  docker compose up --build  (y mira el error)"; exit 1; }
    sleep 2
    for m in $MAQUINAS; do corriendo "$m" && bien "$m en marcha" || error "$m no arrancó: docker logs $(c "$m")"; done
    echo; echo "Ahora: ${N}./lab.sh ayuda${X} para ver qué hacer."
}

aplicar() {
    necesita_lab
    info "Comprobando la sintaxis de firewall/nftables.conf…"
    if ! en firewall nft -c -f /etc/nftables.conf; then
        error "Hay un error en nftables.conf (arriba te dice la línea). No he cargado nada: sigue el cortafuegos de antes."
        exit 1
    fi
    en firewall nft -f /etc/nftables.conf && bien "Cortafuegos cargado. Míralo con ./lab.sh ver"
}

vpn() {
    necesita_lab
    for m in firewall remoto; do
        if ! en "$m" test -s /etc/wireguard/wg0.conf; then error "Falta $m/wireguard/wg0.conf"; exit 1; fi
        en "$m" bash -c 'wg-quick down wg0 >/dev/null 2>&1; wg-quick up wg0' >/dev/null 2>&1 \
            && bien "túnel levantado en $m" || { error "wg-quick no pudo levantar wg0 en $m:"; en "$m" wg-quick up wg0; }
    done
    en remoto ping -c 1 -W 2 10.200.200.1 >/dev/null 2>&1   # provoca el primer saludo
    echo; info "wg show en el firewall:"; en firewall wg show
}

# Lo que se crea dentro de las máquinas (claves, wg0.conf) pasa a ser del dueño de la carpeta, para editarlo desde tu ordenador
# (el arranque de cada máquina ya lo hace cada 2 s; esto es por si acaso, y vale también con sudo ./lab.sh)
tuyo() { for m in firewall remoto; do corriendo "$m" && en "$m" sh -c 'chown -R "$(stat -c %u:%g /lab)" /lab' 2>/dev/null; done; }

# ---------- comprobar la batería ----------
# Cada prueba: número, descripción, máquina, orden, 💡 pista y (opcional) la prueba que tiene que funcionar antes.
# Las 👀 son las del ejemplo resuelto. La batería no cuenta para la nota: el recuento es solo para que sepas cómo vas.
declare -A RES
OK=0; MAL=0
CURL="curl -s -o /dev/null --max-time 3"
prueba() {
    local id=$1 desc=$2 maq=$3 orden=$4 pista=${5:-} dep=${6:-}
    if [ -n "$dep" ] && [ "${RES[$dep]:-0}" != 1 ]; then
        RES[$id]=0; MAL=$((MAL + 1)); echo "${R}✘${X} $id · $desc"; echo "    ${A}primero tiene que funcionar $dep${X}"; return
    fi
    if en "$maq" bash -c "$orden" >/dev/null 2>&1; then RES[$id]=1; OK=$((OK + 1)); bien "$id · $desc"
    else RES[$id]=0; MAL=$((MAL + 1)); echo "${R}✘${X} $id · $desc"; [ -n "$pista" ] && echo "    ${A}💡${X} $pista"; fi
}
# curl a un puerto sin servicio: 7 = el vigilante deja pasar y no hay nadie (rechazado) · 28 = el vigilante lo tira (drop)
PASA="[ \$? -eq 7 ] || [ \$? -eq 0 ]"

bloque1() {
    echo "${N}1 · El vigilante (input)${X}"
    prueba "👀 1.0" "El vigilante se habla a sí mismo y recuerda lo que empezó (lo, established)" firewall \
        "nft list chain inet filtro input | grep -q 'iif \"lo\" accept' && nft list chain inet filtro input | grep -q 'ct state established,related accept'" \
        "¿has borrado las líneas 👀 de input?"
    prueba "1.1" "input tiene policy drop (lista blanca)" firewall "nft list chain inet filtro input | grep -q 'policy drop'" \
        "cambia  policy accept;  por  policy drop;  en la cadena input"
    prueba "1.2" "Las oficinas (pc) llegan al SSH del vigilante" pc "$CURL telnet://10.10.10.254:22; r=\$?; [ \$r -eq 7 ] || [ \$r -eq 0 ]" \
        "iifname \$LAN tcp dport 22 accept   (el vigilante no tiene SSH: «rechazado» quiere decir que el vigilante te ha dejado pasar)" 1.1
    prueba "1.3" "La tienda (web) NO llega al SSH del vigilante" web "$CURL telnet://10.10.20.254:22; [ \$? -eq 28 ]" \
        "error típico: tcp dport 22 accept sin iifname \$LAN (entonces entra cualquiera)" 1.2
    prueba "1.4" "Las oficinas hacen ping al vigilante" pc "ping -c 1 -W 2 10.10.10.254" "icmp type echo-request accept" 1.1
}
bloque2() {
    echo "${N}2 · Quién va a dónde (forward)${X}"
    prueba "👀 2.0" "Las oficinas navegan por la calle" pc "$CURL http://203.0.113.50" \
        "esto lo dan hecho las líneas 👀 (established, lan -> wan) y el masquerade 👀"
    prueba "2.1" "Hay una regla que deja pasar de la calle a la web, solo 80 y 443" firewall \
        "nft list chain inet filtro forward | grep -E 'iifname \"wan\" oifname \"dmz\".*dport \\{ 80, 443 \\}.*accept'" \
        "iifname \$WAN oifname \$DMZ ip daddr \$WEB tcp dport { 80, 443 } accept"
    prueba "2.2" "Las oficinas administran la web por SSH" pc "$CURL telnet://10.10.20.10:22; r=\$?; [ \$r -eq 7 ] || [ \$r -eq 0 ]" \
        "iifname \$LAN oifname \$DMZ ip daddr \$WEB tcp dport 22 accept"
    prueba "2.3" "La tienda NO entra en las oficinas" web "$CURL http://10.10.10.5; [ \$? -ne 0 ]" \
        "iifname \$DMZ oifname \$LAN drop" 2.2
    prueba "2.4" "La tienda NO sale a la calle" web "$CURL http://203.0.113.50; [ \$? -ne 0 ]" \
        "error típico: oifname \$WAN accept sin decir de dónde (iifname \$LAN). Así sale cualquiera" 2.2
}
bloque3() {
    echo "${N}3 · La centralita (NAT)${X}"
    prueba "👀 3.0" "Fuera ven la IP de la empresa (masquerade)" pc "curl -s --max-time 3 http://203.0.113.50 | grep -q 203.0.113.254" \
        "¿has borrado el masquerade 👀?"
    prueba "3.1" "Desde la calle se ve la web en la IP de la empresa (DNAT)" internet \
        "curl -s --max-time 3 http://203.0.113.254 | grep -q DMZ" \
        "iifname \$WAN tcp dport { 80, 443 } dnat to \$WEB   (en prerouting) y la regla 2.1 en forward"
    prueba "3.2" "Desde la calle NO se llega al 8080 (no está publicado)" internet "$CURL http://203.0.113.254:8080; [ \$? -eq 28 ]" \
        "error típico: dnat de todos los puertos (sin tcp dport)" 3.1
}
bloque4() {
    echo "${N}4 · 🔮 Piensa como un atacante${X}"
    local esperado="22=filtered 80=open 443=closed 8080=filtered" bien_n=0 p l
    for p in $esperado; do
        l=$(grep -E "^${p%%=*}=" predicciones.txt 2>/dev/null | tr -d ' \r' | tr A-Z a-z)
        if [ "$l" = "$p" ]; then bien_n=$((bien_n + 1)); fi
    done
    if [ "$bien_n" -eq 4 ]; then RES[4.1]=1; OK=$((OK + 1)); bien "4.1 · Tus cuatro predicciones de predicciones.txt son correctas"
    else RES[4.1]=0; MAL=$((MAL + 1)); echo "${R}✘${X} 4.1 · predicciones.txt: $bien_n de 4 bien"
        echo "    ${A}💡${X} open = te abren · closed = el vigilante te deja pasar y no hay nadie · filtered = el vigilante te ignora. ¿Qué puertos publica el DNAT? ¿Escucha la web en el 443?"; fi
}
bloque5() {
    echo "${N}5 · El pasadizo (VPN)${X}"
    tuyo
    prueba "👀 5.0" "El vigilante tiene sus claves (firewall/wireguard/fw.key y fw.pub)" firewall "test -s /etc/wireguard/fw.key && test -s /etc/wireguard/fw.pub" \
        "sigue el paso 👀 de la página: wg genkey | tee fw.key | wg pubkey > fw.pub"
    en remoto ping -c 1 -W 2 10.200.200.1 >/dev/null 2>&1
    prueba "5.1" "Los dos extremos se han dado la mano (handshake)" firewall \
        "[ \$(wg show wg0 latest-handshakes | awk '{print \$2}' | sort -n | tail -1) -gt 0 ]" \
        "en TU fichero, TU llave y el CANDADO DEL OTRO · Endpoint = 203.0.113.254:51820 · y la puerta del 5.2 abierta"
    prueba "5.2" "El vigilante abre la puerta del pasadizo (udp 51820 en input, por la wan)" firewall \
        "nft list chain inet filtro input | grep -E 'iifname \"wan\" udp dport 51820 accept'" "iifname \$WAN udp dport 51820 accept"
    prueba "5.3" "Desde casa se llega a la intranet por el pasadizo" remoto \
        "curl -s --max-time 3 http://10.10.10.5 | grep -q 'desde 10.200.200.2'" \
        "falta en forward:  iifname \"wg0\" oifname \$LAN accept   ¿y el AllowedIPs del remoto incluye 10.10.10.0/24?" 5.1
    prueba "5.4" "Sin pasadizo, la calle NO llega a la intranet" internet "$CURL http://10.10.10.5; [ \$? -ne 0 ]" "" 5.3
}
comprobar() {
    necesita_lab; OK=0; MAL=0
    case "${1:-todo}" in
        1) bloque1 ;; 2) bloque2 ;; 3) bloque3 ;; 4) bloque4 ;; 5) bloque5 ;;
        6) echo "Bloque 6: haz ./lab.sh averia 1 (o 2, o 3) y después ./lab.sh comprobar para encontrarla"; bloque1; bloque2; bloque3; bloque5 ;;
        *) bloque1; echo; bloque2; echo; bloque3; echo; bloque4; echo; bloque5 ;;
    esac
    echo; [ "$MAL" -eq 0 ] && bien "${N}$OK de $OK. ¡Todo bien!${X}" || echo "${A}$OK bien · $MAL por arreglar${X}"
    echo "(la batería no cuenta para la nota: es tu entrenamiento para la Práctica 2)"
}

# ---------- bloque 6: averías ----------
averia() {
    necesita_lab; tuyo
    local n=${1:-}
    if [ "$n" = deshacer ]; then
        [ -d copias/antes-de-la-averia ] || { error "No hay ninguna avería que deshacer."; exit 1; }
        cp -r copias/antes-de-la-averia/firewall/. firewall/; cp -r copias/antes-de-la-averia/remoto/. remoto/
        aplicar; vpn >/dev/null 2>&1; bien "Todo como antes de la avería"; return
    fi
    [[ "$n" =~ ^[123]$ ]] || { error "Uso: ./lab.sh averia 1|2|3  (o ./lab.sh averia deshacer)"; exit 1; }
    rm -rf copias/antes-de-la-averia; mkdir -p copias/antes-de-la-averia; cp -r firewall remoto copias/antes-de-la-averia/
    case "$n" in
        # La de forward. Se reescribe el contenido sin borrar el fichero (el firewall lo tiene enlazado)
        1) awk '/chain forward/{f=1} f && /ct state established,related accept/ && !d {d=1; next} {print}' firewall/nftables.conf > copias/tmp.conf \
             && cat copias/tmp.conf > firewall/nftables.conf && rm -f copias/tmp.conf ;;
        # En el remoto, su propio candado en lugar del del vigilante: llave y candado cruzados
        2) local p; p=$(sed -n "s/^PrivateKey *= *//p" remoto/wireguard/wg0.conf 2>/dev/null | docker exec -i "$(c remoto)" wg pubkey 2>/dev/null)
           [ -n "$p" ] || { error "Primero termina el bloque 5"; exit 1; }
           sed -i "s|^PublicKey *=.*|PublicKey  = $p|" remoto/wireguard/wg0.conf ;;
        3) sed -i '/iifname "wg0" oifname \$LAN accept/d; /iifname \$VPN oifname \$LAN accept/d' firewall/nftables.conf ;;
    esac
    aplicar >/dev/null; vpn >/dev/null 2>&1
    aviso "Avería $n puesta. Algo ha dejado de funcionar: encuéntralo con  ./lab.sh comprobar, ./lab.sh ver  y  wg show."
    echo "  Si te rindes:  ./lab.sh averia deshacer"
}

solucion() {
    [ -d solucion ] || { error "Esta orden es solo del profesor."; exit 1; }
    necesita_lab
    mkdir -p copias; local f; f="copias/$(date +%H%M%S)"; mkdir -p "$f"; cp -r firewall remoto predicciones.txt "$f"/ 2>/dev/null
    aviso "Copia de lo que había en $f/"
    cp solucion/nftables.conf firewall/nftables.conf; cp solucion/predicciones.txt predicciones.txt
    local fpriv fpub rpriv rpub
    fpriv=$(en firewall wg genkey); fpub=$(echo "$fpriv" | docker exec -i "$(c firewall)" wg pubkey)
    rpriv=$(en remoto wg genkey);   rpub=$(echo "$rpriv" | docker exec -i "$(c remoto)" wg pubkey)
    echo "$fpriv" > firewall/wireguard/fw.key; echo "$fpub" > firewall/wireguard/fw.pub
    echo "$rpriv" > remoto/wireguard/remoto.key; echo "$rpub" > remoto/wireguard/remoto.pub
    sed -e "s|@FW_PRIV@|$fpriv|" -e "s|@REMOTO_PUB@|$rpub|" solucion/wg0-firewall.conf > firewall/wireguard/wg0.conf
    sed -e "s|@REMOTO_PRIV@|$rpriv|" -e "s|@FW_PUB@|$fpub|" solucion/wg0-remoto.conf > remoto/wireguard/wg0.conf
    chmod 600 firewall/wireguard/* remoto/wireguard/*
    aplicar && vpn
}

case "${1:-ayuda}" in
    arrancar) arrancar ;;
    parar) necesita_docker; tuyo; docker compose stop >/dev/null 2>&1 && bien "Laboratorio parado" ;;
    reiniciar) necesita_docker; docker compose down >/dev/null 2>&1; arrancar ;;
    estado) necesita_docker; for m in $MAQUINAS; do corriendo "$m" && bien "$m" || aviso "$m parada"; done ;;
    firewall|pc|web|internet|remoto) necesita_lab; docker exec -it "$(c "$1")" bash; tuyo ;;
    aplicar) aplicar ;;
    ver) necesita_lab; en firewall nft -a list ruleset ;;
    vaciar) necesita_lab; en firewall nft flush ruleset && aviso "Cortafuegos vacío: ahora pasa todo" ;;
    vpn) vpn ;;
    comprobar) comprobar "${2:-todo}" ;;
    averia) averia "${2:-}" ;;
    solucion) solucion ;;
    ayuda|-h|--help) ayuda ;;
    *) error "No conozco la orden «$1»."; ayuda; exit 1 ;;
esac

#!/bin/bash
# Arranque de cada máquina del laboratorio según su ROL: firewall, pc, web, internet o remoto.
set -u
ROL=${ROL:-?}

# Prompt de color con el nombre de la máquina, para no confundirse de terminal
case "$ROL" in
  firewall) C=31 ;; pc) C=34 ;; web) C=33 ;; internet) C=35 ;; remoto) C=36 ;; *) C=37 ;;
esac
grep -q "PS1=" /root/.bashrc || echo "PS1='\[\e[1;${C}m\]${ROL}\[\e[0m\]:\w# '" >> /root/.bashrc

# Página que sirve cada máquina: así se ve a quién llega cada petición y desde qué IP
pagina() {
  printf 'server { listen 80 default_server; location / { default_type text/plain; return 200 "%s · te llega una peticion desde $remote_addr\\n"; } }\n' "$1" \
    > /etc/nginx/sites-enabled/lab
  nginx
}

# Lo que se edita vive en /lab (tu carpeta firewall/ o remoto/): /etc/nftables.conf y /etc/wireguard apuntan ahí
if [ -d /lab ]; then
  [ -f /lab/nftables.conf ] && ln -sf /lab/nftables.conf /etc/nftables.conf
  mkdir -p /lab/wireguard && rm -rf /etc/wireguard && ln -s /lab/wireguard /etc/wireguard
  # Lo que se crea aquí dentro (claves, wg0.conf…) es de root y desde tu ordenador no podrías editarlo:
  # cada 2 s pasa a ser del dueño de la carpeta (tú)
  ( while sleep 2; do find /lab ! -user "$(stat -c %u /lab)" -exec chown -h "$(stat -c %u:%g /lab)" {} + 2>/dev/null; done ) &
fi

case "$ROL" in
  firewall)
    # Las interfaces se llaman por la red a la que van: wan, dmz y lan (Docker las crea como eth0, eth1…)
    for i in $(ls /sys/class/net | grep -v -e '^lo$' -e '^wg'); do
      ip=$(ip -4 -o addr show "$i" | awk '{print $4}')
      case "$ip" in 203.0.113.*) n=wan ;; 10.10.20.*) n=dmz ;; 10.10.10.*) n=lan ;; *) continue ;; esac
      ip link set "$i" down && ip link set "$i" name "$n" && ip link set "$n" up
    done
    ip route replace default via 203.0.113.1 dev wan 2>/dev/null
    nft -f /etc/nftables.conf 2>/dev/null || echo "nftables.conf tiene errores: corrígelo y ./lab.sh aplicar"
    [ -s /etc/wireguard/wg0.conf ] && wg-quick up wg0 >/dev/null 2>&1
    ;;
  pc)       ip route replace default via 10.10.10.254; pagina "PC de la LAN (intranet)" ;;
  web)      ip route replace default via 10.10.20.254; pagina "Servidor web de la DMZ" ;;
  internet) pagina "Servidor de Internet" ;;
  remoto)   [ -s /etc/wireguard/wg0.conf ] && wg-quick up wg0 >/dev/null 2>&1 ;;
esac
echo "$ROL listo"
exec sleep infinity

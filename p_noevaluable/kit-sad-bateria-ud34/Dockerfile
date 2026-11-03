# Laboratorio de clase SAD · UD3 (cortafuegos nftables) y UD4 (VPN WireGuard)
# Una sola imagen para las cinco máquinas: cada una hace su papel según ROL (ver arranque.sh).
FROM debian:trixie-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      nftables iproute2 iputils-ping wireguard-tools tcpdump curl nmap netcat-openbsd nginx-light procps less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/* && rm -f /etc/nginx/sites-enabled/default
COPY arranque.sh /usr/local/bin/arranque.sh
RUN chmod +x /usr/local/bin/arranque.sh
CMD ["/usr/local/bin/arranque.sh"]

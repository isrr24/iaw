# Práctica 1: Servidores, Proxies y Certificados
**Proyecto:** Nimbus Docs - Portal Documental Seguro Multi-Marca
**Módulo:** Implantación de Aplicaciones Web (Curso 2026/2027)

---

## I. Diseño y Requisitos

**1. Dominios Elegidos:**
*   **Marca 1 (Pública):** `nimbus1.local` (y expuesto a través de Nginx como `isma.iaw.net`). Elegido para representar la marca principal de cara al público.
*   **Marca 2 (Interna/Privada):** `nimbus2.local`. Elegido para la documentación técnica interna de la empresa que requiere medidas de protección adicionales.
*   **Sitio por Defecto:** `default.local`. Creado como sumidero para atrapar cualquier petición con un dominio no reconocido.

**2. MPM de Apache Elegido:**
Al utilizar la imagen de Docker `php:8.2-apache`, el servidor viene configurado por defecto con el **MPM Prefork**. Esta elección es técnicamente necesaria y justificada porque el módulo de PHP nativo (`mod_php`) no es "thread-safe", lo que obliga a Apache a crear procesos independientes (en lugar de hilos) para aislar cada petición y garantizar la estabilidad al ejecutar código PHP.

---

## II. Fase 1 - Backend Apache Multi-Marca (Docker Compose)

La infraestructura se levantó usando Docker Compose con dos servicios (`web` para Apache y `proxy` para Nginx), mapeando los volúmenes locales a sus rutas correspondientes (código en `/var/www`, configuraciones en `/etc/apache2/sites-available` y `/etc/nginx/conf.d`, y logs en `/var/log/apache2`). Apache expone internamente el puerto 80 y externamente el 2001.

**1. Virtual Hosts Configurados:**
Se crearon tres archivos `.conf` dentro de la carpeta local `apache/sites-available` y se activaron usando `a2ensite`:
*   `000-default.conf`: Atrapa dominios no válidos apuntando al DocumentRoot `/var/www/default`.
*   `nimbus1.conf`: Sirve la marca 1 en `/var/www/nimbus1`.
*   `nimbus2.conf`: Sirve la marca 2 en `/var/www/nimbus2`.
*   *Nota:* Cada Virtual Host tiene directivas `ErrorLog` y `CustomLog` separadas para aislar la auditoría (ej. `nimbus1_access.log`).

**2. Protección de Recursos (Marca Interna):**
Dentro de `nimbus2.conf`, se aplicaron directivas de seguridad estrictas:
*   `Options -Indexes`: Para desactivar el listado de directorios y evitar exposición de estructura.
*   `<Files "archivoprivado.php"> Require all denied </Files>`: Para denegar por completo el acceso HTTP a este documento simulado, devolviendo un error 403.

---

## III. Fase 2 - Terminación TLS en Nginx y Seguridad

Nginx se configuró como proxy inverso (`nimbus.conf`) para interceptar todo el tráfico HTTPS en el puerto 443, descargar el trabajo de cifrado (Terminación TLS) y reenviar el texto plano a Apache.

**1. Configuración TLS y Cifrado:**
*   **Certificado:** Se generó un certificado auto-firmado de curva elíptica ECDSA (`isma.crt` / `isma.key`) asociado al dominio `isma.iaw.net`.
*   **Protocolos:** Se restringió obsoletos mediante `ssl_protocols TLSv1.2 TLSv1.3;`.
*   **Cipher Suite:** Se configuró un conjunto fuerte (`ECDHE-ECDSA-AES128-GCM-SHA256...`) dando prioridad a algoritmos GCM de cifrado autenticado, rechazando RC4 y 3DES.

**2. Redirección y Proxy Inverso:**
*   El bloque del puerto 80 obliga a saltar a HTTPS con `return 301 https://$host$request_uri;` (se usa 301 porque el salto a la versión segura es permanente y ayuda al SEO/caché).
*   En el bloque HTTPS, se usa `proxy_pass http://web:80;` para enrutar internamente.
*   **Cabeceras obligatorias:** Se incluyó `proxy_set_header Host $host;`. Sin esta línea, Apache recibiría la petición con la IP interna del proxy como "Host", por lo que no sabría a qué marca apuntar y devolvería la página por defecto (`000-default.conf`).

**3. Cabeceras de Seguridad:**
*   `Strict-Transport-Security`: Obliga al cliente a usar siempre HTTPS (HSTS).
*   `X-Content-Type-Options "nosniff"`: Evita que el navegador adivine el tipo MIME.
*   `Content-Security-Policy "default-src 'self'"`: Previene XSS forzando la carga local.

**4. Rate Limiting (Límite de peticiones):**
Para frenar el script de scraping (20 req/s) permitiendo a los usuarios (3 req/s con picos de 6 req/s):
*   Se creó en contexto HTTP: `limit_req_zone $binary_remote_addr zone=limite_nimbus:10m rate=3r/s;`. Permite un llenado constante de 3 peticiones por segundo.
*   Se aplicó en el `server`: `limit_req zone=limite_nimbus burst=5 nodelay;`. El `burst=5` genera un "cubo" adicional que absorbe instantáneamente hasta 5 recargas rápidas de un usuario legítimo (picos). Todo lo que supere ese burst (como las 20 req/s del bot) es descartado automáticamente con Error 503.

---

## IV. Fase 3 - Diagnóstico Provocado

Errores provocados deliberadamente para la defensa oral:

| Síntoma observado | Hipótesis inicial | Comando de diagnóstico usado | Causa real y solución |
| :--- | :--- | :--- | :--- |
| **(Fallo Apache)**<br>Al intentar entrar a la web desde el navegador, la pantalla carga y muestra un error "403 Forbidden" provisto por Apache. | Nginx proxy funciona, pero el motor Apache deniega la lectura del directorio web por permisos internos. | `docker exec nimbusdocsp1 tail /var/log/apache2/nimbus1_error.log` (para ver el rechazo en el log de errores de la marca). | **Causa:** En el archivo del Virtual Host de Apache, el bloque `<Directory>` tiene configurado `Require all denied`.<br>**Solución:** Editar el archivo `.conf`, cambiarlo a `Require all granted` y ejecutar `service apache2 reload`. |
| **(Fallo Nginx)**<br>Al simular un ataque (ráfaga) de 20 peticiones seguidas, todas responden `200 OK`. No se bloquea el tráfico malicioso. | Nginx recibe el tráfico, pero la regla de Rate Limiting no se está aplicando a la ruta de entrada. | Bucle de carga rápida:<br>`while true; do curl -I -k -H "Host: isma.iaw.net" https://localhost/; done` | **Causa:** La zona de memoria global está creada, pero la directiva `limit_req zone=limite_nimbus burst=5...` está comentada o falta dentro del bloque `server` o `location`.<br>**Solución:** Descomentar la directiva en el `location /` y reiniciar el proxy (`docker compose restart proxy`). |
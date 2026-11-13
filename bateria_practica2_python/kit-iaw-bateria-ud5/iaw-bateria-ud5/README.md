# Batería UD5 · Las reservas del polideportivo (Nginx + Gunicorn + Flask)

Batería **opcional** de la UD5 de IAW: no se entrega y no cuenta para la nota. Las explicaciones y las pistas están en la
página de la batería, en la web de la asignatura («🏋️ Practicar»).

## Antes de empezar

Solo necesitas **Docker** (el de la práctica 1). En tu ordenador no se instala nada más. Todo se hace con `./bateria.sh`:

```bash
unzip kit-iaw-bateria-ud5.zip
cd iaw-bateria-ud5
./bateria.sh arrancar        # la primera vez tarda: descarga las imágenes
./bateria.sh comprobar       # al principio, solo los ejemplos 👀 en verde: 5 de 32
code .
```

| Orden | Para qué |
|---|---|
| `./bateria.sh arrancar` | Levanta el polideportivo: https://localhost:8448 (certificado de prueba: acepta el aviso) |
| `./bateria.sh comprobar` | Comprueba todos los bloques |
| `./bateria.sh comprobar 2` | Solo el bloque 2, con un 💡 en cada ejercicio y el porqué de cada predicción |
| `./bateria.sh recargar` | Aplica tus cambios: `nginx -t` + recarga Nginx, y reinicia la app (`comprobar` ya lo hace solo) |
| `./bateria.sh llave` | Genera una `SECRET_KEY` al azar (bloque 4) |
| `./bateria.sh logs` | Las últimas líneas de los logs de Nginx y de Gunicorn |
| `./bateria.sh parar` | Lo apaga todo |

## Qué tocas tú

| Bloque | Fichero |
|---|---|
| 1 · Nginx ↔ Gunicorn | `nginx/sites-available/polideportivo.conf` y `predicciones.txt` |
| 2 · Flask: rutas, métodos y validación | `polideportivo/app.py` |
| 3 · Plantillas sin XSS | `polideportivo/templates/reservar.html` y `admin.html` |
| 4 · Sesiones y `SECRET_KEY` | `polideportivo/app.py`, `config/polideportivo.env` y `predicciones.txt` |
| 5 · Python en producción | `config/polideportivo.env` y `config/gunicorn.conf.py` |
| 6 · Integrador: la API de las pistas | `polideportivo/app.py` |
| ✍️ | `respuestas.md` |

Cada hueco está marcado con ✍️ y lleva sus instrucciones dentro del fichero. Lo marcado con 👀 ya está resuelto: léelo.
No toques `comprobador/`, `compose.yaml` ni los `Dockerfile`.

**Recuerda:** Python carga el código al arrancar. Si cambias `app.py`, una plantilla o algo de `config/`, hace falta
`./bateria.sh recargar` (o `comprobar`, que ya lo hace) para verlo en el navegador.

Conserje para probar el login: `conserje` / `pista2026`.

**Puertos:** 8088 (HTTP) y 8448 (HTTPS). No chocan con el laboratorio de clase (8084/8446).

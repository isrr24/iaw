# Batería UD6 · El inventario del aula (MariaDB + PHP + Python + Git)

Batería **opcional** de la UD6 de IAW: no se entrega y no cuenta para la nota. Las explicaciones y las pistas están en la
página de la batería, en la web de la asignatura («🏋️ Practicar»).

## Antes de empezar

Solo necesitas **Docker** (el de la práctica 1). En tu ordenador no se instala nada más. Todo se hace con `./bateria.sh`:

```bash
unzip kit-iaw-bateria-ud6.zip
cd iaw-bateria-ud6
./bateria.sh arrancar        # la primera vez tarda: descarga las imágenes
./bateria.sh comprobar       # al principio, solo los ejemplos 👀 en verde: 4 de 32
code .
```

| Orden | Para qué |
|---|---|
| `./bateria.sh arrancar` | Levanta el inventario: https://localhost:8450 (certificado de prueba: acepta el aviso) |
| `./bateria.sh comprobar` | Comprueba todos los bloques |
| `./bateria.sh comprobar 2` | Solo el bloque 2, con un 💡 en cada ejercicio y el porqué de cada predicción |
| `./bateria.sh sql` | Aplica `sql/bloque1.sql` como root, dentro del servidor de base de datos |
| `./bateria.sh mariadb` | La consola de MariaDB como root, para mirar (`EXIT;` para salir) |
| `./bateria.sh admin` | Una terminal en el ordenador del administrador: Git y `mariadb -h db -u inv_web -p` |
| `./bateria.sh copia` | Lanza `servidor/copia.sh` |
| `./bateria.sh recargar` | Aplica tus cambios: recarga Nginx y reinicia la API (`comprobar` ya lo hace solo) |
| `./bateria.sh logs` | Las últimas líneas de los logs de Nginx y de Gunicorn |
| `./bateria.sh parar` | Lo apaga todo (la base de datos se conserva) |
| `./bateria.sh desde-cero` | Borra la base de datos y la crea como al principio (tus ficheros no se tocan) |

## Qué tocas tú

| Bloque | Fichero |
|---|---|
| 1 · Usuarios y permisos | `sql/bloque1.sql` y `predicciones.txt` |
| 2 · La web y la API, conectadas | `servidor/inventario.env`, `web/inc/db.php` y `app/app.py` |
| 3 · Consultas preparadas | `web/buscar.php`, `app/app.py` y `predicciones.txt` |
| 4 · Copia y restauración | `servidor/copia.sh` y `predicciones.txt` |
| 5 · La configuración en Git | `servidor/` (con `./bateria.sh admin`) |
| 6 · Integrador: las incidencias | `app/app.py` |
| ✍️ | `respuestas.md` |

Haz primero el bloque 1 y después el 2: los demás necesitan que la web y la API ya entren en la base de datos. El 5 (Git)
se puede hacer en cualquier momento.

Cada hueco está marcado con ✍️ y lleva sus instrucciones dentro del fichero. Lo marcado con 👀 ya está resuelto: léelo.
No toques `comprobador/`, `compose.yaml`, `sql/01-inventario.sql` ni los `Dockerfile`.

**Recuerda:** PHP lee `db.php` e `inventario.env` en cada petición; Python, al arrancar. Si cambias `app.py` o
`inventario.env`, hace falta `./bateria.sh recargar` (o `comprobar`, que ya lo hace) para que la API lo vea.

**Puertos:** 8089 (HTTP) y 8450 (HTTPS). No chocan con el laboratorio de clase (8085/8449).

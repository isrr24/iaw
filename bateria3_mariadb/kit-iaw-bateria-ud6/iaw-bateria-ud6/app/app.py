# API del inventario del aula (UD6): los equipos y las incidencias, en JSON, sacados de MariaDB con PyMySQL.
# Lee la conexión del entorno (servidor/inventario.env, al arrancar). Si cambias algo: ./bateria.sh recargar
import os
import pymysql
from flask import Flask, jsonify, request

app = Flask(__name__)
app.json.ensure_ascii = False          # las tildes, tal cual en el JSON


# ✍️ 2.3 Faltan dos datos: QUIÉN y CON QUÉ CONTRASEÑA (user= y password=). Sácalos del entorno, como host y database.
#        Nada escrito a mano: lo que haya en inventario.env.
def conectar():
    return pymysql.connect(
        host=os.environ["DB_HOST"], database=os.environ["DB_NAME"],
        charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,   # cada fila, un diccionario
    )


@app.route("/api/salud")
def salud():
    # 👀 No usa la base de datos: si contesta, Nginx le pasa bien /api/ a Gunicorn.
    return jsonify({"ok": True})


@app.route("/api/equipos")
def equipos():
    with conectar() as c, c.cursor() as cur:
        cur.execute("SELECT id, codigo, tipo, aula, estado FROM equipos ORDER BY aula, codigo")
        filas = cur.fetchall()
        cur.execute("SELECT CURRENT_USER() AS yo")
        yo = cur.fetchone()["yo"]
    return jsonify({"conectado_como": yo, "equipos": filas})


@app.route("/api/equipos/<int:id>")
def equipo(id):
    # 👀 Así se hace en Python: el SQL con %s y el dato APARTE, en una tupla. Nunca pegado dentro del SQL.
    with conectar() as c, c.cursor() as cur:
        cur.execute("SELECT id, codigo, tipo, aula, estado FROM equipos WHERE id = %s", (id,))
        fila = cur.fetchone()
    if fila is None:
        return jsonify({"error": "No existe ese equipo"}), 404
    return jsonify(fila)


@app.route("/api/buscar")
def buscar():
    aula = request.args.get("aula", "")
    # ⚠️ ASÍ VIENE: el texto del usuario se pega dentro del SQL (f-string) → inyección SQL.
    # ✍️ 3.2 Como en equipo(), justo encima: %s en el SQL y el dato aparte, en una tupla.
    with conectar() as c, c.cursor() as cur:
        cur.execute(f"SELECT codigo, tipo, aula, estado FROM equipos WHERE aula = '{aula}' ORDER BY codigo")
        return jsonify(cur.fetchall())


@app.route("/api/incidencias", methods=["GET", "POST"])
def incidencias():
    # ✍️ 6 · Integrador. Usa la tabla incidencias que creaste en el 1.3.
    #
    # GET  → la lista de incidencias, la más nueva primero:
    #        [{"id": 2, "equipo_id": 3, "descripcion": "…"}, …]       (jsonify de lo que da fetchall)
    #
    # POST → recibe un JSON {"equipo_id": 3, "descripcion": "No enciende"}  (datos = request.get_json(silent=True) or {})
    #        - descripción vacía o que falta                → {"error": "…"}, 422
    #        - equipo_id que no es de ningún equipo         → {"error": "…"}, 422   (búscalo en equipos, con %s)
    #        - si todo está bien: INSERT con %s, c.commit() y {"id": cur.lastrowid}, 201
    #
    # Todo con consultas preparadas: la descripción la escribe cualquiera.
    return jsonify({"error": "Sin hacer todavía"}), 501

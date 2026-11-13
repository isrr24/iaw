# Ayudante del comprobador (se ejecuta dentro del contenedor «app»). Lee la respuesta por la entrada estándar.
#   texto ID      → el texto del elemento con ese id
#   errores       → los avisos <p class="error">, uno por línea
#   json          → «LISTA n d» (n pistas, d disponibles) · «OBJETO nombre» · «OBJETO-ERROR texto» · «NO_JSON»
#   forjar LLAVE  → una cookie de sesión del conserje firmada con esa llave
import sys, json, re
from html.parser import HTMLParser

modo = sys.argv[1]
if modo == "forjar":
    from flask import Flask
    from flask.sessions import SecureCookieSessionInterface
    a = Flask("forja"); a.secret_key = sys.argv[2]
    print(SecureCookieSessionInterface().get_signing_serializer(a).dumps({"usuario": "conserje"}))
    sys.exit()

datos = sys.stdin.read()

class Lector(HTMLParser):
    def __init__(self, id_buscado):
        super().__init__(); self.id = id_buscado; self.prof = 0; self.texto = []; self.errores = []; self.en_error = False
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if self.prof: self.prof += 1
        elif self.id and a.get("id") == self.id: self.prof = 1
        if tag == "p" and a.get("class") == "error": self.en_error = True; self.errores.append("")
    def handle_endtag(self, tag):
        if self.prof: self.prof -= 1
        if tag == "p": self.en_error = False
    def handle_data(self, d):
        if self.prof: self.texto.append(d)
        if self.en_error: self.errores[-1] += d

if modo in ("texto", "errores"):
    l = Lector(sys.argv[2] if modo == "texto" else None); l.feed(datos)
    if modo == "texto": print(re.sub(r"\s+", " ", "".join(l.texto)).strip())
    else: print("\n".join(e.strip() for e in l.errores))
elif modo == "json":
    try:
        j = json.loads(datos)
    except ValueError:
        print("NO_JSON"); sys.exit()
    if isinstance(j, list):
        print("LISTA", len(j), sum(1 for p in j if isinstance(p, dict) and p.get("disponible") is True))
    elif isinstance(j, dict) and "error" in j:
        print("OBJETO-ERROR", j["error"])
    elif isinstance(j, dict):
        print("OBJETO", j.get("nombre", "?"))
    else:
        print("OTRO")

# Configuración de Gunicorn (el cocinero de Python). Si la cambias: ./bateria.sh recargar
bind = "0.0.0.0:8000"          # 👀 dónde escucha: Nginx le llama a app:8000
timeout = 30                   # 👀 5.1 segundos que se espera a un worker antes de matarlo y arrancar otro
accesslog = "/var/log/lab/gunicorn-acceso.log"   # 👀 cada petición, una línea

# ✍️ 5.3 Cuántos workers. El servidor de producción del polideportivo tiene 4 CPU (no mires las de tu ordenador).
workers = 1

# ✍️ 5.4 Los errores de la app, al fichero /var/log/lab/gunicorn-errores.log (en tu kit: logs/gunicorn-errores.log).
#        Es la misma idea que accesslog, con otra palabra.

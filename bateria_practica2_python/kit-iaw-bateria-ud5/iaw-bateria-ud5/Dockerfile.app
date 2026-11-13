# UD5 (Python) — Gunicorn + Flask de laboratorio, IAW ASIR 2.º
# Imagen oficial de Python + procps (para ver los workers con ps). Las librerías van en la imagen, como en un
# servidor real (en un servidor sin Docker irían en un entorno virtual: python3 -m venv).
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends procps nano \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir flask==3.0.3 gunicorn==23.0.0
EXPOSE 8000

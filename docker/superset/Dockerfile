FROM apache/superset:latest

# PostgreSQL sürücüsünü (psycopg2-binary) Superset sanal ortamına kur
USER root
RUN pip install --no-cache-dir --prefix /app/.venv psycopg2-binary
USER superset


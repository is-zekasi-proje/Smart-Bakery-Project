-- PostgreSQL başlangıç betiği
-- smartbakery_db veritabanı POSTGRES_DB ortam değişkeni ile otomatik oluşturulur.
-- Bu betik Superset için gerekli metadata veritabanını ve yetkileri hazırlar.

CREATE DATABASE superset;
GRANT ALL PRIVILEGES ON DATABASE smartbakery_db TO postgres;
GRANT ALL PRIVILEGES ON DATABASE superset TO postgres;


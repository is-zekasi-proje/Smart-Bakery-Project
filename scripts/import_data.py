"""
Smart Bakery - PostgreSQL Veri Aktarım Betiği (import_data.py)

dbt tarafından üretilen Mart tablolarını (Parquet veya DuckDB)
Docker üzerinde koşan PostgreSQL 'smartbakery_db' veritabanına aktarır.

Kullanım:
    python scripts/import_data.py
    veya
    python import_data.py

Parametreler (opsiyonel):
    --source     : 'parquet' (varsayılan), 'duckdb' veya 'auto'
    --host       : PostgreSQL sunucu adresi (varsayılan: localhost / env: POSTGRES_HOST)
    --port       : PostgreSQL portu (varsayılan: 5433 / env: POSTGRES_PORT)
    --db         : Veritabanı adı (varsayılan: smartbakery_db / env: POSTGRES_DB)
    --user       : Kullanıcı adı (varsayılan: postgres / env: POSTGRES_USER)
    --password   : Şifre (varsayılan: postgres / env: POSTGRES_PASSWORD)
    --schema     : Hedef şema (varsayılan: public / env: POSTGRES_SCHEMA)
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

# Proje dizin kökü
PROJECT_ROOT = Path(__file__).resolve().parent.parent
MARTS_DIR = PROJECT_ROOT / "data" / "marts"
DUCKDB_PATH = PROJECT_ROOT / "data" / "bakery.duckdb"

# Aktarılacak mart tabloları ve birincil anahtarları (PK)
MART_TABLES: Dict[str, Optional[str]] = {
    "dim_musteriler": "musteri_id",
    "dim_urunler": "urun_adi",
    "dim_tarih": "tarih",
    "dim_musteri_rfm": "musteri_id",
    "fct_satislar": "siparis_kalem_id",
    "fct_israf_ve_fire_analizi": "israf_kayit_id",
    "fct_ideal_uretim_tavsiyesi": "tavsiye_id",
}

# Tablolar için performans indeksleri
TABLE_INDEXES: Dict[str, List[str]] = {
    "fct_satislar": [
        "siparis_tarihi",
        "musteri_id",
        "urun_adi",
        "magaza_id",
    ],
    "fct_israf_ve_fire_analizi": [
        "siparis_tarihi",
        "magaza_id",
        "urun_adi",
    ],
    "fct_ideal_uretim_tavsiyesi": [
        "magaza_id",
        "urun_adi",
        "haftanin_gunu",
    ],
    "dim_musteri_rfm": [
        "rfm_segmenti",
        "r_skoru",
        "f_skoru",
        "m_skoru",
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parquet veya DuckDB verilerini PostgreSQL'e aktarır."
    )
    parser.add_argument(
        "--source",
        choices=["auto", "parquet", "duckdb"],
        default="auto",
        help="Veri kaynağı (varsayılan: auto)",
    )
    parser.add_argument(
        "--host",
        default=os.getenv("POSTGRES_HOST", "localhost"),
        help="PostgreSQL host (varsayılan: localhost)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("POSTGRES_PORT", "5433")),
        help="PostgreSQL port (varsayılan: 5433)",
    )
    parser.add_argument(
        "--db",
        default=os.getenv("POSTGRES_DB", "smartbakery_db"),
        help="PostgreSQL veritabanı (varsayılan: smartbakery_db)",
    )
    parser.add_argument(
        "--user",
        default=os.getenv("POSTGRES_USER", "postgres"),
        help="PostgreSQL kullanıcı adı (varsayılan: postgres)",
    )
    parser.add_argument(
        "--password",
        default=os.getenv("POSTGRES_PASSWORD", "postgres"),
        help="PostgreSQL şifre (varsayılan: postgres)",
    )
    parser.add_argument(
        "--schema",
        default=os.getenv("POSTGRES_SCHEMA", "public"),
        help="Hedef PostgreSQL şeması (varsayılan: public)",
    )
    return parser.parse_args()


def check_dependencies() -> None:
    """Gerekli Python kütüphanelerini kontrol eder."""
    missing = []
    try:
        import pandas  # noqa: F401
    except ImportError:
        missing.append("pandas")

    try:
        import sqlalchemy  # noqa: F401
    except ImportError:
        missing.append("sqlalchemy")

    try:
        import psycopg2  # noqa: F401
    except ImportError:
        missing.append("psycopg2-binary")

    if missing:
        print("[HATA] Eksik Python kütüphaneleri tespit edildi:")
        for pkg in missing:
            print(f"  - {pkg}")
        print("\nLütfen şu komutla yükleyin:")
        print(f"    pip install {' '.join(missing)}")
        sys.exit(1)


def get_db_engine(args: argparse.Namespace):
    """SQLAlchemy veritabanı motorunu oluşturur ve bağlantıyı test eder."""
    from sqlalchemy import create_engine, text

    uri = f"postgresql+psycopg2://{args.user}:{args.password}@{args.host}:{args.port}/{args.db}"
    engine = create_engine(uri, pool_pre_ping=True)

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
    except Exception as e:
        print(f"\n[HATA] PostgreSQL sunucusuna bağlanılamadı ({args.host}:{args.port}/{args.db})")
        print(f"Hata detayı: {e}\n")
        print("Lütfen Docker servislerinin çalıştığından emin olun:")
        print("    docker compose up -d postgres")
        print("    # veya tüm servisler için: docker compose up -d")
        sys.exit(1)

    return engine


def load_from_parquet(table_name: str):
    """Parquet dosyasını okuyup pandas DataFrame döner."""
    import pandas as pd

    parquet_file = MARTS_DIR / f"{table_name}.parquet"
    if not parquet_file.exists():
        raise FileNotFoundError(f"Parquet dosyası bulunamadı: {parquet_file}")

    df = pd.read_parquet(parquet_file)
    return df


def load_from_duckdb(table_name: str):
    """DuckDB veritabanından tabloyu okur."""
    try:
        import duckdb
    except ImportError:
        print("[HATA] DuckDB'den veri okumak için 'duckdb' paketi gereklidir.")
        sys.exit(1)

    if not DUCKDB_PATH.exists():
        raise FileNotFoundError(f"DuckDB veritabanı bulunamadı: {DUCKDB_PATH}")

    with duckdb.connect(str(DUCKDB_PATH), read_only=True) as con:
        # Önce 'main.<tablo>' veya doğrudan '<tablo>' olup olmadığını ara
        tables = con.execute("SHOW TABLES").fetchall()
        table_names = [t[0] for t in tables]

        if table_name in table_names:
            df = con.execute(f"SELECT * FROM {table_name}").df()
        else:
            # Şema araması
            schemas = con.execute(
                f"SELECT table_schema, table_name FROM information_schema.tables WHERE table_name = '{table_name}'"
            ).fetchall()
            if schemas:
                schema_name, t_name = schemas[0]
                df = con.execute(f"SELECT * FROM {schema_name}.{t_name}").df()
            else:
                raise ValueError(f"'{table_name}' tablosu DuckDB içinde bulunamadı.")

    return df


def add_constraints_and_indexes(engine, schema: str, table_name: str, pk_col: Optional[str]) -> None:
    """Tabloya birincil anahtar (PK) ve performans indeksleri ekler."""
    from sqlalchemy import text

    with engine.begin() as conn:
        # Birincil Anahtar Ekle
        if pk_col:
            try:
                pk_constraint_name = f"pk_{table_name}_{pk_col}"
                # Önce var olan kısıtı düşürmeyi dene (idempotent)
                conn.execute(
                    text(f"ALTER TABLE {schema}.{table_name} DROP CONSTRAINT IF EXISTS {pk_constraint_name}")
                )
                conn.execute(
                    text(f"ALTER TABLE {schema}.{table_name} ADD CONSTRAINT {pk_constraint_name} PRIMARY KEY ({pk_col})")
                )
            except Exception as e:
                print(f"    [UYARI] PK kısıtı eklenirken not: {e}")

        # İndeksleri Ekle
        if table_name in TABLE_INDEXES:
            for col in TABLE_INDEXES[table_name]:
                try:
                    idx_name = f"idx_{table_name}_{col}"
                    conn.execute(
                        text(f"CREATE INDEX IF NOT EXISTS {idx_name} ON {schema}.{table_name} ({col})")
                    )
                except Exception as e:
                    print(f"    [UYARI] İndeks ({col}) eklenirken not: {e}")


def main() -> None:
    args = parse_args()
    check_dependencies()

    from sqlalchemy import text

    print("=" * 65)
    print(" Smart Bakery -> PostgreSQL Veri Aktarımı")
    print("=" * 65)
    print(f"Hedef Veritabanı : {args.host}:{args.port}/{args.db} (Şema: {args.schema})")

    # 1. Kaynak Tespiti
    source = args.source
    if source == "auto":
        # Parquet dosyaları varsa Parquet tercih et
        has_parquet = all((MARTS_DIR / f"{t}.parquet").exists() for t in MART_TABLES)
        if has_parquet:
            source = "parquet"
        elif DUCKDB_PATH.exists():
            source = "duckdb"
        else:
            print("[HATA] Ne data/marts/*.parquet ne de data/bakery.duckdb bulunabildi!")
            print("Lütfen önce dbt modellerini çalıştırın: cd firin_dbt && dbt build")
            sys.exit(1)

    print(f"Veri Kaynağı    : {source.upper()} ({MARTS_DIR if source == 'parquet' else DUCKDB_PATH})")
    print("-" * 65)

    # 2. Bağlantı Kur
    engine = get_db_engine(args)

    # Hedef şemayı oluştur (yoksa)
    with engine.begin() as conn:
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {args.schema}"))

    # 3. Tabloları Aktar
    start_time = time.time()
    summary = []

    for table_name, pk_col in MART_TABLES.items():
        table_start = time.time()
        print(f"-> Aktarılıyor: {table_name}...")

        try:
            if source == "parquet":
                df = load_from_parquet(table_name)
            else:
                df = load_from_duckdb(table_name)

            row_count = len(df)
            col_count = len(df.columns)

            # PostgreSQL'e yaz (replace modu)
            df.to_sql(
                name=table_name,
                con=engine,
                schema=args.schema,
                if_exists="replace",
                index=False,
                chunksize=2500,
                method="multi",
            )

            # Birincil anahtar ve indeksleri tanımla
            add_constraints_and_indexes(engine, args.schema, table_name, pk_col)

            # Doğrulama sorgusu
            with engine.connect() as conn:
                verified_count = conn.execute(
                    text(f"SELECT COUNT(*) FROM {args.schema}.{table_name}")
                ).scalar()

            elapsed = time.time() - table_start
            print(f"   [TAMAM] {verified_count:,} satır, {col_count} sütun aktarıldı ({elapsed:.2f} sn)")
            summary.append((table_name, verified_count, col_count, f"{elapsed:.2f}s"))

        except Exception as e:
            print(f"   [HATA] {table_name} aktarılırken hata oluştu: {e}")
            raise e

    total_elapsed = time.time() - start_time
    print("-" * 65)
    print("Aktarım Özeti:")
    print(f"{'Tablo Adı':<20} {'Satır Sayısı':<15} {'Sütun':<8} {'Süre':<8}")
    print("-" * 65)
    for t_name, rows, cols, duration in summary:
        print(f"{t_name:<20} {rows:<15,} {cols:<8} {duration:<8}")
    print("-" * 65)
    print(f"Tüm mart tabloları başarıyla '{args.db}' veritabanına aktarıldı! (Toplam: {total_elapsed:.2f} sn)")
    print("\nArtık DBeaver ile bağlanabilir veya Superset üzerinde dashboard oluşturabilirsiniz:")
    print(f"  - DBeaver URL : localhost:{args.port}/{args.db}")
    print("  - Superset UI : http://localhost:8088")
    print("=" * 65)


if __name__ == "__main__":
    main()


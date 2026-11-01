"""
Ham fırın satış verisini (CSV) DuckDB analitik veritabanına aktarır.

Çalıştırma (proje kök klasöründen):
    python scripts/load_raw_data.py

Sonuç: data/bakery.duckdb dosyasında raw.bakery_sales tablosu oluşur.
Tablo her çalıştırmada baştan kurulur; script'i tekrar çalıştırmak güvenlidir.
"""
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = PROJECT_ROOT / "data" / "raw" / "bakery_sales_dataset.csv"
DB_PATH = PROJECT_ROOT / "data" / "bakery.duckdb"


def main() -> None:
    if not CSV_PATH.exists():
        raise FileNotFoundError(f"Ham veri bulunamadı: {CSV_PATH}")

    with duckdb.connect(str(DB_PATH)) as con:
        # Ham veri "raw" şemasında tutulur; temizlik dbt staging katmanında yapılır.
        con.execute("CREATE SCHEMA IF NOT EXISTS raw")

        # Değerler CSV'deki gibi aktarılır, yalnızca sütun tipleri otomatik algılanır.
        # _loaded_at: verinin ne zaman yüklendiğini gösteren yükleme bilgisi.
        con.execute(f"""
            CREATE OR REPLACE TABLE raw.bakery_sales AS
            SELECT *, current_timestamp AS _loaded_at
            FROM read_csv('{CSV_PATH}', header = true)
        """)

        row_count = con.execute("SELECT count(*) FROM raw.bakery_sales").fetchone()[0]
        col_count = len(con.execute("DESCRIBE raw.bakery_sales").fetchall())

    if row_count == 0:
        raise RuntimeError("raw.bakery_sales tablosu boş yüklendi.")

    print(f"Yüklendi: raw.bakery_sales -> {row_count} satır, {col_count} sütun ({DB_PATH.name})")


if __name__ == "__main__":
    main()

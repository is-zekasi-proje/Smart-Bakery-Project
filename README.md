# Smart Bakery

Üç mağazalı bir fırının 2023-2024 satış verisi üzerinde kurulan uçtan uca veri projesi. Veri DuckDB'ye
yüklenir, dbt ile temizlenip analize hazır tablolara dönüştürülür; bu tablolar dashboard ve tahmin modeli
için kullanılır.

## Veri

Eğitmen onaylı fırın satış veri seti: `data/raw/bakery_sales_dataset.csv`

19.321 satır (sipariş kalemi), 6.576 sipariş, 500 müşteri, 35 ürün ve 3 mağaza içerir; 2023-01-01 ile
2024-12-31 arasını kapsar. Sütun açıklamaları `docs/veri_sozlugu.md` dosyasındadır.

## Veri akışı

1. `scripts/load_raw_data.py`, CSV dosyasını DuckDB'deki `raw.bakery_sales` tablosuna yükler.
2. dbt staging katmanı (`stg_firin_satislari`) sütunları yeniden adlandırır, tipleri düzeltir ve boş değerleri doldurur.
3. dbt mart katmanı dört tablo üretir:
   - `fct_satislar`: her satır bir sipariş kalemi
   - `dim_musteriler`: müşteri bilgileri ve satın alma özeti
   - `dim_urunler`: ürün bilgileri, satış ve fire özeti
   - `dim_tarih`: takvim, mevsim, festival ve hava bilgisi
4. Mart tabloları `data/marts/` klasörüne Parquet dosyası olarak da yazılır. Dashboard ve model bu dosyaları kullanır.

## Kullanılan araçlar

- DuckDB: kurulum gerektirmeyen, tek dosyalık analitik veritabanı.
- dbt Core 1.12 ve dbt-duckdb: katmanlı, test edilen ve dokümante edilen dönüşümler için. dbt-duckdb adaptörü
  dbt v1 için geliştirildiğinden v1 kullanılıyor.
- Parquet: Power BI'ın okuyabildiği ve sütun tiplerini koruyan dosya formatı. Türkçe bölge ayarlarında CSV'deki
  ondalık ayıracı sorun çıkarabildiği için CSV yerine tercih edildi.
- Python 3.12

## Klasörler

- `data/raw/`: ham veri
- `data/marts/`: dbt çıktısı (Parquet)
- `scripts/`: veri yükleme ve dokümantasyon scriptleri
- `firin_dbt/`: dbt projesi (modeller, testler, makrolar)
- `docs/`: dbt docs sayfası ve veri sözlüğü

## Kurulum ve çalıştırma

Python 3.11 veya üstü gerekir (`python3 --version` ile kontrol edilebilir). macOS'taki hazır python3 genellikle
3.9 olduğu için python.org'dan 3.12 kurulması önerilir.

```bash
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

python scripts/load_raw_data.py    # data/bakery.duckdb oluşturulur

cd firin_dbt
dbt build                          # modeller, testler ve Parquet çıktıları
dbt docs generate --static
cd ..
python scripts/generate_docs.py    # docs/ klasörünü günceller
```

dbt komutları `firin_dbt/` klasörünün içinden çalıştırılmalıdır.

## Testler

`dbt build` sırasında 49 test çalışır: tekillik, boş değer, kabul edilen değerler, tablolar arası ilişki ve değer
aralığı kontrolleri. Bunlara ek olarak tutar ve kâr hesaplamalarını, staging ile mart tabloları arasındaki satır
sayısı ve ciro eşitliğini kontrol eden testler vardır.

## Dokümantasyon

- `docs/dbt_docs.html`: dbt docs sayfası (indirilip tarayıcıda açılabilir)
- `docs/veri_sozlugu.md`: veri sözlüğü

{% docs __overview__ %}
# Smart Bakery dbt Projesi

Bu proje, üç mağazalı bir fırının 2023-2024 satış verisini ham hâlinden analize hazır tablolara dönüştürür.
Veri DuckDB veritabanında tutulur, dönüşümler dbt ile yapılır.

## Veri akışı

1. `scripts/load_raw_data.py` CSV dosyasını `raw.bakery_sales` tablosuna yükler.
2. `staging.stg_firin_satislari` ham veriyi temizler: sütunları Türkçe adlandırır, tipleri düzeltir, boş değerleri doldurur.
3. `marts` şemasındaki tablolar dashboard ve model için hazırlanır:
   - `fct_satislar`: satış olgu tablosu, her satır bir sipariş kalemi
   - `fct_israf_ve_fire_analizi`: mağaza, ürün ve gün bazında satış, israf ve fire maliyeti
   - `fct_ideal_uretim_tavsiyesi`: mağaza, ürün ve haftanın günü bazında üretim önerisi
   - `dim_musteriler`: müşteri bilgileri ve satın alma özeti
   - `dim_musteri_rfm`: müşteri RFM ölçümleri ve dokuz segmentli sınıflandırma
   - `dim_urunler`: ürün bilgileri, satış ve fire özeti
   - `dim_tarih`: takvim, mevsim, festival ve hava bilgisi
4. Mart tabloları `data/marts/` klasörüne Parquet dosyası olarak da yazılır.

## Kullanım notları

- Stok ve fire sütunları (`uretilen_adet`, `satilan_adet`, `fire_orani` vb.) satıra ait anlık bilgilerdir;
  satırlar arasında toplanmamalı, ortalaması alınmalıdır.
- `musteri_puani` sipariş düzeyinde verilir; ortalama için `dim_musteriler.ortalama_puan` kullanılmalıdır.
- Sipariş sayısı için `count(distinct siparis_id)` kullanılmalıdır, çünkü bir sipariş birden fazla satırdan oluşur.
- Kategori değerleri (Female, Winter, Cash vb.) kaynaktaki gibi İngilizcedir.
{% enddocs %}

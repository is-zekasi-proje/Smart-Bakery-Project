# Mutabakat Raporu

Bu rapor, `data/bakery.duckdb` üzerinde 10 Kasım 2026'da çalıştırılan sorguların ve `dbt test` çıktısının sonuçlarını içerir. Rakamların hepsi bu çıktılardan alınmıştır.

## 1. Veri akışı boyunca satır ve ciro mutabakatı

| Katman | Tablo | Satır sayısı | Toplam ciro (`toplam_tutar`) |
|---|---|---|---|
| Ham | `raw.bakery_sales` | 19.321 | (ham tabloda ciro sütunu karşılaştırılmadı) |
| Staging | `staging.stg_firin_satislari` | 19.321 | 2.690.806,05 |
| Mart | `marts.fct_satislar` | 19.321 | 2.690.806,05 |

Sonuç: ham, staging ve mart katmanlarında satır sayısı aynıdır (19.321). Staging ile `fct_satislar` arasında satır kaybı veya çoğalması yoktur; ciro toplamları da eşittir. Ciro, ekipçe paylaşılan beklenen kontrol değeriyle (2.690.806,05) eşleşmektedir.

## 2. Müşteri özeti mutabakatı

| Ölçüt | `dim_musteriler` | `fct_satislar` | Eşit mi |
|---|---|---|---|
| Toplam harcama | 2.690.806,05 | 2.690.806,05 | Evet |
| Sipariş sayısı (toplam / tekil `siparis_id`) | 6.576 | 6.576 | Evet |
| Müşteri sayısı | 500 | 500 (tekil `musteri_id`) | Evet |

## 3. Kalem düzeyi iş kuralı

Kural: her kalemde `toplam_tutar = satis_fiyati × adet` ve `kar = toplam_tutar − toplam_maliyet` olmalıdır (tolerans 0,01).

- Kuralı ihlal eden satır sayısı: **0**
- En büyük sapma (tutar): 0,00
- En büyük sapma (kâr): 0,00

## 4. Kâr ve fire kontrol sayıları

**Toplam kâr.** Dört tabloda da aynı değer çıkmıştır; paylaşılan beklenen kontrol değeri (1.143.737,55) ile eşleşmektedir.

| Tablo | Sütun | Toplam |
|---|---|---|
| `marts.fct_satislar` | `kar` | 1.143.737,55 |
| `marts.dim_musteriler` | `toplam_kar` | 1.143.737,55 |
| `marts.dim_musteri_rfm` | `toplam_kar` | 1.143.737,55 |
| `marts.dim_urunler` | `toplam_kar` | 1.143.737,55 |

**Ortalama fire oranı.** Tanıma ve tabloya göre farklı değerler çıkmaktadır. Paylaşılan beklenen değer (%34,1) ilk iki satırla eşleşmektedir.

| Tablo | Hesap | Sonuç (%) |
|---|---|---|
| `staging.stg_firin_satislari` | `avg(fire_orani)` (kalem bazında) | 34,12 |
| `marts.fct_satislar` | `avg(fire_orani)` (kalem bazında) | 34,12 |
| `marts.fct_israf_ve_fire_analizi` | `avg(fire_orani)` (mağaza-ürün-gün bazında) | 36,19 |
| `marts.fct_israf_ve_fire_analizi` | `sum(satilmayan_adet) / sum(uretilen_adet) × 100` | 30,55 |
| `marts.dim_urunler` | `avg(ortalama_fire_orani)` (ürün bazında) | 35,81 |
| `marts.fct_ideal_uretim_tavsiyesi` | `avg(ortalama_gecmis_fire_orani)` | 37,41 |

Not: "ortalama fire" metriği dashboard'da kullanılırken hangi tablo ve hesabın esas alındığı açıkça belirtilmelidir; farklı tanımlar farklı değer verir.

## 5. Veri kapsamı (`fct_satislar`)

| Ölçüt | Değer |
|---|---|
| Tekil sipariş | 6.576 |
| Tekil müşteri | 500 |
| Tekil ürün | 35 |
| Mağaza | 3 |
| Tarih aralığı | 2023-01-01 – 2024-12-31 |

## 6. Mart tablolarının satır sayıları

| Tablo | Satır sayısı |
|---|---|
| `fct_satislar` | 19.321 |
| `fct_israf_ve_fire_analizi` | 16.563 |
| `fct_ideal_uretim_tavsiyesi` | 735 |
| `dim_musteriler` | 500 |
| `dim_musteri_rfm` | 500 |
| `dim_urunler` | 35 |
| `dim_tarih` | 731 |

Bu sayılar README'deki değerlerle birebir aynıdır.

## 7. dbt testleri

`dbt test` (10 Kasım 2026): **PASS=89, WARN=0, ERROR=0, SKIP=0, TOTAL=89**.

Bu testlerin üçü `firin_dbt/tests/` altındaki özel testlerdir:

| Test | Kontrol |
|---|---|
| `assert_fct_staging_mutabakati` | Staging ile `fct_satislar` aynı satır sayısına ve ciroya sahip |
| `assert_musteri_harcamasi_mutabakati` | `dim_musteriler` toplam harcama ve sipariş sayısı `fct_satislar` ile aynı |
| `assert_tutar_ve_kar_tutarli` | Her kalemde tutar ve kâr hesabı tutarlı (iş kuralı) |

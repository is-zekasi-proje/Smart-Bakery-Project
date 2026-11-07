# firin_dbt

Fırın satış verisinin dbt projesi (DuckDB + dbt-duckdb). Kurulum ve genel açıklama için
ana klasördeki [README.md](../README.md) dosyasına bakın.

```bash
dbt build                    # modelleri kur + testleri çalıştır + data/marts/*.parquet yaz
dbt docs generate --static   # dokümantasyonu üret
dbt docs serve               # dokümantasyonu tarayıcıda aç
```

| Klasör | İçerik |
|---|---|
| `models/staging/` | `stg_firin_satislari`: ham verinin temizlenmiş hâli (view) |
| `models/marts/` | `fct_satislar`, `fct_israf_ve_fire_analizi`, `fct_ideal_uretim_tavsiyesi`, `dim_musteriler`, `dim_musteri_rfm`, `dim_urunler`, `dim_tarih` (tablo) |
| `tests/` | İş kuralı ve mutabakat testleri; `generic/deger_araliginda` özel testi |
| `macros/` | Şema adlandırma ve Parquet dışa aktarım makroları |

Proje toplam **8 dbt modelinden** (1 staging + 7 mart) oluşur. Yeni martlar:

- `fct_israf_ve_fire_analizi`: Mağaza, ürün ve gün bazında `satilmayan_adet`,
  `fire_orani`, `fire_maliyeti` ve `potansiyel_ciro_kaybi` metrikleriyle israfı izler.
- `fct_ideal_uretim_tavsiyesi`: Ürün, mağaza ve haftanın gününe göre
  `ortalama_gunluk_satis` ve bozulabilirlik güvenlik payından `tavsiye_edilen_uretim_adedi`,
  `tahmini_uretim_maliyeti` ve `tahmini_potansiyel_ciro` hesaplar.
- `dim_musteri_rfm`: Müşterileri `son_siparisten_gecen_gun`, `siparis_sayisi` ve
  `toplam_harcama` metrikleriyle RFM skorlarına ve segmentlerine ayırır.

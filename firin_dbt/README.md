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
| `models/marts/` | `fct_satislar`, `dim_musteriler`, `dim_urunler`, `dim_tarih` (tablo) |
| `tests/` | İş kuralı ve mutabakat testleri; `generic/deger_araliginda` özel testi |
| `macros/` | Şema adlandırma ve Parquet dışa aktarım makroları |

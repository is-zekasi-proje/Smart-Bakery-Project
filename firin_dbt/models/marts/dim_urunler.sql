-- Ürün boyutu: her ürün için bir satır.
-- Kategori, saklama tipi ve bozulabilirlik ürün düzeyinde sabittir.
-- Fiyat ve raf ömrü satırdan satıra değiştiği için ortalamaları verilir.

with satislar as (

    select * from {{ ref('stg_firin_satislari') }}

)

select
    urun_adi,
    kategori,
    saklama_tipi,
    bozulabilirlik,
    cast(avg(birim_fiyat) as decimal(10, 2))                    as ortalama_birim_fiyat,
    cast(avg(birim_maliyet) as decimal(10, 2))                  as ortalama_birim_maliyet,
    cast(avg(raf_omru_gun) as decimal(6, 1))                    as ortalama_raf_omru_gun,
    cast(sum(adet) as integer)                                  as toplam_satis_adedi,
    cast(sum(toplam_tutar) as decimal(14, 2))                   as toplam_ciro,
    cast(sum(kar) as decimal(14, 2))                            as toplam_kar,
    cast(100 * sum(kar) / sum(toplam_tutar) as decimal(5, 1))   as kar_marji,
    cast(avg(fire_orani) as decimal(5, 1))                      as ortalama_fire_orani

from satislar
group by urun_adi, kategori, saklama_tipi, bozulabilirlik
order by urun_adi

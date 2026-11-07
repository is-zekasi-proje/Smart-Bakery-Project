-- Fırın gıda israfı ve fire olgu tablosu (SmartBakery 360).
-- stg_firin_satislari verilerini kullanarak mağaza, ürün ve tarih bazında
-- satılmayan adet, fire oranı ve fire maliyeti metriklerini hesaplar.
-- Tahıl/unlu mamul israfını en aza indirmek ve sürdürülebilirlik takibi için kullanılır.

with satislar as (

    select * from {{ ref('stg_firin_satislari') }}

),

israf_ozeti as (

    select
        -- Kimlik ve boyutlar
        md5(magaza_id || '|' || urun_adi || '|' || cast(siparis_tarihi as text)) as israf_kayit_id,
        magaza_id,
        urun_adi,
        siparis_tarihi,
        max(kategori)                                               as kategori,
        max(saklama_tipi)                                           as saklama_tipi,
        max(bozulabilirlik)                                         as bozulabilirlik,
        max(raf_omru_gun)                                           as raf_omru_gun,
        max(mevsim)                                                 as mevsim,
        max(hava_durumu)                                            as hava_durumu,

        -- Günlük üretim, satış ve stok
        cast(max(uretilen_adet) as integer)                         as uretilen_adet,
        cast(max(satilan_adet) as integer)                          as satilan_adet,
        cast(max(mevcut_stok) as integer)                           as mevcut_stok,

        -- İsraf ve fire metrikleri
        cast(max(satilmayan_adet) as integer)                       as satilmayan_adet,
        cast(max(fire_orani) as decimal(5, 1))                      as fire_orani,

        -- Fiyat ve maliyet
        cast(avg(birim_maliyet) as decimal(10, 2))                  as birim_maliyet,
        cast(avg(birim_fiyat) as decimal(10, 2))                    as birim_fiyat,

        -- Parasal fire kaybı (satılmayan adet * birim maliyet)
        cast(max(satilmayan_adet) * avg(birim_maliyet) as decimal(12, 2)) as fire_maliyeti,

        -- İsraf potansiyel ciro kaybı (satılmayan adet * birim fiyat)
        cast(max(satilmayan_adet) * avg(birim_fiyat) as decimal(12, 2))   as potansiyel_ciro_kaybi

    from satislar
    group by magaza_id, urun_adi, siparis_tarihi

)

select * from israf_ozeti
order by siparis_tarihi desc, magaza_id, urun_adi

-- Satış olgu tablosu: her satır bir siparişteki bir ürün kalemidir.
-- Boyut tablolarına musteri_id, urun_adi ve siparis_tarihi ile bağlanır.

with satislar as (

    select * from {{ ref('stg_firin_satislari') }}

)

select
    -- Anahtarlar
    siparis_kalem_id,
    siparis_id,
    musteri_id,                                                 -- dim_musteriler
    urun_adi,                                                   -- dim_urunler
    siparis_tarihi,                                             -- dim_tarih
    magaza_id,

    -- Sipariş bilgileri
    siparis_saati,
    siparis_zamani,
    saat,
    odeme_yontemi,
    promosyon_uygulandi_mi,
    promosyon_tipi,
    musteri_puani,

    -- Birim fiyatlar
    birim_fiyat,
    birim_maliyet,
    indirim_orani,
    satis_fiyati,

    -- Kalem tutarları
    adet,
    cast(birim_fiyat * adet as decimal(12, 2))                  as brut_tutar,
    cast(birim_fiyat * adet - toplam_tutar as decimal(12, 2))   as indirim_tutari,
    toplam_tutar,
    cast(birim_maliyet * adet as decimal(12, 2))                as toplam_maliyet,
    kar,

    -- Stok ve fire (satıra ait anlık bilgi; satırlar arasında toplanmamalı)
    raf_omru_gun,
    uretilen_adet,
    satilan_adet,
    satilmayan_adet,
    mevcut_stok,
    fire_orani

from satislar

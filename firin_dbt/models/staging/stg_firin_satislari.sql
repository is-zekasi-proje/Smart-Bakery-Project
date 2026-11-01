-- Ham fırın satış verisini temizler:
--   * sütunları Türkçe ve tutarlı biçimde adlandırır,
--   * tipleri netleştirir (para ve yüzde sütunları DECIMAL),
--   * anlamlı boş değerleri doldurur (festival yok, promosyon yok),
--   * her satır için tekil bir anahtar üretir.
-- Satır düzeyi (grain): bir siparişteki bir ürün kalemi.

with kaynak as (

    select * from {{ source('raw', 'bakery_sales') }}

),

temizlenmis as (

    select
        -- Kimlikler
        md5(Order_ID || '|' || Product)                 as siparis_kalem_id,
        Order_ID                                        as siparis_id,
        Customer_ID                                     as musteri_id,
        Store_ID                                        as magaza_id,

        -- Müşteri
        cast(Customer_Age as integer)                   as musteri_yasi,
        Customer_Gender                                 as musteri_cinsiyeti,
        Customer_Segment                                as musteri_segmenti,
        Loyalty_Member                                  as sadakat_uyesi_mi,

        -- Zaman
        Date                                            as siparis_tarihi,
        Time                                            as siparis_saati,
        Date + Time                                     as siparis_zamani,
        cast(Year as integer)                           as yil,
        cast(Month as integer)                          as ay,
        cast(Day as integer)                            as gun,
        Day_of_Week                                     as haftanin_gunu,
        Weekend                                         as hafta_sonu_mu,
        cast(Hour as integer)                           as saat,
        Season                                          as mevsim,
        coalesce(Festival, 'No Festival')               as festival,

        -- Hava
        Weather                                         as hava_durumu,
        cast(Temperature as decimal(4, 1))              as sicaklik,

        -- Ürün
        Product                                         as urun_adi,
        Category                                        as kategori,
        cast(Shelf_Life_Days as integer)                as raf_omru_gun,
        Storage_Type                                    as saklama_tipi,
        Perishability                                   as bozulabilirlik,

        -- Satış ve fiyat
        cast(Quantity as integer)                       as adet,
        cast(Unit_Price as decimal(10, 2))              as birim_fiyat,
        cast(Cost_Price as decimal(10, 2))              as birim_maliyet,
        cast(Discount_Percentage as decimal(5, 1))      as indirim_orani,
        cast(Selling_Price as decimal(10, 2))           as satis_fiyati,
        cast(Total_Bill as decimal(12, 2))              as toplam_tutar,
        cast(Profit as decimal(12, 2))                  as kar,
        Payment_Method                                  as odeme_yontemi,
        Promotion_Applied                               as promosyon_uygulandi_mi,
        coalesce(Promotion_Type, 'No Promotion')        as promosyon_tipi,
        cast(Customer_Rating as integer)                as musteri_puani,

        -- Stok ve fire (satıra ait anlık stok bilgisi; satırlar arasında toplanmamalı)
        cast(Units_Produced as integer)                 as uretilen_adet,
        cast(Units_Sold as integer)                     as satilan_adet,
        cast(Unsold_Units as integer)                   as satilmayan_adet,
        cast(Stock_Available as integer)                as mevcut_stok,
        cast(Waste_Pct as decimal(5, 1))                as fire_orani,

        -- Yükleme bilgisi
        _loaded_at                                      as _yuklenme_zamani

    from kaynak

)

select * from temizlenmis

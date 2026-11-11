-- İdeal üretim miktarı karar destek tablosu (SmartBakery 360).
-- Ürün, mağaza ve haftanın günü bazında geçmiş ortalama satışları analiz ederek
-- fırın ustasına tavsiye edilen ideal üretim miktarını hesaplar.
-- Bozulabilirlik seviyesine göre dinamik güvenlik stoku tamponu uygular.

with gunluk_satislar as (

    select
        magaza_id,
        urun_adi,
        siparis_tarihi,
        haftanin_gunu,
        case haftanin_gunu
            when 'Monday' then 1
            when 'Tuesday' then 2
            when 'Wednesday' then 3
            when 'Thursday' then 4
            when 'Friday' then 5
            when 'Saturday' then 6
            when 'Sunday' then 7
        end as haftanin_gunu_no,
        hafta_sonu_mu,
        sum(adet)              as gunluk_satilan_adet,
        max(fire_orani)        as gunluk_fire_orani,
        cast(round(sum(birim_maliyet) / count(birim_maliyet), 8) as decimal(18, 8)) as birim_maliyet,
        cast(round(sum(birim_fiyat) / count(birim_fiyat), 8) as decimal(18, 8))     as birim_fiyat
    from {{ ref('stg_firin_satislari') }}
    group by magaza_id, urun_adi, siparis_tarihi, haftanin_gunu, hafta_sonu_mu

),

urun_bilgileri as (

    select
        urun_adi,
        kategori,
        bozulabilirlik,
        saklama_tipi,
        ortalama_raf_omru_gun,
        ortalama_birim_maliyet,
        ortalama_birim_fiyat
    from {{ ref('dim_urunler') }}

),

gecmis_istatistikler as (

    select
        md5(g.magaza_id || '|' || g.urun_adi || '|' || g.haftanin_gunu) as tavsiye_id,
        g.magaza_id,
        g.urun_adi,
        u.kategori,
        u.bozulabilirlik,
        u.saklama_tipi,
        u.ortalama_raf_omru_gun,
        g.haftanin_gunu,
        max(g.haftanin_gunu_no)                                             as haftanin_gunu_no,
        max(g.hafta_sonu_mu)                                                as hafta_sonu_mu,
        count(distinct g.siparis_tarihi)                                    as gozlem_sayisi,
        cast(avg(g.gunluk_satilan_adet) as decimal(10, 2))                  as ortalama_gunluk_satis,
        cast(min(g.gunluk_satilan_adet) as integer)                         as min_gunluk_satis,
        cast(max(g.gunluk_satilan_adet) as integer)                         as max_gunluk_satis,
        cast(avg(g.gunluk_fire_orani) as decimal(5, 1))                     as ortalama_gecmis_fire_orani,
        cast(coalesce(round(sum(g.birim_maliyet) / count(g.birim_maliyet), 2), u.ortalama_birim_maliyet) as decimal(10, 2)) as ortalama_birim_maliyet,
        cast(coalesce(round(sum(g.birim_fiyat) / count(g.birim_fiyat), 2), u.ortalama_birim_fiyat) as decimal(10, 2))     as ortalama_birim_fiyat,

        -- Dengeli başlangıç politikası: kısa raf ömrü ve yüksek fire daha düşük,
        -- uzun raf ömrü stok bulunurluğu için daha yüksek tamponla dengelenir.
        -- Gözlenen stock-out olmadığından oranlar saha verisiyle izlenmelidir.
        case
            when u.bozulabilirlik = 'High' then 0.07
            when u.bozulabilirlik = 'Medium' then 0.10
            when u.bozulabilirlik = 'Low' then 0.12
            when u.bozulabilirlik = 'Very High' then 0.05
            else 0.12
        end as guvenlik_stogu_orani,

        -- Fırın ustasına tavsiye edilen ideal üretim miktarı
        case
            when u.bozulabilirlik = 'High' then cast(ceil(avg(g.gunluk_satilan_adet) * 1.07) as integer)
            when u.bozulabilirlik = 'Medium' then cast(ceil(avg(g.gunluk_satilan_adet) * 1.10) as integer)
            when u.bozulabilirlik = 'Low' then cast(ceil(avg(g.gunluk_satilan_adet) * 1.12) as integer)
            when u.bozulabilirlik = 'Very High' then cast(ceil(avg(g.gunluk_satilan_adet) * 1.05) as integer)
            else cast(ceil(avg(g.gunluk_satilan_adet) * 1.12) as integer)
        end as tavsiye_edilen_uretim_adedi

    from gunluk_satislar as g
    left join urun_bilgileri as u
        on g.urun_adi = u.urun_adi
    group by g.magaza_id, g.urun_adi, u.kategori, u.bozulabilirlik, u.saklama_tipi, u.ortalama_raf_omru_gun, u.ortalama_birim_maliyet, u.ortalama_birim_fiyat, g.haftanin_gunu

)

select
    tavsiye_id,
    magaza_id,
    urun_adi,
    kategori,
    bozulabilirlik,
    ortalama_raf_omru_gun as raf_omru_gun,
    saklama_tipi,
    haftanin_gunu,
    haftanin_gunu_no,
    hafta_sonu_mu,
    gozlem_sayisi,
    ortalama_gunluk_satis,
    min_gunluk_satis,
    max_gunluk_satis,
    ortalama_gecmis_fire_orani,
    guvenlik_stogu_orani,
    tavsiye_edilen_uretim_adedi,
    ortalama_birim_maliyet,
    ortalama_birim_fiyat,
    cast(tavsiye_edilen_uretim_adedi * ortalama_birim_maliyet as decimal(12, 2)) as tahmini_uretim_maliyeti,
    cast(tavsiye_edilen_uretim_adedi * ortalama_birim_fiyat as decimal(12, 2))   as tahmini_potansiyel_ciro

from gecmis_istatistikler
order by magaza_id, urun_adi, haftanin_gunu_no

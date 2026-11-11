-- Müşteri RFM (Recency, Frequency, Monetary) boyut tablosu (SmartBakery 360).
-- dim_musteriler ve fct_satislar modellerini kullanarak her müşteri için
-- son satın almadan geçen gün (Recency), toplam sipariş sayısı (Frequency) ve
-- toplam harcama (Monetary) metriklerini derler, 1-5 arası ntile skorları ve
-- müşteri segmentasyonu atar.

with magaza_siralama as (

    select
        musteri_id,
        magaza_id,
        row_number() over (
            partition by musteri_id
            order by count(*) desc, magaza_id asc
        ) as magaza_sirasi
    from {{ ref('fct_satislar') }}
    group by musteri_id, magaza_id

),

odeme_siralama as (

    select
        musteri_id,
        odeme_yontemi,
        row_number() over (
            partition by musteri_id
            order by count(*) desc, odeme_yontemi asc
        ) as odeme_sirasi
    from {{ ref('fct_satislar') }}
    group by musteri_id, odeme_yontemi

),

satislar as (

    select
        o.musteri_id,
        o.odeme_yontemi as favori_odeme_yontemi,
        m.magaza_id as en_sik_gidilen_magaza
    from odeme_siralama as o
    inner join magaza_siralama as m
        on o.musteri_id = m.musteri_id
    where o.odeme_sirasi = 1
      and m.magaza_sirasi = 1

),

musteriler as (

    select
        musteri_id,
        musteri_yasi,
        yas_grubu,
        musteri_cinsiyeti,
        musteri_segmenti,
        sadakat_uyesi_mi,
        ilk_siparis_tarihi,
        son_siparis_tarihi,
        son_siparisten_gecen_gun,
        siparis_sayisi,
        toplam_harcama,
        toplam_kar,
        toplam_urun_adedi,
        ortalama_sepet_tutari,
        ortalama_puan
    from {{ ref('dim_musteriler') }}

),

rfm_birlestirme as (

    select
        m.musteri_id,
        m.musteri_yasi,
        m.yas_grubu,
        m.musteri_cinsiyeti,
        m.musteri_segmenti,
        m.sadakat_uyesi_mi,
        m.ilk_siparis_tarihi,
        m.son_siparis_tarihi,
        m.son_siparisten_gecen_gun,
        m.siparis_sayisi,
        m.toplam_harcama,
        m.toplam_kar,
        m.toplam_urun_adedi,
        m.ortalama_sepet_tutari,
        m.ortalama_puan,
        s.favori_odeme_yontemi,
        s.en_sik_gidilen_magaza
    from musteriler as m
    left join satislar as s
        on m.musteri_id = s.musteri_id

),

skorlama as (

    select
        *,
        -- R Skoru: Son alışverişi en yakın olan (en küçük gün) en yüksek puanı alır (5)
        ntile(5) over (order by son_siparisten_gecen_gun desc, musteri_id asc) as r_skoru,
        -- F Skoru: Sipariş adedi en çok olan en yüksek puanı alır (5)
        ntile(5) over (order by siparis_sayisi asc, musteri_id asc) as f_skoru,
        -- M Skoru: Harcaması en yüksek olan en yüksek puanı alır (5)
        ntile(5) over (order by toplam_harcama asc, musteri_id asc) as m_skoru
    from rfm_birlestirme

),

segmentasyon as (

    select
        musteri_id,
        musteri_yasi,
        yas_grubu,
        musteri_cinsiyeti,
        musteri_segmenti,
        sadakat_uyesi_mi,
        ilk_siparis_tarihi,
        son_siparis_tarihi,
        son_siparisten_gecen_gun,
        siparis_sayisi,
        toplam_harcama,
        toplam_kar,
        toplam_urun_adedi,
        ortalama_sepet_tutari,
        ortalama_puan,
        favori_odeme_yontemi,
        en_sik_gidilen_magaza,
        r_skoru,
        f_skoru,
        m_skoru,
        cast(r_skoru as text) || cast(f_skoru as text) || cast(m_skoru as text) as rfm_skoru,
        cast((r_skoru + f_skoru + m_skoru) / 3.0 as decimal(3, 2))              as rfm_ortalama_skor,
        case
            when r_skoru >= 4 and f_skoru >= 4 and m_skoru >= 4 then 'Şampiyonlar'
            when r_skoru >= 3 and f_skoru >= 3 then 'Sadık Müşteriler'
            when r_skoru >= 4 and f_skoru = 1 then 'Yeni Müşteriler'
            when r_skoru >= 4 and f_skoru <= 2 then 'Potansiyel Sadıklar'
            when r_skoru = 3 and f_skoru <= 2 then 'Gelişime Açık'
            when r_skoru <= 2 and f_skoru >= 4 then 'Kaybedilme Riski Yüksek'
            when r_skoru <= 2 and f_skoru = 3 then 'Dikkat Gerektirenler'
            when r_skoru <= 2 and f_skoru <= 2 and m_skoru >= 3 then 'Uykudaki Değerliler'
            else 'Kayıp Müşteriler'
        end as rfm_segmenti

    from skorlama

)

select * from segmentasyon
order by rfm_ortalama_skor desc, toplam_harcama desc

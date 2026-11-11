with beklenen_segmentler as (

    select *
    from (
        values
            ('Şampiyonlar'),
            ('Sadık Müşteriler'),
            ('Yeni Müşteriler'),
            ('Potansiyel Sadıklar'),
            ('Gelişime Açık'),
            ('Kaybedilme Riski Yüksek'),
            ('Dikkat Gerektirenler'),
            ('Uykudaki Değerliler'),
            ('Kayıp Müşteriler')
    ) as segmentler(rfm_segmenti)

),

segment_sayilari as (

    select
        rfm_segmenti,
        count(*) as musteri_sayisi
    from {{ ref('dim_musteri_rfm') }}
    group by rfm_segmenti

)

select
    beklenen.rfm_segmenti,
    coalesce(mevcut.musteri_sayisi, 0) as musteri_sayisi
from beklenen_segmentler as beklenen
left join segment_sayilari as mevcut
    on beklenen.rfm_segmenti = mevcut.rfm_segmenti
where coalesce(mevcut.musteri_sayisi, 0) < 1

-- Müşteri boyutu: her müşteri için bir satır.
-- Demografik bilgilere ek olarak satın alma davranışı özetlenir
-- (sipariş sayısı, harcama, son siparişten bu yana geçen gün vb.).

with satislar as (

    select * from {{ ref('stg_firin_satislari') }}

),

-- Puan sipariş düzeyinde verildiği için önce siparişler tekilleştirilir.
siparisler as (

    select
        siparis_id,
        musteri_id,
        siparis_tarihi,
        musteri_puani,
        sum(adet)                                       as urun_adedi,
        sum(toplam_tutar)                               as siparis_tutari,
        sum(kar)                                        as siparis_kari
    from satislar
    group by siparis_id, musteri_id, siparis_tarihi, musteri_puani

),

musteri_bilgileri as (

    select distinct
        musteri_id,
        musteri_yasi,
        musteri_cinsiyeti,
        musteri_segmenti,
        sadakat_uyesi_mi
    from satislar

),

davranis as (

    select
        musteri_id,
        min(siparis_tarihi)                             as ilk_siparis_tarihi,
        max(siparis_tarihi)                             as son_siparis_tarihi,
        count(*)                                        as siparis_sayisi,
        cast(sum(urun_adedi) as integer)                as toplam_urun_adedi,
        cast(sum(siparis_tutari) as decimal(14, 2))     as toplam_harcama,
        cast(sum(siparis_kari) as decimal(14, 2))       as toplam_kar,
        cast(avg(siparis_tutari) as decimal(10, 2))     as ortalama_sepet_tutari,
        cast(avg(musteri_puani) as decimal(3, 2))       as ortalama_puan
    from siparisler
    group by musteri_id

),

-- "Son siparişten geçen gün" bugüne göre değil, verinin son gününe göre hesaplanır.
veri_son_tarihi as (

    select max(siparis_tarihi) as son_tarih from satislar

)

select
    m.musteri_id,
    m.musteri_yasi,
    case
        when m.musteri_yasi < 25 then '16-24'
        when m.musteri_yasi < 35 then '25-34'
        when m.musteri_yasi < 45 then '35-44'
        when m.musteri_yasi < 55 then '45-54'
        else '55+'
    end                                                 as yas_grubu,
    m.musteri_cinsiyeti,
    m.musteri_segmenti,
    m.sadakat_uyesi_mi,
    d.ilk_siparis_tarihi,
    d.son_siparis_tarihi,
    date_diff('day', d.son_siparis_tarihi, v.son_tarih) as son_siparisten_gecen_gun,
    d.siparis_sayisi,
    d.toplam_urun_adedi,
    d.toplam_harcama,
    d.toplam_kar,
    d.ortalama_sepet_tutari,
    d.ortalama_puan

from musteri_bilgileri as m
left join davranis as d
    on m.musteri_id = d.musteri_id
cross join veri_son_tarihi as v
order by m.musteri_id

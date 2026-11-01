-- Takvim boyutu: veri aralığındaki her gün için bir satır.
-- Mevsim, festival ve hava bilgisi gün düzeyinde sabit olduğu için burada tutulur.

with satislar as (

    select * from {{ ref('stg_firin_satislari') }}

),

sinirlar as (

    select
        min(siparis_tarihi) as ilk_tarih,
        max(siparis_tarihi) as son_tarih
    from satislar

),

-- Satış olmayan günler de takvimde yer alsın diye aralıktaki tüm günler üretilir.
takvim as (

    select cast(unnest(generate_series(ilk_tarih, son_tarih, interval 1 day)) as date) as tarih
    from sinirlar

),

gun_bilgileri as (

    select distinct
        siparis_tarihi as tarih,
        mevsim,
        festival,
        hava_durumu,
        sicaklik
    from satislar

)

select
    t.tarih,
    cast(year(t.tarih) as integer)              as yil,
    cast(quarter(t.tarih) as integer)           as ceyrek,
    cast(month(t.tarih) as integer)             as ay,
    monthname(t.tarih)                          as ay_adi,
    cast(day(t.tarih) as integer)               as gun,
    dayname(t.tarih)                            as haftanin_gunu,
    cast(isodow(t.tarih) as integer)            as haftanin_gunu_no,
    isodow(t.tarih) in (6, 7)                   as hafta_sonu_mu,
    g.mevsim,
    g.festival,
    g.festival != 'No Festival'                 as festival_gunu_mu,
    g.hava_durumu,
    g.sicaklik

from takvim as t
left join gun_bilgileri as g
    on t.tarih = g.tarih
order by t.tarih

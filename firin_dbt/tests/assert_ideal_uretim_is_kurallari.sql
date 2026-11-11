with gunluk_satislar as (

    select
        magaza_id,
        urun_adi,
        siparis_tarihi,
        haftanin_gunu,
        hafta_sonu_mu,
        sum(adet) as gunluk_satilan_adet
    from {{ ref('stg_firin_satislari') }}
    group by magaza_id, urun_adi, siparis_tarihi, haftanin_gunu, hafta_sonu_mu

),

ortalama_satislar as (

    select
        magaza_id,
        urun_adi,
        haftanin_gunu,
        avg(gunluk_satilan_adet) as yuvarlanmamis_ortalama_gunluk_satis
    from gunluk_satislar
    group by magaza_id, urun_adi, haftanin_gunu

),

beklenen as (

    select
        tavsiye.tavsiye_id,
        tavsiye.bozulabilirlik,
        tavsiye.guvenlik_stogu_orani,
        tavsiye.tavsiye_edilen_uretim_adedi,
        case tavsiye.bozulabilirlik
            when 'High' then 0.07
            when 'Medium' then 0.10
            when 'Low' then 0.12
            when 'Very High' then 0.05
        end as beklenen_guvenlik_stogu_orani,
        ceil(ortalama.yuvarlanmamis_ortalama_gunluk_satis
            * (1 + tavsiye.guvenlik_stogu_orani)) as beklenen_uretim_adedi
    from {{ ref('fct_ideal_uretim_tavsiyesi') }} as tavsiye
    inner join ortalama_satislar as ortalama
        on tavsiye.magaza_id = ortalama.magaza_id
       and tavsiye.urun_adi = ortalama.urun_adi
       and tavsiye.haftanin_gunu = ortalama.haftanin_gunu

)

select *
from beklenen
where bozulabilirlik is null
   or bozulabilirlik not in ('High', 'Medium', 'Low', 'Very High')
   or guvenlik_stogu_orani is null
   or tavsiye_edilen_uretim_adedi is null
   or abs(guvenlik_stogu_orani - beklenen_guvenlik_stogu_orani) > 0.000001
   or tavsiye_edilen_uretim_adedi != beklenen_uretim_adedi

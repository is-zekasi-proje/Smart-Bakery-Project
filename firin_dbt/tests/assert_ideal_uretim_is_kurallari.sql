select
    tavsiye_id,
    bozulabilirlik,
    guvenlik_stogu_orani,
    tavsiye_edilen_uretim_adedi,
    case bozulabilirlik
        when 'High' then 0.05
        when 'Medium' then 0.10
        when 'Low' then 0.15
        when 'Very High' then 0.15
    end as beklenen_guvenlik_stogu_orani,
    ceil(ortalama_gunluk_satis * (1 + guvenlik_stogu_orani)) as beklenen_uretim_adedi
from {{ ref('fct_ideal_uretim_tavsiyesi') }}
where bozulabilirlik is null
   or bozulabilirlik not in ('High', 'Medium', 'Low', 'Very High')
   or guvenlik_stogu_orani is null
   or ortalama_gunluk_satis is null
   or tavsiye_edilen_uretim_adedi is null
   or abs(
        guvenlik_stogu_orani
        - case bozulabilirlik
            when 'High' then 0.05
            when 'Medium' then 0.10
            when 'Low' then 0.15
            when 'Very High' then 0.15
        end
   ) > 0.000001
   or tavsiye_edilen_uretim_adedi
      != ceil(ortalama_gunluk_satis * (1 + guvenlik_stogu_orani))

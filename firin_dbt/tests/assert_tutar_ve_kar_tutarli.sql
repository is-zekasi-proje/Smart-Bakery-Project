-- İş kuralı: her kalemde
--   toplam_tutar = satis_fiyati * adet
--   kar          = toplam_tutar - toplam_maliyet
-- olmalıdır. Kurala uymayan satırlar döner; hiç satır dönmezse test geçer.

select
    siparis_kalem_id,
    toplam_tutar,
    satis_fiyati * adet                 as beklenen_tutar,
    kar,
    toplam_tutar - toplam_maliyet       as beklenen_kar
from {{ ref('fct_satislar') }}
where abs(toplam_tutar - satis_fiyati * adet) > 0.01
   or abs(kar - (toplam_tutar - toplam_maliyet)) > 0.01

-- Mutabakat: dim_musteriler'deki toplam harcama ve sipariş sayısı, fct_satislar ile aynı olmalıdır.
-- Müşteri özetlenirken bir join satırları çoğaltırsa bu test başarısız olur.

with musteriler as (

    select sum(toplam_harcama) as harcama, sum(siparis_sayisi) as siparis_sayisi
    from {{ ref('dim_musteriler') }}

),

satislar as (

    select sum(toplam_tutar) as harcama, count(distinct siparis_id) as siparis_sayisi
    from {{ ref('fct_satislar') }}

)

select *
from musteriler, satislar
where musteriler.harcama != satislar.harcama
   or musteriler.siparis_sayisi != satislar.siparis_sayisi

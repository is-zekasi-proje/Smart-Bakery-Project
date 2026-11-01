-- Mutabakat: fct_satislar, staging ile aynı satır sayısına ve ciroya sahip olmalıdır.
-- Dönüşüm sırasında satır kaybı ya da çoğalması olursa bu test başarısız olur.

with staging as (

    select count(*) as satir_sayisi, sum(toplam_tutar) as ciro
    from {{ ref('stg_firin_satislari') }}

),

mart as (

    select count(*) as satir_sayisi, sum(toplam_tutar) as ciro
    from {{ ref('fct_satislar') }}

)

select *
from staging, mart
where staging.satir_sayisi != mart.satir_sayisi
   or staging.ciro != mart.ciro

-- Bir mart tablosunu data/marts/<tablo_adi>.parquet dosyasına yazar (Power BI ve Python için).
-- DECIMAL sütunlar dosyada DOUBLE'a çevrilir: pandas bunları Decimal nesnesi yerine
-- normal sayı olarak okur. Veritabanındaki tablo DECIMAL olarak kalır.
{% macro parquet_olarak_disa_aktar(relation) %}
    {%- set sutunlar = adapter.get_columns_in_relation(relation) -%}
    copy (
        select
        {%- for sutun in sutunlar %}
            {% if sutun.dtype.lower().startswith('decimal') -%}
                cast({{ adapter.quote(sutun.name) }} as double) as {{ adapter.quote(sutun.name) }}
            {%- else -%}
                {{ adapter.quote(sutun.name) }}
            {%- endif -%}
            {{ "," if not loop.last }}
        {%- endfor %}
        from {{ relation }}
    ) to '../data/marts/{{ relation.identifier }}.parquet' (format parquet)
{% endmacro %}

-- dbt varsayılan olarak şema adlarını "main_staging" gibi birleştirir.
-- Bu makro, dbt_project.yml'de verilen şema adını olduğu gibi kullanır (ör. "staging").
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

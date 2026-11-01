-- Genel test: sütun değerleri verilen aralığın dışına çıkıyor mu?
-- Aralık dışındaki satırları döndürür; hiç satır dönmezse test geçer.
-- Kullanım (yml): deger_araliginda: {arguments: {min_deger: 1, max_deger: 5}}
-- min_deger veya max_deger'den biri verilmeyebilir (tek taraflı sınır).
{% test deger_araliginda(model, column_name, min_deger=none, max_deger=none) %}

select *
from {{ model }}
where {{ column_name }} is not null
  and (
      false
      {% if min_deger is not none %} or {{ column_name }} < {{ min_deger }} {% endif %}
      {% if max_deger is not none %} or {{ column_name }} > {{ max_deger }} {% endif %}
  )

{% endtest %}

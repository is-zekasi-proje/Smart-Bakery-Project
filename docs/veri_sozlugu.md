# Veri Sözlüğü

> Bu dosya `scripts/generate_docs.py` ile dbt dokümantasyonundan **otomatik üretilir**; elle düzenlemeyin.
> Açıklamaları değiştirmek için `firin_dbt/models/**/_*.yml` dosyalarını güncelleyin.

Analiz ve dashboard için **`marts`** tablolarını kullanın (dosya olarak: `data/marts/<tablo>.parquet`).
Tip sütunu DuckDB'deki tipi gösterir; Parquet dosyalarında `DECIMAL` sütunlar `DOUBLE` (ondalıklı sayı) olarak yazılır.

## Tablolar

| Tablo | Şema | Sütun | Açıklama |
|---|---|---|---|
| [`fct_satislar`](#fct_satislar) | `marts` | 29 | Satış olgu tablosu. |
| [`dim_musteriler`](#dim_musteriler) | `marts` | 15 | Müşteri boyutu. |
| [`dim_urunler`](#dim_urunler) | `marts` | 12 | Ürün boyutu. |
| [`dim_tarih`](#dim_tarih) | `marts` | 14 | Takvim boyutu. |
| [`stg_firin_satislari`](#stg_firin_satislari) | `staging` | 43 | Temizlenmiş fırın satış verisi. |

## fct_satislar

**Şema:** `marts`, **Tip:** table, **Kaynak kod:** `firin_dbt/models/marts/fct_satislar.sql`

Satış olgu tablosu. Her satır bir siparişteki bir ürün kalemidir. Ciro, kâr ve indirim analizlerinin ana tablosudur. dim_musteriler (musteri_id), dim_urunler (urun_adi) ve dim_tarih (siparis_tarihi) ile bağlanır.

| Sütun | Tip | Açıklama | Testler |
|---|---|---|---|
| `siparis_kalem_id` | VARCHAR | Satırın tekil anahtarı (siparis_id + urun_adi'ndan üretilen md5 özeti). | not_null, unique |
| `siparis_id` | VARCHAR | Sipariş numarası. Bir sipariş birden fazla kalem içerebilir. | not_null |
| `musteri_id` | VARCHAR | Müşteri numarası; dim_musteriler tablosuna bağlanır. | not_null, relationships: dim_musteriler.musteri_id |
| `urun_adi` | VARCHAR | Ürün adı; dim_urunler tablosuna bağlanır. | not_null, relationships: dim_urunler.urun_adi |
| `siparis_tarihi` | DATE | Sipariş tarihi; dim_tarih tablosuna bağlanır. | not_null, relationships: dim_tarih.tarih |
| `magaza_id` | VARCHAR | Siparişin verildiği mağaza (ST01, ST02, ST03). | accepted_values |
| `siparis_saati` | TIME | Siparişin saati (ss:dd). |  |
| `siparis_zamani` | TIMESTAMP | Sipariş tarihi ve saatinin birleşimi. |  |
| `saat` | INTEGER | Siparişin saat dilimi (7-21). |  |
| `odeme_yontemi` | VARCHAR | Ödeme yöntemi (sipariş düzeyinde sabit). |  |
| `promosyon_uygulandi_mi` | BOOLEAN | Promosyon uygulandı mı (sipariş düzeyinde sabit). |  |
| `promosyon_tipi` | VARCHAR | Promosyon tipi; promosyon yoksa 'No Promotion'. |  |
| `musteri_puani` | INTEGER | Müşterinin siparişe verdiği puan (1-5). Sipariş düzeyinde verilir; ortalama alınırken siparişler tekilleştirilmelidir (bkz. dim_musteriler.ortalama_puan). | aralık [1, 5] |
| `birim_fiyat` | DECIMAL(10,2) | İndirim öncesi birim fiyat. |  |
| `birim_maliyet` | DECIMAL(10,2) | Birim maliyet. |  |
| `indirim_orani` | DECIMAL(5,1) | İndirim yüzdesi (14.7 = %14.7). | aralık [0, 100] |
| `satis_fiyati` | DECIMAL(10,2) | İndirim sonrası birim satış fiyatı. |  |
| `adet` | INTEGER | Bu kalemde satılan ürün adedi. | >= 1 |
| `brut_tutar` | DECIMAL(12,2) | İndirim öncesi kalem tutarı (birim_fiyat * adet). |  |
| `indirim_tutari` | DECIMAL(12,2) | İndirim ile düşülen tutar (brut_tutar - toplam_tutar). |  |
| `toplam_tutar` | DECIMAL(12,2) | Kalemin net tutarı, yani ciro (satis_fiyati * adet). | >= 0 |
| `toplam_maliyet` | DECIMAL(12,2) | Kalemin toplam maliyeti (birim_maliyet * adet). |  |
| `kar` | DECIMAL(12,2) | Kalemin kârı (toplam_tutar - toplam_maliyet). Çok küçük negatif değerler olabilir. |  |
| `raf_omru_gun` | INTEGER | Ürünün raf ömrü (gün); partiden partiye değişebilir. |  |
| `uretilen_adet` | INTEGER | Üretilen adet. Satıra ait stok bilgisidir; satırlar arasında toplanmamalıdır. |  |
| `satilan_adet` | INTEGER | Satılan adet (her zaman adet'e eşit veya büyük). Toplanmamalıdır. |  |
| `satilmayan_adet` | INTEGER | Satılmayan adet (uretilen_adet - satilan_adet). |  |
| `mevcut_stok` | INTEGER | Kalan stok adedi. |  |
| `fire_orani` | DECIMAL(5,1) | Fire yüzdesi (satilmayan_adet / uretilen_adet * 100). Toplanmamalı, ortalaması alınmalıdır. | aralık [0, 100] |

## dim_musteriler

**Şema:** `marts`, **Tip:** table, **Kaynak kod:** `firin_dbt/models/marts/dim_musteriler.sql`

Müşteri boyutu. Her satır bir müşteridir; demografik bilgiler ve satın alma davranışı özeti (sipariş sayısı, harcama, yenilik) içerir. Müşteri segmentasyonu veya churn modeli için temel tablodur.

| Sütun | Tip | Açıklama | Testler |
|---|---|---|---|
| `musteri_id` | VARCHAR | Müşteri numarası (tekil). | not_null, unique |
| `musteri_yasi` | INTEGER | Müşterinin yaşı. | aralık [0, 120] |
| `yas_grubu` | VARCHAR | Yaş grubu (16-24, 25-34, 35-44, 45-54, 55+). Verideki en küçük yaş 16'dır. | accepted_values |
| `musteri_cinsiyeti` | VARCHAR | Müşterinin cinsiyeti (Female, Male, Other). |  |
| `musteri_segmenti` | VARCHAR | Müşteri segmenti (Family, Senior Citizen, Student, Young Professional). |  |
| `sadakat_uyesi_mi` | BOOLEAN | Sadakat programı üyesi mi. |  |
| `ilk_siparis_tarihi` | DATE | Müşterinin ilk sipariş tarihi. |  |
| `son_siparis_tarihi` | DATE | Müşterinin son sipariş tarihi. |  |
| `son_siparisten_gecen_gun` | BIGINT | Son siparişten verinin son gününe (2024-12-31) kadar geçen gün sayısı (yenilik / recency). Bugünün tarihine göre değil, veri setinin son gününe göre hesaplanır. | >= 0 |
| `siparis_sayisi` | BIGINT | Müşterinin toplam sipariş sayısı (sıklık / frequency). | >= 1 |
| `toplam_urun_adedi` | INTEGER | Müşterinin satın aldığı toplam ürün adedi. |  |
| `toplam_harcama` | DECIMAL(14,2) | Müşterinin toplam harcaması, indirim sonrası (parasal değer / monetary). |  |
| `toplam_kar` | DECIMAL(14,2) | Müşteriden elde edilen toplam kâr. |  |
| `ortalama_sepet_tutari` | DECIMAL(10,2) | Sipariş başına ortalama harcama. |  |
| `ortalama_puan` | DECIMAL(3,2) | Müşterinin siparişlerine verdiği ortalama puan (sipariş bazında). |  |

## dim_urunler

**Şema:** `marts`, **Tip:** table, **Kaynak kod:** `firin_dbt/models/marts/dim_urunler.sql`

Ürün boyutu. Her satır bir üründür; kategori ve saklama bilgileri ile satış, kâr ve fire özetini içerir.

| Sütun | Tip | Açıklama | Testler |
|---|---|---|---|
| `urun_adi` | VARCHAR | Ürün adı (tekil). | not_null, unique |
| `kategori` | VARCHAR | Ürün kategorisi. | not_null |
| `saklama_tipi` | VARCHAR | Saklama koşulu (Dry Storage, Refrigerated, Room Temperature). |  |
| `bozulabilirlik` | VARCHAR | Bozulma hızı (Low, Medium, High, Very High). |  |
| `ortalama_birim_fiyat` | DECIMAL(10,2) | Ortalama indirim öncesi birim fiyat (fiyat satırdan satıra değişir). |  |
| `ortalama_birim_maliyet` | DECIMAL(10,2) | Ortalama birim maliyet. |  |
| `ortalama_raf_omru_gun` | DECIMAL(6,1) | Ortalama raf ömrü (gün). |  |
| `toplam_satis_adedi` | INTEGER | Toplam satılan adet. |  |
| `toplam_ciro` | DECIMAL(14,2) | Toplam ciro (indirim sonrası). |  |
| `toplam_kar` | DECIMAL(14,2) | Toplam kâr. |  |
| `kar_marji` | DECIMAL(5,1) | Kâr marjı yüzdesi (toplam_kar / toplam_ciro * 100). |  |
| `ortalama_fire_orani` | DECIMAL(5,1) | Ortalama fire yüzdesi. | aralık [0, 100] |

## dim_tarih

**Şema:** `marts`, **Tip:** table, **Kaynak kod:** `firin_dbt/models/marts/dim_tarih.sql`

Takvim boyutu. Veri aralığındaki (2023-01-01 ile 2024-12-31 arası) her gün için bir satır; mevsim, festival ve hava bilgisi gün düzeyinde burada tutulur.

| Sütun | Tip | Açıklama | Testler |
|---|---|---|---|
| `tarih` | DATE | Gün (tekil). | not_null, unique |
| `yil` | INTEGER | Yıl. |  |
| `ceyrek` | INTEGER | Çeyrek (1-4). |  |
| `ay` | INTEGER | Ay (1-12). |  |
| `ay_adi` | VARCHAR | Ay adı (January-December). |  |
| `gun` | INTEGER | Ayın günü. |  |
| `haftanin_gunu` | VARCHAR | Haftanın günü (Monday-Sunday). |  |
| `haftanin_gunu_no` | INTEGER | Haftanın günü numarası (1 = Pazartesi, 7 = Pazar); sıralama için. |  |
| `hafta_sonu_mu` | BOOLEAN | Cumartesi veya Pazar mı. |  |
| `mevsim` | VARCHAR | Mevsim (Winter, Summer, Monsoon, Autumn). | not_null |
| `festival` | VARCHAR | O günkü festival; yoksa 'No Festival'. |  |
| `festival_gunu_mu` | BOOLEAN | O gün bir festival günü mü. |  |
| `hava_durumu` | VARCHAR | O günkü hava durumu. | not_null |
| `sicaklik` | DECIMAL(4,1) | O günkü sıcaklık (°C). |  |

## stg_firin_satislari

**Şema:** `staging`, **Tip:** view, **Kaynak kod:** `firin_dbt/models/staging/stg_firin_satislari.sql`

Temizlenmiş fırın satış verisi. Her satır bir siparişteki bir ürün kalemidir (siparis_id + urun_adi tekildir). Sütunlar Türkçe adlandırılmış, para ve yüzde sütunları DECIMAL'e çevrilmiş, boş festival/promosyon değerleri doldurulmuştur. Kategori değerleri kaynaktaki gibi İngilizcedir.

| Sütun | Tip | Açıklama | Testler |
|---|---|---|---|
| `siparis_kalem_id` | VARCHAR | Satırın tekil anahtarı; siparis_id ve urun_adi'ndan üretilen md5 özeti. | not_null, unique |
| `siparis_id` | VARCHAR | Sipariş numarası. Bir sipariş birden fazla ürün kalemi içerebilir. | not_null |
| `musteri_id` | VARCHAR | Müşteri numarası. | not_null |
| `magaza_id` | VARCHAR | Siparişin verildiği mağaza. | accepted_values |
| `musteri_yasi` | INTEGER | Müşterinin yaşı. |  |
| `musteri_cinsiyeti` | VARCHAR | Müşterinin cinsiyeti. | accepted_values |
| `musteri_segmenti` | VARCHAR | Müşteri segmenti. | accepted_values |
| `sadakat_uyesi_mi` | BOOLEAN | Müşteri sadakat programı üyesi mi (true/false). |  |
| `siparis_tarihi` | DATE | Siparişin tarihi. | not_null |
| `siparis_saati` | TIME | Siparişin saati (ss:dd). |  |
| `siparis_zamani` | TIMESTAMP | Sipariş tarihi ve saatinin birleşimi. |  |
| `yil` | INTEGER | Sipariş yılı. |  |
| `ay` | INTEGER | Sipariş ayı (1-12). |  |
| `gun` | INTEGER | Ayın günü (1-31). |  |
| `haftanin_gunu` | VARCHAR | Haftanın günü (Monday-Sunday). |  |
| `hafta_sonu_mu` | BOOLEAN | Sipariş hafta sonu mu verildi (Cumartesi/Pazar). |  |
| `saat` | INTEGER | Siparişin saat dilimi (7-21). |  |
| `mevsim` | VARCHAR | Mevsim (Winter, Summer, Monsoon, Autumn). |  |
| `festival` | VARCHAR | O günkü festival; festival olmayan günlerde 'No Festival'. | not_null |
| `hava_durumu` | VARCHAR | O günkü hava durumu. |  |
| `sicaklik` | DECIMAL(4,1) | O günkü sıcaklık (°C). |  |
| `urun_adi` | VARCHAR | Satılan ürün (35 farklı ürün). | not_null |
| `kategori` | VARCHAR | Ürün kategorisi. | accepted_values |
| `raf_omru_gun` | INTEGER | Ürünün raf ömrü (gün). Aynı ürün için partiden partiye değişebilir. |  |
| `saklama_tipi` | VARCHAR | Saklama koşulu (Dry Storage, Refrigerated, Room Temperature). |  |
| `bozulabilirlik` | VARCHAR | Ürünün bozulma hızı (Low, Medium, High, Very High). |  |
| `adet` | INTEGER | Bu kalemde satılan ürün adedi. |  |
| `birim_fiyat` | DECIMAL(10,2) | İndirim öncesi birim fiyat. |  |
| `birim_maliyet` | DECIMAL(10,2) | Ürünün birim maliyeti. |  |
| `indirim_orani` | DECIMAL(5,1) | Uygulanan indirim yüzdesi (14.7 = %14.7). |  |
| `satis_fiyati` | DECIMAL(10,2) | İndirim sonrası birim satış fiyatı (birim_fiyat * (1 - indirim_orani/100)). |  |
| `toplam_tutar` | DECIMAL(12,2) | Bu kalemin tutarı (satis_fiyati * adet). Siparişin toplamı değil, kalemin toplamıdır. |  |
| `kar` | DECIMAL(12,2) | Bu kalemden elde edilen kâr ((satis_fiyati - birim_maliyet) * adet). |  |
| `odeme_yontemi` | VARCHAR | Ödeme yöntemi. | accepted_values |
| `promosyon_uygulandi_mi` | BOOLEAN | Bu kaleme promosyon uygulandı mı (true/false). |  |
| `promosyon_tipi` | VARCHAR | Promosyon tipi; promosyon yoksa 'No Promotion'. | accepted_values, not_null |
| `musteri_puani` | INTEGER | Müşterinin verdiği puan (1-5). | accepted_values |
| `uretilen_adet` | INTEGER | Ürünün üretilen adedi. Satıra ait stok bilgisidir; satırlar arasında toplanmamalıdır. |  |
| `satilan_adet` | INTEGER | Ürünün satılan adedi (her zaman adet'e eşit veya büyük). Satırlar arasında toplanmamalıdır. |  |
| `satilmayan_adet` | INTEGER | Satılmayan adet (uretilen_adet - satilan_adet). |  |
| `mevcut_stok` | INTEGER | Kalan stok adedi. |  |
| `fire_orani` | DECIMAL(5,1) | Fire yüzdesi (satilmayan_adet / uretilen_adet * 100). Toplanmamalı, ortalaması alınmalıdır. |  |
| `_yuklenme_zamani` | TIMESTAMP WITH TIME ZONE | Ham verinin DuckDB'ye yüklendiği zaman. |  |

## İş kuralı ve mutabakat testleri

Sütun testlerine ek olarak `firin_dbt/tests/` klasöründeki testler:

| Test | Açıklama |
|---|---|
| `assert_fct_staging_mutabakati` | Mutabakat: fct_satislar ile staging aynı satır sayısına ve ciroya sahip olmalıdır (dönüşümde satır kaybı veya çoğalması yok). |
| `assert_musteri_harcamasi_mutabakati` | Mutabakat: dim_musteriler'deki toplam harcama ve sipariş sayısı fct_satislar ile aynı olmalıdır (müşteri özetinde join kaynaklı çoğalma yok). |
| `assert_tutar_ve_kar_tutarli` | İş kuralı: her kalemde toplam_tutar = satis_fiyati * adet ve kar = toplam_tutar - toplam_maliyet olmalıdır. |

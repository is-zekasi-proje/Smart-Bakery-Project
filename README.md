# Smart Bakery

Üç mağazalı bir fırının 2023-2024 satış verisi üzerinde kurulan uçtan uca veri projesi. Veri DuckDB'ye
yüklenir, dbt ile temizlenip analize hazır tablolara dönüştürülür; bu tablolar PostgreSQL'e aktarılarak
Apache Superset dashboard'ları ve tahmin modelleri için kullanılır.

## Veri

Eğitmen onaylı fırın satış veri seti: `data/raw/bakery_sales_dataset.csv`

Doğrulanan satış özeti: 19.321 sipariş kalemi, 6.576 sipariş, 500 müşteri, 35 ürün ve 3 mağaza;
2023-01-01 ile 2024-12-31 arasını kapsar. Sütun açıklamaları `docs/DATA_DICTIONARY.md` dosyasındadır.

## Veri akışı ve dbt Veri Ambarı Mimarisi

Proje, dbt ile modellenen **toplam 8 modelden** (1 staging, 7 mart) oluşur:

1. `scripts/load_raw_data.py`, CSV dosyasını DuckDB'deki `raw.bakery_sales` tablosuna yükler.
2. **dbt Staging Katmanı (`staging`)**:
   - `stg_firin_satislari`: Ham fırın satış verilerini temizler, sütun adlarını standartlaştırır, tipleri dönüştürür ve boş değerleri doldurur.
3. **dbt Mart Katmanı (`marts`) — 7 analitik model.** PostgreSQL'deki mevcut satır sayıları ve kolonlar dbt SQL'iyle kontrol edildi:
   - `fct_satislar`: Sipariş kalemi düzeyi satış olgusu (19.321 satır). Ciro, maliyet, kâr ve indirim analizlerinde kullanılır.
     - **dbt SQL çıktı kolonları:** `siparis_kalem_id`, `siparis_id`, `musteri_id`, `urun_adi`, `siparis_tarihi`, `magaza_id`, `siparis_saati`, `siparis_zamani`, `saat`, `odeme_yontemi`, `promosyon_uygulandi_mi`, `promosyon_tipi`, `musteri_puani`, `birim_fiyat`, `birim_maliyet`, `indirim_orani`, `satis_fiyati`, `adet`, `brut_tutar`, `indirim_tutari`, `toplam_tutar`, `toplam_maliyet`, `kar`, `raf_omru_gun`, `uretilen_adet`, `satilan_adet`, `satilmayan_adet`, `mevcut_stok`, `fire_orani`.
     - `satilmayan_adet`, `mevcut_stok` ve `fire_orani` sipariş satırındaki stok bilgisidir; satırlar arasında toplanmamalıdır.
     - **Beslediği Superset grafikleri (`viz_type`):** `Gerçekleşen Toplam Ciro` (`big_number_total`), `Ortalama Sepet Tutarı` (`big_number_total`), `Toplam Kâr` (`big_number_total`), `Mağaza Bazlı Ciro` (`echarts_timeseries_bar`), `Promosyon Tipine Göre Performans` (`echarts_timeseries_bar`).
   - `fct_israf_ve_fire_analizi`: Mağaza × ürün × gün düzeyinde israf/fire olgusu (16.563 satır).
     - **dbt SQL çıktı kolonları:** `israf_kayit_id`, `magaza_id`, `urun_adi`, `siparis_tarihi`, `kategori`, `saklama_tipi`, `bozulabilirlik`, `raf_omru_gun`, `mevsim`, `hava_durumu`, `uretilen_adet`, `satilan_adet`, `mevcut_stok`, `satilmayan_adet`, `fire_orani`, `birim_maliyet`, `birim_fiyat`, `fire_maliyeti`, `potansiyel_ciro_kaybi`.
     - `fire_maliyeti`, satılmayan adet ile ortalama birim maliyetin; `potansiyel_ciro_kaybi`, satılmayan adet ile ortalama birim fiyatın çarpımıdır (gruplama düzeyinde).
     - **Beslediği Superset grafikleri (`viz_type`):** `Ortalama İsraf Oranı` (`big_number_total`), `Toplam Fire Maliyeti` (`big_number_total`), `Satılamayan Ürün Adedi` (`big_number_total`), `En Çok İsraf Edilen Top 10 Ürün` (`echarts_timeseries_bar`), `Kategori Bazlı İsraf Maliyeti Dağılımı` (`pie`), `Haftanın Günlerine Göre İsraf Risk Haritası (%)` (`heatmap_v2`), `Günlük Fire Maliyeti ve İsraf Trendi` (`echarts_area`).
   - `fct_ideal_uretim_tavsiyesi`: Mağaza × ürün × haftanın günü düzeyinde üretim tavsiyesi (735 satır).
     - **dbt SQL çıktı kolonları:** `tavsiye_id`, `magaza_id`, `urun_adi`, `kategori`, `bozulabilirlik`, `raf_omru_gun`, `saklama_tipi`, `haftanin_gunu`, `haftanin_gunu_no`, `hafta_sonu_mu`, `gozlem_sayisi`, `ortalama_gunluk_satis`, `min_gunluk_satis`, `max_gunluk_satis`, `ortalama_gecmis_fire_orani`, `guvenlik_stogu_orani`, `tavsiye_edilen_uretim_adedi`, `ortalama_birim_maliyet`, `ortalama_birim_fiyat`, `tahmini_uretim_maliyeti`, `tahmini_potansiyel_ciro`.
     - `guvenlik_stogu_orani` başlangıç politikasıdır: Very High %5, High %7, Medium %10, Low %12. `tavsiye_edilen_uretim_adedi`, geçmiş günlük satış ortalamasına bu oran uygulanıp yukarı yuvarlanarak hesaplanır.
     - **Oran gerekçesi:** `fct_israf_ve_fire_analizi` günlük mağaza × ürün gözlemlerindeki ortalama raf ömrü ve üretim ağırlıklı fire oranı (`100 * SUM(satilmayan_adet) / SUM(uretilen_adet)`) Very High için 2,1 gün / %27,68; High için 4,2 gün / %32,98; Medium için 46,9 gün / %35,27; Low için 179,6 gün / %30,54'tür. Veride stock-out ölçümü bulunmadığından tampon oranları başlangıç politikasıdır; saha verisiyle izlenmelidir.
     - **Beslediği Superset grafikleri (`viz_type`):** `Tavsiye Edilen Günlük Üretim Adedi` (`big_number_total`), `Haftanın Günlerine Göre Akıllı Üretim Tavsiyesi` (`echarts_timeseries_bar`).
   - `dim_musteriler`: Müşteri boyutu ve sipariş düzeyinde davranış özeti (500 satır).
     - **dbt SQL çıktı kolonları:** `musteri_id`, `musteri_yasi`, `yas_grubu`, `musteri_cinsiyeti`, `musteri_segmenti`, `sadakat_uyesi_mi`, `ilk_siparis_tarihi`, `son_siparis_tarihi`, `son_siparisten_gecen_gun`, `siparis_sayisi`, `toplam_urun_adedi`, `toplam_harcama`, `toplam_kar`, `ortalama_sepet_tutari`, `ortalama_puan`.
   - `dim_musteri_rfm`: RFM müşteri segmentasyonu (500 satır; verideki 500 müşterinin tamamı).
     - **dbt SQL çıktı kolonları:** `musteri_id`, `musteri_yasi`, `yas_grubu`, `musteri_cinsiyeti`, `musteri_segmenti`, `sadakat_uyesi_mi`, `ilk_siparis_tarihi`, `son_siparis_tarihi`, `son_siparisten_gecen_gun`, `siparis_sayisi`, `toplam_harcama`, `toplam_kar`, `toplam_urun_adedi`, `ortalama_sepet_tutari`, `ortalama_puan`, `favori_odeme_yontemi`, `en_sik_gidilen_magaza`, `r_skoru`, `f_skoru`, `m_skoru`, `rfm_skoru`, `rfm_ortalama_skor`, `rfm_segmenti`.
     - `r_skoru`, `f_skoru` ve `m_skoru` 1–5 arası `ntile` puanlarıdır; eşit metriklerde `musteri_id` artan sırası kullanılır. En sık mağaza ve favori ödeme yöntemi eşitliğinde alfabetik ilk değer seçilir.
     - Veride dokuz segmentin tamamı bulunur: Şampiyonlar, Sadık Müşteriler, Potansiyel Sadıklar, Yeni Müşteriler, Gelişime Açık, Kaybedilme Riski Yüksek, Dikkat Gerektirenler, Uykudaki Değerliler, Kayıp Müşteriler.
     - **Beslediği Superset grafikleri (`viz_type`):** `Yaş Grubu ve Sadakat Üyeliği Kârlılığı` (`echarts_timeseries_bar`), `Müşteri RFM Segment Dağılımı` (`mixed_timeseries`).
   - `dim_urunler`: Ürün boyutu (35 satır/ürün).
     - **dbt SQL çıktı kolonları:** `urun_adi`, `kategori`, `saklama_tipi`, `bozulabilirlik`, `ortalama_birim_fiyat`, `ortalama_birim_maliyet`, `ortalama_raf_omru_gun`, `toplam_satis_adedi`, `toplam_ciro`, `toplam_kar`, `kar_marji`, `ortalama_fire_orani`.
     - **Beslediği Superset grafiği (`viz_type`):** `Ürün Kategorisi ve Kâr Marjı Analizi` (`echarts_timeseries_bar`).
   - `dim_tarih`: Takvim boyutu (731 gün; 2023-01-01–2024-12-31).
     - **dbt SQL çıktı kolonları:** `tarih`, `yil`, `ceyrek`, `ay`, `ay_adi`, `gun`, `haftanin_gunu`, `haftanin_gunu_no`, `hafta_sonu_mu`, `mevsim`, `festival`, `festival_gunu_mu`, `hava_durumu`, `sicaklik`.
   - **Dashboard filtre eşlemesi:** Ürün kategorisi filtresi `dim_urunler`, mağaza filtresi `fct_israf_ve_fire_analizi`, müşteri segmenti filtresi `dim_musteri_rfm` dataset'ine bağlıdır. Tarih aralığı filtresinin dashboard API metadata'sında belirli bir dataset hedefi yoktur.
4. Mart tabloları `data/marts/` klasörüne Parquet dosyası olarak yazılır (`dim_musteriler.parquet`, `dim_musteri_rfm.parquet`, `dim_urunler.parquet`, `dim_tarih.parquet`, `fct_satislar.parquet`, `fct_israf_ve_fire_analizi.parquet`, `fct_ideal_uretim_tavsiyesi.parquet`).
5. `import_data.py` (veya `scripts/import_data.py`) betiği ile Parquet mart verileri Docker üzerinde koşan PostgreSQL (`smartbakery_db`) veritabanına aktarılır.
6. DBeaver ile SQL analizleri yapılır ve Apache Superset üzerinde interaktif iş zekası dashboard'ları oluşturulur.

## Kullanılan araçlar

- **DuckDB**: kurulum gerektirmeyen, tek dosyalık hızlı analitik veritabanı.
- **dbt Core 1.12 ve dbt-duckdb**: katmanlı, test edilen ve dokümante edilen dönüşümler için. dbt-duckdb adaptörü
  dbt v1 için geliştirildiğinden v1 kullanılıyor.
- **Parquet**: sütun tiplerini koruyan, yüksek performanslı ve taşınabilir dosya formatı.
- **PostgreSQL 15 (Docker)**: analitik veri ambarı ve Superset metadata depolama katmanı.
- **Apache Superset (Docker)**: modern, kurumsal seviyede veri görselleştirme ve BI platformu.
- **Redis (Docker)**: Superset sorgu sonuçları ve oturum yönetimi için önbellekleme katmanı.
- **Python 3.12** / SQLAlchemy & Pandas

## Klasörler

- `data/raw/`: ham veri (CSV)
- `data/marts/`: dbt çıktısı olan Parquet dosyaları
- `scripts/`: veri yükleme, PostgreSQL aktarımı ve dokümantasyon scriptleri
- `docker/`: PostgreSQL ve Superset yapılandırma dosyaları (`init.sql`, `superset_config.py`)
- `firin_dbt/`: dbt projesi (modeller, testler, makrolar)
- `docs/`: dbt docs sayfası ve veri sözlüğü
- `docker-compose.yml`: PostgreSQL, Redis ve Superset konteyner yapılandırması
- `import_data.py`: Parquet/DuckDB verilerini PostgreSQL'e aktaran ana betik

## Kurulum ve çalıştırma

Python 3.11 veya üstü gerekir (`python3 --version` ile kontrol edilebilir).

### 1. Python Ortamı ve dbt Modellemesi

```bash
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

python scripts/load_raw_data.py    # data/bakery.duckdb oluşturulur

cd firin_dbt
dbt build                          # modeller, testler ve Parquet çıktıları üretilir
dbt docs generate --static
cd ..
python scripts/generate_docs.py    # docs/ klasörünü günceller
```

### 2. Docker Servislerini Başlatma (PostgreSQL & Superset)

Önce `.env.example` dosyasını `.env` olarak kopyalayın ve yerel ortamınızda gerekli değişkenleri doldurun. `.env` Git tarafından yok sayılır; değerleri repoya eklemeyin veya paylaşmayın. Gerekli değişken adları [Dashboard Gömme ve Güvenlik](#dashboard-gömme-ve-güvenlik) bölümündedir.

Docker Desktop veya Docker Engine'in çalışır durumda olduğundan emin olun:

```bash
# PostgreSQL, Redis, Superset-Init ve Superset web servislerini başlatır:
docker compose up -d
```

> **Not:** `superset-init` servisi ilk çalıştırmada veritabanı migrasyonlarını (`db upgrade`), admin kullanıcısını ve yetkileri (`superset init`) otomatik olarak tamamlar. Admin parolası `.env` içindeki `SUPERSET_ADMIN_PASSWORD` değişkeninden alınır. `docker compose logs -f superset-init` komutu ile süreci takip edebilirsiniz.

### 3. Verileri PostgreSQL'e Aktarma

dbt mart Parquet verilerini Docker üzerinde koşan PostgreSQL `smartbakery_db` veritabanına aktarmak için (yerel makineden `localhost:5433` portu kullanılır):

```bash
python import_data.py
# veya
python scripts/import_data.py
```

Aktarım tamamlandığında tüm mart tabloları (`dim_musteriler`, `dim_musteri_rfm`, `dim_urunler`, `dim_tarih`, `fct_satislar`, `fct_israf_ve_fire_analizi`, `fct_ideal_uretim_tavsiyesi`) birincil anahtarları ve performans indeksleriyle birlikte `smartbakery_db` içinde hazır hale gelir.

### 4. Streamlit Dashboard'unu Çalıştırma

Önce 2. adımdaki Docker servislerinin çalıştığını ve 3. adımdaki veritabanı aktarımının tamamlandığını doğrulayın. Proje kökündeki `.env` dosyasında `SUPERSET_SERVICE_USER`, `SUPERSET_SERVICE_PASSWORD` ve `SUPERSET_EMBEDDED_ID` değişkenleri tanımlı olmalıdır.

Proje kökünde çalıştırın:

```bash
streamlit run app.py --server.port 8501
```

İlk çalıştırmada Streamlit e-posta sorarsa alanı boş bırakıp Enter'a basın. Uygulamayı [http://localhost:8501](http://localhost:8501) adresinde açın. Port 8501 doluysa Streamlit hata verir; başka port kullanılırsa CSP, CORS ve Superset embed izinleri yalnızca 8501'e açık olduğundan dashboard gömülemez.

Yeni bir bilgisayarda kurulum için [KURULUM.md](KURULUM.md) dosyasına bakın.

Günlük kullanım için calistir.bat ile başlatın.

---

## Veritabanı ve Görselleştirme Bağlantıları

> 📌 **Önemli Port Ayrımı:**
> - **Yerel Makine (Localhost / DBeaver / import_data.py):** Yerel makinenizdeki mevcut PostgreSQL servisleriyle port çakışmasını önlemek amacıyla Docker dış portu **`5433`** (`localhost:5433`) olarak ayarlanmıştır.
> - **Docker Konteyner İçi Ağı (Apache Superset):** Apache Superset, PostgreSQL ile aynı izole Docker ağı (`smartbakery_network`) içerisinde haberleştiği için iç port olan **`5432`** (`postgres:5432`) üzerinden bağlanır.

### 🐘 DBeaver Bağlantı Adresi

PostgreSQL veritabanındaki tabloları sorgulamak için DBeaver üzerinden aşağıdaki bağlantıyı oluşturabilirsiniz:

| Parametre | Değer |
| :--- | :--- |
| **Veritabanı Türü (Driver)** | PostgreSQL |
| **Host (Sunucu)** | `localhost` |
| **Port** | `5433` |
| **Database (Veritabanı)** | `smartbakery_db` |
| **Username (Kullanıcı Adı)** | `postgres` |
| **Password (Şifre)** | Yerel `.env` içindeki `POSTGRES_PASSWORD` |
| **Şema (Schema)** | `public` |
| **JDBC Bağlantı URL** | `jdbc:postgresql://localhost:5433/smartbakery_db` |

---

### 📊 Apache Superset Bağlantı Adresi

Apache Superset web arayüzüne tarayıcınızdan erişebilirsiniz:

- **Web Arayüzü**: [http://localhost:8088](http://localhost:8088)
- **Kullanıcı Adı**: `admin`
- **Şifre**: Yerel `.env` içindeki `SUPERSET_ADMIN_PASSWORD`

#### Superset İçinden Smart Bakery Veritabanını Ekleme:

1. [http://localhost:8088](http://localhost:8088) adresine gidin ve admin bilgileriyle giriş yapın.
2. Sağ üstteki **Settings (Ayarlar)** menüsünden **Database Connections** seçeneğine tıklayın.
3. Sağ üstteki **+ DATABASE** butonuna basın.
4. Veritabanı tipi olarak **PostgreSQL** seçin.
5. Docker ağı içerisinden bağlanmak için aşağıdaki bilgileri girin:
   - **HOST**: `postgres` *(Docker ağı içerisindeki PostgreSQL konteyner adı)*
   - **PORT**: `5432` *(Konteyner içi ağ bağlantı portu)*
   - **DATABASE NAME**: `smartbakery_db`
   - **USERNAME**: `postgres`
   - **PASSWORD**: Yerel `.env` içindeki `POSTGRES_PASSWORD`
   - **DISPLAY NAME**: `Smart Bakery DB`
6. **Test Connection** butonuna basarak bağlantının başarılı olduğunu doğrulayın, ardından **Connect** butonuna tıklayın.
7. **Datasets** menüsünden `+ DATASET` diyerek `fct_satislar`, `fct_israf_ve_fire_analizi`, `fct_ideal_uretim_tavsiyesi`, `dim_musteriler`, `dim_musteri_rfm`, `dim_urunler` veya `dim_tarih` tablolarını ekleyip dashboard ve grafiklerinizi oluşturmaya başlayabilirsiniz.

#### Superset Başlatma Adımları (Manuel İhtiyaç Halinde):

Konteyner otomatik olarak başlatma adımlarını çalıştırsa da, manuel olarak yeniden başlatmak veya çalıştırmak isterseniz:

- **Linux / macOS / Git Bash:**
  ```bash
  bash scripts/init_superset.sh
  ```
- **Windows PowerShell:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/init_superset.ps1
  ```
- **Veya doğrudan Docker komutlarıyla:**
  ```bash
  docker compose exec superset superset db upgrade
  docker compose exec superset superset init
  # Admin kullanıcısını yeniden oluşturmak için (parola .env'deki SUPERSET_ADMIN_PASSWORD'den alınır):
  docker compose run --rm superset-init
  ```

---

## Dashboard Gömme ve Güvenlik

- Streamlit, `app.py` içinde `components.html` ve `@superset-ui/embedded-sdk` kullanarak dashboard 6'yı gömer. Tarayıcıda servis parolası veya Superset erişim token'ı tutulmaz; Streamlit sunucusu kısa ömürlü guest token alıp SDK'ya verir.
- `Public` rolüne izin verilmez ve dashboard'a `Public` erişimi tanımlı değildir. Gömülü oturum `GuestViewer` rolünü kullanır; rol yalnızca dashboard'un kullandığı datasetleri okuyabilir, yazma, dışa aktarma/CSV indirme ve SQL Lab yetkisi yoktur.
- `token_service` hesabı Admin değildir; `TokenService` rolündeki izinler guest token verme ve bu akış için gereken `SecurityRestApi` okumasıyla sınırlıdır.
- Guest token HS256 ile imzalanır ve 300 saniyede sona erer. Uygulama guest token'ı 180 saniye, servis erişim token'ını 240 saniye önbellekler; Streamlit fragmanı 240 saniyede yenilenir.
- CSP `frame-ancestors`, CORS ve dashboard'un embed `allowed_domains` listesi geliştirme ortamında yalnızca `http://localhost:8501` origin'ine açıktır. Yerel HTTP geliştirme yapılandırmasında güvenli çerez zorlaması kapalıdır.
- `.env` Git tarafından yok sayılır; repodaki `.env.example` boş değerli şablondur. Gerekli yerel değişken adları: `POSTGRES_PASSWORD`, `SUPERSET_ADMIN_PASSWORD`, `SUPERSET_SECRET_KEY`, `GUEST_TOKEN_JWT_SECRET`, `SUPERSET_SERVICE_USER`, `SUPERSET_SERVICE_PASSWORD`, `SUPERSET_EMBEDDED_ID`.
- Compose, Superset'e `SQLALCHEMY_DATABASE_URI` değerini `POSTGRES_PASSWORD` üzerinden üretip aktarır. Yapılandırmada varsayılanı bulunan isteğe bağlı değişkenler `APP_ICON`, `FAVICON_PATH`, `REDIS_HOST` ve `REDIS_PORT`'tur.
- Canlıya geçmeden önce HTTPS kullanın, `SESSION_COOKIE_SECURE=True` ayarlayın, CSP/CORS/embed origin'lerini HTTPS adresine güncelleyin ve yerel admin ile PostgreSQL parolalarını döndürün. Gizli değerleri README'ye veya Git'e yazmayın.

---

## Testler

dbt doğrulamaları, model YAML dosyalarındaki test tanımları ve `firin_dbt/tests/` altındaki özel SQL testlerinden oluşur. Testleri çalıştırmak için `firin_dbt/` içinde `dbt build` kullanılır.
- Birincil anahtar tekillik ve boş olmama kontrolleri (`unique`, `not_null`)
- Boyut ve olgu tabloları arası referans bütünlüğü (`relationships`)
- Şube kodları, haftanın günleri, ödeme ve saklama tipleri için kabul edilen değerler (`accepted_values`)
- Fire oranı, puan, adet, tutar ve RFM puanları için değer aralığı kontrolleri (`deger_araliginda`)
- Staging ile mart tabloları arasında satır sayısı ve ciro mutabakatı (`firin_dbt/tests/`)

## Dokümantasyon

- `docs/dbt_docs.html`: dbt docs sayfası (indirilip tarayıcıda açılabilir)
- `docs/DATA_DICTIONARY.md`: veri sözlüğü

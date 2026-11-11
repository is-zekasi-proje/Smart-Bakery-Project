# Smart Bakery

Üç mağazalı bir fırının 2023-2024 satış verisi üzerinde kurulan uçtan uca veri projesi. Veri DuckDB'ye
yüklenir, dbt ile temizlenip analize hazır tablolara dönüştürülür; bu tablolar PostgreSQL'e aktarılarak
Apache Superset dashboard'ları ve tahmin modelleri için kullanılır.

## Veri

Eğitmen onaylı fırın satış veri seti: `data/raw/bakery_sales_dataset.csv`

19.321 satır (sipariş kalemi), 6.576 sipariş, 500 müşteri, 35 ürün ve 3 mağaza içerir; 2023-01-01 ile
2024-12-31 arasını kapsar. Sütun açıklamaları `docs/veri_sozlugu.md` dosyasındadır.

## Veri akışı ve dbt Veri Ambarı Mimarisi

Proje, dbt ile modellenen **toplam 8 modelden** (1 staging, 7 mart) oluşur:

1. `scripts/load_raw_data.py`, CSV dosyasını DuckDB'deki `raw.bakery_sales` tablosuna yükler.
2. **dbt Staging Katmanı (`staging`)**:
   - `stg_firin_satislari`: Ham fırın satış verilerini temizler, sütun adlarını standartlaştırır, tipleri dönüştürür ve boş değerleri doldurur.
3. **dbt Mart Katmanı (`marts`)** - Toplam 7 Analitik Model:
   - `fct_satislar`: Sipariş kalemi bazında satış olgu tablosu (19.321 satır). Ciro, net kâr ve indirim analizlerinin ana tablosudur.
   - `fct_israf_ve_fire_analizi`: **(Yeni Mart Modeli)** SmartBakery 360 gıda israfı ve fire analizi olgu tablosu (16.563 satır).
     - **İş Amacı:** Mağaza, ürün ve gün bazında unlu mamul israfını en aza indirmek, sürdürülebilirlik hedeflerini takip etmek ve finansal fire kaybını izlemek.
     - **Hesaplanan Türkçe Metrikler:** `satilmayan_adet`, `fire_orani`, `birim_maliyet`, `birim_fiyat`, `fire_maliyeti`, `potansiyel_ciro_kaybi`.
     - **Beslediği Superset/BI Grafikleri:** Günlük & Aylık Fire Maliyeti Trendi (Line Chart), Ürün/Kategori Bazlı Fire Dağılımı (Bar Chart), Bozulabilirlik Seviyesine Göre İsraf Oranı (Pie/Donut), Şube Bazlı İsraf Karşılaştırması.
   - `fct_ideal_uretim_tavsiyesi`: **(Yeni Mart Modeli)** SmartBakery 360 karar destek sistemi ideal günlük üretim tavsiyesi tablosu (735 satır).
     - **İş Amacı:** Ürün, mağaza ve haftanın günü bazında geçmiş satış ortalamalarını ve ürünün bozulabilirlik seviyesini analiz ederek fırın ustasına günlük ideal üretim adedi önerisinde bulunmak.
     - **Hesaplanan Türkçe Metrikler:** `ortalama_gunluk_satis`, `min_gunluk_satis`, `max_gunluk_satis`, `ortalama_gecmis_fire_orani`, `guvenlik_stogu_orani` (High: %5, Medium: %10, Low: %15, Very High: %15 — iş kuralı kararı bekliyor), `tavsiye_edilen_uretim_adedi`, `tahmini_uretim_maliyeti`, `tahmini_potansiyel_ciro`.
     - **Beslediği Superset/BI Grafikleri:** Fırın Ustası Günlük Üretim Planlama Çizelgesi (Pivot Table), Gerçekleşen Satış vs. Tavsiye Edilen Üretim Karşılaştırma Grafiği (Dual-Axis Bar/Line), Güvenlik Stoku ve Maliyet Dağılımı.
   - `dim_musteriler`: Müşteri demografik boyut tablosu (500 müşteri). Satın alma davranışı özeti (sipariş sayısı, toplam harcama, ortalama sepet vb.).
   - `dim_musteri_rfm`: **(Yeni Mart Modeli)** Müşteri RFM (Recency, Frequency, Monetary) analiz ve segmentasyon tablosu (500 müşteri).
     - **İş Amacı:** 500 müşterinin alışveriş sıklığı, harcama büyüklüğü ve son temas tarihine göre 1-5 arası ntile puanlamasını yaparak 9 farklı pazarlama segmentine ayırmak ve müşteri sadakatini artırmak.
     - **Eşitlik kuralları:** R/F/M `ntile` puanlarında eşit metrik değerleri `musteri_id` artan sırada çözülür. En sık mağaza ve favori ödeme yöntemi eşitliğinde alfabetik ilk değer seçilir.
     - **Hesaplanan Türkçe Metrikler:** `son_siparisten_gecen_gun` (Yenilik / Recency), `siparis_sayisi` (Sıklık / Frequency), `toplam_harcama` (Parasal Değer / Monetary), `toplam_kar`, `r_skoru` (1-5), `f_skoru` (1-5), `m_skoru` (1-5), `rfm_skoru`, `rfm_ortalama_skor`, `rfm_segmenti` (Şampiyonlar, Sadık Müşteriler, Potansiyel Sadıklar, Yeni Müşteriler, Gelişime Açık, Kaybedilme Riski Yüksek, Dikkat Gerektirenler, Uykudaki Değerliler, Kayıp Müşteriler).
     - **Beslediği Superset/BI Grafikleri:** RFM Müşteri Segmentleri Dağılımı (Treemap / Sunburst), Sadakat Üyeliği vs. RFM Skoru Dağılımı (Boxplot), Segment Başına Ortalama Ciro ve Kârlılık (Bar Chart).
   - `dim_urunler`: Ürün boyutu (35 ürün). Kategori, raf ömrü, saklama tipi, ortalama fiyat/maliyet, toplam satış, ciro ve fire özeti.
   - `dim_tarih`: Takvim boyutu (731 gün, 2023-2024). Mevsim, festival, tatil ve hava durumu bilgileri.
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

Docker Desktop veya Docker Engine'in çalışır durumda olduğundan emin olun:

```bash
# PostgreSQL, Redis, Superset-Init ve Superset web servislerini başlatır:
docker compose up -d
```

> **Not:** `superset-init` servisi ilk çalıştırmada veritabanı migrasyonlarını (`db upgrade`), admin kullanıcısını (`admin` / `admin`) ve yetkileri (`superset init`) otomatik olarak tamamlar. `docker compose logs -f superset-init` komutu ile süreci takip edebilirsiniz.

### 3. Verileri PostgreSQL'e Aktarma

dbt mart Parquet verilerini Docker üzerinde koşan PostgreSQL `smartbakery_db` veritabanına aktarmak için (yerel makineden `localhost:5433` portu kullanılır):

```bash
python import_data.py
# veya
python scripts/import_data.py
```

Aktarım tamamlandığında tüm mart tabloları (`dim_musteriler`, `dim_musteri_rfm`, `dim_urunler`, `dim_tarih`, `fct_satislar`, `fct_israf_ve_fire_analizi`, `fct_ideal_uretim_tavsiyesi`) birincil anahtarları ve performans indeksleriyle birlikte `smartbakery_db` içinde hazır hale gelir.

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
| **Password (Şifre)** | `postgres` |
| **Şema (Schema)** | `public` |
| **JDBC Bağlantı URL** | `jdbc:postgresql://localhost:5433/smartbakery_db` |

---

### 📊 Apache Superset Bağlantı Adresi

Apache Superset web arayüzüne tarayıcınızdan erişebilirsiniz:

- **Web Arayüzü**: [http://localhost:8088](http://localhost:8088)
- **Kullanıcı Adı**: `admin`
- **Şifre**: `admin`

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
   - **PASSWORD**: `postgres`
   - **DISPLAY NAME**: `Smart Bakery DB`
   
   *Veya alternatif olarak gelişmiş bağlantı (SQLAlchemy URI) alanına şunu yazabilirsiniz:*
   ```text
   postgresql+psycopg2://postgres:postgres@postgres:5432/smartbakery_db
   ```
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
  docker compose exec superset superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@smartbakery.com --password admin
  docker compose exec superset superset init
  ```

---

## Testler

`dbt build` sırasında toplam **89 veri kalitesi testi** (tekillik `unique`, boş değer `not_null`, kabul edilen değerler `accepted_values`, referans bütünlüğü `relationships` ve değer aralığı `deger_araliginda`) ve 8 model olmak üzere **97 doğrulama adımı** çalışır:
- Birincil anahtar tekillik ve boş olmama kontrolleri (`unique`, `not_null`)
- Boyut ve olgu tabloları arası referans bütünlüğü (`relationships`)
- Şube kodları, haftanın günleri, ödeme ve saklama tipleri için kabul edilen değer testleri (`accepted_values`)
- Fire oranı (%0-100), puan (1-5), adet (>=1), tutar (>=0) ve RFM puanları (1-5) için değer aralığı kontrolleri (`deger_araliginda`)
- Staging ile mart tabloları arasındaki satır sayısı ve ciro eşitliğini doğrulayan mutabakat testleri (`firin_dbt/tests/`)

## Dokümantasyon

- `docs/dbt_docs.html`: dbt docs sayfası (indirilip tarayıcıda açılabilir)
- `docs/veri_sozlugu.md`: veri sözlüğü

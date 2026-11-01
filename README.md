# Smart Bakery

Üç mağazalı bir fırının 2023-2024 satış verisi üzerinde kurulan uçtan uca veri projesi. Veri DuckDB'ye
yüklenir, dbt ile temizlenip analize hazır tablolara dönüştürülür; bu tablolar PostgreSQL'e aktarılarak
Apache Superset dashboard'ları ve tahmin modelleri için kullanılır.

## Veri

Eğitmen onaylı fırın satış veri seti: `data/raw/bakery_sales_dataset.csv`

19.321 satır (sipariş kalemi), 6.576 sipariş, 500 müşteri, 35 ürün ve 3 mağaza içerir; 2023-01-01 ile
2024-12-31 arasını kapsar. Sütun açıklamaları `docs/veri_sozlugu.md` dosyasındadır.

## Veri akışı

1. `scripts/load_raw_data.py`, CSV dosyasını DuckDB'deki `raw.bakery_sales` tablosuna yükler.
2. dbt staging katmanı (`stg_firin_satislari`) sütunları yeniden adlandırır, tipleri düzeltir ve boş değerleri doldurur.
3. dbt mart katmanı dört tablo üretir:
   - `fct_satislar`: her satır bir sipariş kalemi
   - `dim_musteriler`: müşteri bilgileri ve satın alma özeti
   - `dim_urunler`: ürün bilgileri, satış ve fire özeti
   - `dim_tarih`: takvim, mevsim, festival ve hava bilgisi
4. Mart tabloları `data/marts/` klasörüne Parquet dosyası olarak yazılır (`dim_musteriler.parquet`, `dim_urunler.parquet`, `dim_tarih.parquet`, `fct_satislar.parquet`).
5. `import_data.py` betiği ile Parquet/DuckDB mart verileri Docker üzerinde koşan PostgreSQL (`smartbakery_db`) veritabanına aktarılır.
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

Aktarım tamamlandığında `dim_musteriler`, `dim_urunler`, `dim_tarih` ve `fct_satislar` tabloları birincil anahtarları ve performans indeksleriyle birlikte `smartbakery_db` içinde hazır hale gelir.

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
7. **Datasets** menüsünden `+ DATASET` diyerek `fct_satislar`, `dim_musteriler`, `dim_urunler` veya `dim_tarih` tablolarını ekleyip dashboard ve grafiklerinizi oluşturmaya başlayabilirsiniz.

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

`dbt build` sırasında 49 test çalışır: tekillik, boş değer, kabul edilen değerler, tablolar arası ilişki ve değer
aralığı kontrolleri. Bunlara ek olarak tutar ve kâr hesaplamalarını, staging ile mart tabloları arasındaki satır
sayısı ve ciro eşitliğini kontrol eden testler vardır.

## Dokümantasyon

- `docs/dbt_docs.html`: dbt docs sayfası (indirilip tarayıcıda açılabilir)
- `docs/veri_sozlugu.md`: veri sözlüğü

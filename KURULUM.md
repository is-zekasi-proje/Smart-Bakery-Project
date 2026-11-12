# Smart Bakery — Yeni Bilgisayarda Kurulum

Bu kılavuz, geliştirme ortamını yerel bilgisayarda kurar. Gizli değerleri bu dosyaya veya Git'e yazmayın.

## Gereksinimler

- Git: `git --version`
- Docker Desktop: kurulu ve çalışır olmalı; kontrol için `docker info`
- Python 3.11 veya üzeri: `python3 --version`
- macOS'ta Homebrew gerekebilir; kurulum notları aşağıdadır.

## Kurulum

1. **Depoyu klonlayın ve proje klasörüne geçin:**

   ```bash
   git clone https://github.com/is-zekasi-proje/Smart-Bakery-Project.git
   cd Smart-Bakery-Project
   ```

2. **Sanal ortamı oluşturun ve bağımlılıkları kurun:**

   Windows PowerShell:

   ```powershell
   py -3 -m venv .venv
   .\.venv\Scripts\Activate.ps1
   python -m pip install -r requirements.txt
   ```

   macOS:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   python -m pip install -r requirements.txt
   ```

3. **`.env` dosyasını oluşturun:**

   Windows PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   macOS:

   ```bash
   cp .env.example .env
   ```

   `.env` içindeki değişkenleri kendi yerel ortamınıza göre doldurun:

   | Değişken | Kullanım |
   | --- | --- |
   | `POSTGRES_PASSWORD` | PostgreSQL parolası; Compose bağlantılarında ve aktarım betiğinde kullanılır. |
   | `SUPERSET_ADMIN_PASSWORD` | `superset-init` tarafından oluşturulan yerel Superset admin hesabının parolası. |
   | `SUPERSET_SECRET_KEY` | Superset uygulama anahtarı. |
   | `GUEST_TOKEN_JWT_SECRET` | Guest JWT imza anahtarı; `SUPERSET_SECRET_KEY` değerinden farklı olmalıdır. |
   | `SUPERSET_SERVICE_USER` | Guest token isteyen, Admin olmayan Superset servis hesabının kullanıcı adı. |
   | `SUPERSET_SERVICE_PASSWORD` | Bu servis hesabının parolası. |
   | `SUPERSET_EMBEDDED_ID` | Dashboard'un Superset embed kaydından dönen UUID. |

   Gizli anahtar ve parolalar için her değer ayrı ve güçlü olmalıdır. Rastgele değer üretmek için:

   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

4. **Ham veriyi yükleyin ve dbt modellerini üretin:**

   Proje kökünde:

   ```bash
   python scripts/load_raw_data.py
   cd firin_dbt
   dbt build
   cd ..
   ```

5. **Docker servislerini başlatın ve init'in bitmesini bekleyin:**

   Docker Desktop'ın çalıştığını doğruladıktan sonra proje kökünde:

   ```bash
   docker compose up -d
   docker compose logs -f superset-init
   ```

   `superset-init` tamamlanınca servis durumunu `docker compose ps -a superset-init` ile kontrol edin. Init servisi veritabanı migrasyonlarını, admin hesabını ve varsayılan Superset izinlerini kurar; aşağıdaki özel embedding ayarlarını oluşturmaz.

6. **Mart verisini PostgreSQL'e aktarın:**

   Docker PostgreSQL hazır olduktan sonra, proje kökünde:

   ```bash
   python import_data.py
   ```

7. **Superset'i yapılandırın:**

   Superset'e `http://localhost:8088` adresinden, yerel admin hesabıyla giriş yapın. PostgreSQL bağlantısını Superset'e ekleme adımları ve bağlantı bilgileri için README'deki Superset bağlantı bölümüne bakın: [README.md](README.md).

8. **Streamlit dashboard'unu çalıştırın:**

   Proje kökünde:

   ```bash
   streamlit run app.py --server.port 8501
   ```

   Tarayıcıda [http://localhost:8501](http://localhost:8501) adresini açın. Streamlit ilk çalıştırmada e-posta sorarsa boş bırakıp Enter'a basın. 8501 portu doluysa başka port kullanmayın; Superset CSP/CORS ve embed domain yalnızca `http://localhost:8501` adresine izin verir.

## Gömülü dashboard için ek kurulum

`docker compose up -d` ve `superset-init`, aşağıdaki embedding kaynaklarını oluşturmaz. Yeni bilgisayarda bunlar bir Superset yöneticisi tarafından ayrıca hazırlanmalıdır:

1. **`GuestViewer` rolü:** Public veya Gamma rolünü kopyalamadan ayrı bir rol oluşturun. Dashboard, Chart, Dataset, CurrentUserRestApi ve EmbeddedDashboard için `can_read`; Superset için `can_dashboard` ve `can_explore_json` izinlerini ekleyin. Ayrıca yalnızca dashboard'un kullandığı `dim_musteri_rfm`, `dim_urunler`, `fct_ideal_uretim_tavsiyesi`, `fct_israf_ve_fire_analizi` ve `fct_satislar` datasetlerine `datasource_access` verin. Yazma, dışa aktarma ve SQL Lab izinleri eklemeyin.
2. **Servis hesabı:** Admin olmayan servis kullanıcısı oluşturun ve bu kullanıcıya ayrı `TokenService` rolünü verin. Rolde yalnızca `can_grant_guest_token` ve `can_read` on `SecurityRestApi` izinleri bulunmalıdır. Kullanıcı adı/parolası `.env` içindeki `SUPERSET_SERVICE_USER` ve `SUPERSET_SERVICE_PASSWORD` ile eşleşmelidir.
3. **Embed kaydı:** Dashboard 6 için embed kaydı oluşturun; `allowed_domains` yalnızca `http://localhost:8501` olmalıdır. Dönen embedded UUID'yi `.env` içindeki `SUPERSET_EMBEDDED_ID` değişkenine yazın.

Bu rolün ve servis hesabının izinleri mevcut Superset API'sinde kontrol edilmiştir; ancak dashboard embed kaydının yeni bir Superset kurulumunda oluşturulma adımları bu depodaki Compose veya scriptlerle otomatikleştirilmemiştir. Embed oluşturma arayüzündeki adımlar burada **doğrulanmadı**; API üzerinden oluşturma gerekiyorsa Superset sürümünüzün API dokümantasyonunu kullanın.

## macOS notları

- Homebrew ile Python kurulumu: `brew install python`
- Docker Desktop kurulumu: `brew install --cask docker`; ardından Docker Desktop'ı açıp çalışır duruma gelmesini bekleyin.
- Apple Silicon Mac'lerde Docker Desktop'ın Apple chip sürümünü kullanın. Bu projede ayrıca bir mimari override gereksinimi **doğrulanmadı**.
- macOS'ta 5000 portu AirPlay Receiver tarafından kullanılabilir. Bu uygulama 8501 portunu kullanır; Superset embed ayarları nedeniyle uygulamayı başka porta taşımayın.

## Sık karşılaşılan sorunlar

| Sorun | Kontrol / çözüm |
| --- | --- |
| Docker çalışmıyor | Docker Desktop'ı açın, hazır olmasını bekleyin ve `docker info` çalıştırın. |
| 8501 portu dolu | 8501'i kullanan uygulamayı kapatıp Streamlit'i `--server.port 8501` ile yeniden başlatın. Başka port embed origin ayarlarıyla eşleşmez. |
| `localhost refused to connect` | Streamlit'in çalıştığını ve `http://localhost:8501` adresinde dinlediğini kontrol edin; terminaldeki başlangıç hatasını inceleyin. |
| “Something went wrong with embedded authentication” | `SUPERSET_SERVICE_USER`, `SUPERSET_SERVICE_PASSWORD` ve `SUPERSET_EMBEDDED_ID` değerlerini; `TokenService` izinlerini ve embed domain'inin 8501 olduğunu kontrol edin. |
| Dashboard boş | `GuestViewer` dataset izinlerini, dashboard embed kaydını ve Superset'teki PostgreSQL veritabanı bağlantısını kontrol edin. |
| `docker compose` `.env` eksik diye hata veriyor | `.env.example` dosyasını `.env` olarak kopyalayıp Compose'un istediği değişkenleri doldurun. Gizli değerleri hata çıktısına veya Git'e koymayın. |

## Güvenlik

`.env` dosyasını paylaşmayın veya commit etmeyin. Gerçek parolaları ve anahtarları kaynak dosyalarına yazmayın. Yerel admin, servis hesabı ve PostgreSQL parolalarını canlıya geçmeden önce döndürün; canlı ortamda HTTPS ve HTTPS origin'leri kullanın.

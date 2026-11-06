import os

# =============================================================================
# 1. Uygulama Markalaması (Branding)
# =============================================================================
APP_NAME = "SmartBakery 360 BI"
APP_ICON = os.environ.get("APP_ICON", "/static/assets/images/superset-logo-horiz.png")
FAVICON_PATH = os.environ.get("FAVICON_PATH", "/static/assets/images/favicon.png")

# =============================================================================
# 2. Güvenlik ve Gizli Anahtarlar
# =============================================================================
# Superset Güvenlik Anahtarı (Oturum ve çerez şifreleme)
SECRET_KEY = os.environ.get(
    "SUPERSET_SECRET_KEY", "smart_bakery_secret_key_superset_2024!"
)

# Web sunucu portu
SUPERSET_WEBSERVER_PORT = 8088

# Yerel geliştirme ortamı için Talisman HTTPS zorunluluğunu devre dışı bırak
TALISMAN_ENABLED = False
WTF_CSRF_ENABLED = True

# =============================================================================
# 3. Iframe ve Gömme (Embedding) Güvenliği
# =============================================================================
# Streamlit veya harici web uygulamasından panoları gömebilmek (iframe) için izinler
HTTP_HEADERS = {"X-Frame-Options": "ALLOWALL"}
OVERRIDE_HTTP_HEADERS = {"X-Frame-Options": "ALLOWALL"}

# Guest Token (Konuk Belirteci) Ayarları
GUEST_ROLE_NAME = "Gamma"
GUEST_TOKEN_JWT_SECRET = os.environ.get(
    "GUEST_TOKEN_JWT_SECRET", "smart_bakery_guest_token_secret_jwt_2024!"
)
GUEST_TOKEN_JWT_ALGO = "HS256"
GUEST_TOKEN_JWT_EXP_SECONDS = 3600

# =============================================================================
# 4. CORS (Cross-Origin Resource Sharing) Yapılandırması
# =============================================================================
ENABLE_CORS = True
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": ["*"],
    "resources": ["*"],
    "origins": [
        "http://localhost:8501",  # Streamlit
        "http://localhost:3000",  # Harici Web / React
    ],
}

# =============================================================================
# 5. Dil Desteği (Localization / Dil)
# =============================================================================
BABEL_DEFAULT_LOCALE = "tr"
LANGUAGES = {
    "tr": {"flag": "tr", "name": "Turkish"},
    "en": {"flag": "us", "name": "English"},
}

# =============================================================================
# 6. Özellik Bayrakları (Feature Flags)
# =============================================================================
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "DASHBOARD_RBAC": True,
    "EMBEDDED_SUPERSET": True,
}

# =============================================================================
# 7. Veritabanı ve Önbellek (PostgreSQL & Redis)
# =============================================================================
# Superset Metadata Veritabanı URI
SQLALCHEMY_DATABASE_URI = os.environ.get(
    "SQLALCHEMY_DATABASE_URI",
    "postgresql+psycopg2://postgres:postgres@postgres:5432/superset",
)

# Redis Önbellek Yapılandırması
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_cache_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 1,
}

DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_data_cache_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 2,
}

FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_filter_cache_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 3,
}

EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_explore_cache_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 4,
}

# Sorgu satır limiti
ROW_LIMIT = 50000

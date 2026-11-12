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
SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# Web sunucu portu
SUPERSET_WEBSERVER_PORT = 8088

TALISMAN_ENABLED = True
# Local HTTP only; enable secure cookies and HTTPS redirection when using HTTPS.
TALISMAN_CONFIG = {
    "force_https": False,
    "session_cookie_secure": False,
    "content_security_policy": {
        "frame-ancestors": ["http://localhost:8501"],
    },
    "frame_options": None,
}
WTF_CSRF_ENABLED = True

# =============================================================================
# 3. Gömme (Embedding) Güvenliği
# =============================================================================
GUEST_ROLE_NAME = "GuestViewer"
GUEST_TOKEN_JWT_SECRET = os.environ["GUEST_TOKEN_JWT_SECRET"]
GUEST_TOKEN_JWT_ALGO = "HS256"
GUEST_TOKEN_HEADER_NAME = "X-GuestToken"
GUEST_TOKEN_JWT_EXP_SECONDS = 300

# =============================================================================
# 4. CORS (Cross-Origin Resource Sharing) Yapılandırması
# =============================================================================
ENABLE_CORS = True
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": ["*"],
    "resources": ["*"],
    "origins": ["http://localhost:8501"],
}
PUBLIC_ROLE_PERMISSIONS = []

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
SQLALCHEMY_DATABASE_URI = os.environ["SQLALCHEMY_DATABASE_URI"]

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

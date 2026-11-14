"""
Configuración de Django para el Sistema de Órdenes de Trabajo.
La conexión a SQL Server se toma de variables de entorno (o de los valores por defecto).
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Lee web/.env (si existe) para que cada integrante ponga SU contraseña
# sin modificar este archivo ni subirla a GitHub. Ver .env.example.
_env = BASE_DIR / ".env"
if _env.exists():
    for _linea in _env.read_text(encoding="utf-8").splitlines():
        _linea = _linea.strip()
        if _linea and not _linea.startswith("#") and "=" in _linea:
            _k, _v = _linea.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "cambie-esta-clave-en-produccion")
DEBUG = os.getenv("DJANGO_DEBUG", "1") == "1"
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.humanize",
    "core",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
]

ROOT_URLCONF = "taller_web.urls"
WSGI_APPLICATION = "taller_web.wsgi.application"

TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
        "core.equipo.contexto_equipo",
    ]},
}]

# ---------------------------------------------------------------
# SQL Server (obligatorio). Requiere "ODBC Driver 18 for SQL Server".
# Con autenticación de Windows deje DB_USER vacío.
# ---------------------------------------------------------------
DB_USER = os.getenv("DB_USER", "sa")
DATABASES = {
    "default": {
        "ENGINE": "mssql",
        "NAME": os.getenv("DB_NAME", "TallerDB"),
        "HOST": os.getenv("DB_HOST", "localhost"),
        "PORT": os.getenv("DB_PORT", ""),
        "USER": DB_USER,
        "PASSWORD": os.getenv("DB_PASSWORD", "TuPassword123"),
        "OPTIONS": {
            "driver": "ODBC Driver 18 for SQL Server",
            "extra_params": "TrustServerCertificate=yes" + ("" if DB_USER else ";Trusted_Connection=yes"),
        },
    }
}

LANGUAGE_CODE = "es"
TIME_ZONE = "America/Guatemala"
USE_I18N = True
USE_TZ = False          # SQL Server guarda la hora local (SYSDATETIME)
USE_THOUSAND_SEPARATOR = True

STATIC_URL = "static/"
LOGIN_URL = "login"
LOGIN_REDIRECT_URL = "inicio"
LOGOUT_REDIRECT_URL = "login"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

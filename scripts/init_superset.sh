#!/usr/bin/env bash
# Apache Superset Başlatma ve Yapılandırma Betiği (Linux / macOS / Git Bash)
set -e

echo "========================================================"
echo " Smart Bakery - Apache Superset Başlatma Adımları"
echo "========================================================"

echo "Superset veritabanı, admin kullanıcısı, roller ve izinler yapılandırılıyor (superset-init)..."
docker compose run --rm superset-init

echo "========================================================"
echo " Superset başarıyla yapılandırıldı!"
echo " Arayüze erişim : http://localhost:8088"
echo " Kullanıcı Adı  : admin"
echo " Admin parolası .env içindeki SUPERSET_ADMIN_PASSWORD değişkenindedir."
echo "========================================================"


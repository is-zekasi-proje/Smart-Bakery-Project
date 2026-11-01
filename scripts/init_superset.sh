#!/usr/bin/env bash
# Apache Superset Başlatma ve Yapılandırma Betiği (Linux / macOS / Git Bash)
set -e

echo "========================================================"
echo " Smart Bakery - Apache Superset Başlatma Adımları"
echo "========================================================"

echo "1/3: Superset veritabanı şeması güncelleniyor (db upgrade)..."
docker compose exec -T superset superset db upgrade

echo "2/3: Admin kullanıcısı oluşturuluyor (admin / admin)..."
docker compose exec -T superset superset fab create-admin \
  --username admin \
  --firstname Superset \
  --lastname Admin \
  --email admin@smartbakery.com \
  --password admin || echo "Admin kullanıcısı zaten mevcut."

echo "3/3: Superset rolleri ve izinleri yapılandırılıyor (superset init)..."
docker compose exec -T superset superset init

echo "========================================================"
echo " Superset başarıyla yapılandırıldı!"
echo " Arayüze erişim : http://localhost:8088"
echo " Kullanıcı Adı  : admin"
echo " Şifre          : admin"
echo "========================================================"


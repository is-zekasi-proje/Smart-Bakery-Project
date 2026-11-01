# Apache Superset Başlatma ve Yapılandırma Betiği (Windows PowerShell)

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Smart Bakery - Apache Superset Başlatma Adımları" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "1/3: Superset veritabanı şeması güncelleniyor (db upgrade)..." -ForegroundColor Yellow
docker compose exec superset superset db upgrade

Write-Host "2/3: Admin kullanıcısı oluşturuluyor (admin / admin)..." -ForegroundColor Yellow
docker compose exec superset superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@smartbakery.com --password admin

Write-Host "3/3: Superset rolleri ve izinleri yapılandırılıyor (superset init)..." -ForegroundColor Yellow
docker compose exec superset superset init

Write-Host "========================================================" -ForegroundColor Green
Write-Host " Superset başarıyla yapılandırıldı!" -ForegroundColor Green
Write-Host " Arayüze erişim : http://localhost:8088" -ForegroundColor Green
Write-Host " Kullanıcı Adı  : admin" -ForegroundColor Green
Write-Host " Şifre          : admin" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green


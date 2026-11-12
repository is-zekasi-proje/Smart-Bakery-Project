# Apache Superset Başlatma ve Yapılandırma Betiği (Windows PowerShell)

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Smart Bakery - Apache Superset Başlatma Adımları" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "Superset veritabanı, admin kullanıcısı, roller ve izinler yapılandırılıyor (superset-init)..." -ForegroundColor Yellow
docker compose run --rm superset-init

Write-Host "========================================================" -ForegroundColor Green
Write-Host " Superset başarıyla yapılandırıldı!" -ForegroundColor Green
Write-Host " Arayüze erişim : http://localhost:8088" -ForegroundColor Green
Write-Host " Kullanıcı Adı  : admin" -ForegroundColor Green
Write-Host " Admin parolası .env içindeki SUPERSET_ADMIN_PASSWORD değişkenindedir." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green


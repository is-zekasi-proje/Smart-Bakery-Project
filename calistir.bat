@chcp 65001 >nul
@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 goto project_dir_error

call docker info >nul 2>&1
if errorlevel 1 goto docker_error

if not exist ".env" goto env_error

echo Docker servisleri baslatiliyor...
call docker compose up -d --no-recreate
if errorlevel 1 goto compose_error

echo Superset bekleniyor. Ilk acilis 1-2 dakika surebilir...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$deadline=(Get-Date).AddSeconds(180); do { try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8088/health' -TimeoutSec 3; if ($r.StatusCode -eq 200) { exit 0 } } catch {}; Start-Sleep -Seconds 3 } while ((Get-Date) -lt $deadline); exit 1"
if errorlevel 1 goto superset_timeout

powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 8501 -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 goto streamlit_exists
goto launch_streamlit

:launch_streamlit
ver >nul
if not exist ".venv\Scripts\python.exe" goto venv_error

if not exist "%USERPROFILE%\.streamlit" mkdir "%USERPROFILE%\.streamlit"
if errorlevel 1 goto credentials_error
if not exist "%USERPROFILE%\.streamlit\credentials.toml" (
    >"%USERPROFILE%\.streamlit\credentials.toml" echo [general]
    >>"%USERPROFILE%\.streamlit\credentials.toml" echo email = ""
)
if errorlevel 1 goto credentials_error

echo Streamlit baslatiliyor...
start "Smart Bakery - Streamlit" "%CD%\.venv\Scripts\python.exe" -m streamlit run app.py --server.port 8501
if errorlevel 1 goto streamlit_start_error

powershell -NoProfile -ExecutionPolicy Bypass -Command "$deadline=(Get-Date).AddSeconds(45); do { if (Get-NetTCPConnection -LocalPort 8501 -State Listen -ErrorAction SilentlyContinue) { exit 0 }; Start-Sleep -Seconds 1 } while ((Get-Date) -lt $deadline); exit 1"
if errorlevel 1 goto streamlit_timeout

start "" "http://localhost:8501"
echo Kapatmak için Streamlit penceresini kapatın. Docker'ı durdurmak için: docker compose stop (veriler korunur).
exit /b 0

:streamlit_exists
echo Streamlit zaten çalışıyor olabilir: http://localhost:8501
start "" "http://localhost:8501"
echo Kapatmak için Streamlit penceresini kapatın. Docker'ı durdurmak için: docker compose stop (veriler korunur).
exit /b 0

:project_dir_error
echo Proje klasörüne geçilemedi.
goto failed

:docker_error
echo Docker Desktop'ı açın.
goto failed

:env_error
echo Önce KURULUM.md'yi izleyin, .env dosyası eksik.
goto failed

:compose_error
echo Docker servisleri başlatılamadı.
goto failed

:superset_timeout
echo Superset zaman aşımına uğradı. Docker loglarını kontrol edin.
goto failed

:venv_error
echo .venv bulunamadı. KURULUM.md'yi izleyin.
goto failed

:credentials_error
echo Streamlit credentials.toml oluşturulamadı.
goto failed

:streamlit_start_error
echo Streamlit başlatılamadı.
goto failed

:streamlit_timeout
echo Streamlit 45 saniye içinde 8501 portunda yanıt vermedi. Streamlit penceresini kontrol edin.
goto failed

:failed
pause
exit /b 1

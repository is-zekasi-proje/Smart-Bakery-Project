"""
Smart Bakery - PostgreSQL Veri Aktarım Betiği

Kullanım:
    python import_data.py
    # veya
    python scripts/import_data.py
"""
import sys
from pathlib import Path

# Proje kökünü sys.path'e ekle
PROJECT_ROOT = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.import_data import main

if __name__ == "__main__":
    main()


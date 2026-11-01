"""
dbt dokümantasyonunu repoya aktarır:
  1. docs/dbt_docs.html   -> tek dosyalık dbt docs sitesi (tarayıcıda açılır)
  2. docs/veri_sozlugu.md -> tablo ve sütunların veri sözlüğü

Çalıştırma (proje kök klasöründen), önce firin_dbt/ içinde dokümantasyon üretilmeli:
    cd firin_dbt && dbt docs generate --static && cd ..
    python scripts/generate_docs.py

Açıklamalar dbt yml dosyalarından okunur. Sözlüğü güncellemek için yml'i düzenleyip
yukarıdaki iki komutu tekrar çalıştırmak yeterlidir; veri_sozlugu.md elle düzenlenmemelidir.
"""
import json
import shutil
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TARGET_DIR = PROJECT_ROOT / "firin_dbt" / "target"
DOCS_DIR = PROJECT_ROOT / "docs"

# Sözlükteki tablo sırası: önce olgu, sonra boyutlar, en son staging.
TABLO_SIRASI = ["fct_satislar", "dim_musteriler", "dim_urunler", "dim_tarih", "stg_firin_satislari"]


def test_etiketi(test: dict) -> str:
    """Bir generic testi sözlükte gösterilecek kısa bir metne çevirir."""
    meta = test["test_metadata"]
    ad, args = meta["name"], meta["kwargs"]
    if ad == "relationships":
        hedef = args["to"].removeprefix("ref('").removesuffix("')")
        return f"relationships: {hedef}.{args['field']}"
    if ad == "deger_araliginda":
        alt = args.get("min_deger", "")
        ust = args.get("max_deger", "")
        return f"aralık [{alt}, {ust}]" if ust != "" else f">= {alt}"
    if ad == "accepted_values":
        return "accepted_values"
    return ad


def tek_satir(metin: str) -> str:
    """Markdown tablosunu bozmasın diye metni tek satıra indirir."""
    return " ".join(metin.split()).replace("|", "\\|")


def main() -> None:
    manifest_path = TARGET_DIR / "manifest.json"
    static_path = TARGET_DIR / "static_index.html"
    for yol in (manifest_path, TARGET_DIR / "catalog.json", static_path):
        if not yol.exists():
            raise FileNotFoundError(f"{yol} yok. Önce firin_dbt/ içinde `dbt docs generate --static` çalıştırın.")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    catalog = json.loads((TARGET_DIR / "catalog.json").read_text(encoding="utf-8"))
    DOCS_DIR.mkdir(exist_ok=True)

    # 1) Tek dosyalık dbt docs sitesini kopyala
    shutil.copyfile(static_path, DOCS_DIR / "dbt_docs.html")

    # 2) Testleri sütunlara göre grupla
    sutun_testleri = defaultdict(list)
    is_kurali_testleri = []
    for node in manifest["nodes"].values():
        if node["resource_type"] != "test":
            continue
        if node.get("test_metadata"):
            anahtar = (node["attached_node"], node["column_name"])
            sutun_testleri[anahtar].append(test_etiketi(node))
        else:
            is_kurali_testleri.append(node)

    modeller = {n["name"]: n for n in manifest["nodes"].values() if n["resource_type"] == "model"}
    satirlar = [
        "# Veri Sözlüğü",
        "",
        "> Bu dosya `scripts/generate_docs.py` ile dbt dokümantasyonundan **otomatik üretilir**; elle düzenlemeyin.",
        "> Açıklamaları değiştirmek için `firin_dbt/models/**/_*.yml` dosyalarını güncelleyin.",
        "",
        "Analiz ve dashboard için **`marts`** tablolarını kullanın (dosya olarak: `data/marts/<tablo>.parquet`).",
        "Tip sütunu DuckDB'deki tipi gösterir; Parquet dosyalarında `DECIMAL` sütunlar `DOUBLE` (ondalıklı sayı) olarak yazılır.",
        "",
        "## Tablolar",
        "",
        "| Tablo | Şema | Sütun | Açıklama |",
        "|---|---|---|---|",
    ]
    for ad in TABLO_SIRASI:
        model = modeller[ad]
        aciklama = tek_satir(model["description"]).split(". ")[0].rstrip(".") + "."
        satirlar.append(f"| [`{ad}`](#{ad}) | `{model['schema']}` | {len(model['columns'])} | {aciklama} |")

    for ad in TABLO_SIRASI:
        model = modeller[ad]
        tipler = catalog["nodes"].get(model["unique_id"], {}).get("columns", {})
        satirlar += [
            "",
            f"## {ad}",
            "",
            f"**Şema:** `{model['schema']}`, **Tip:** {model['config']['materialized']}"
            f", **Kaynak kod:** `firin_dbt/{model['original_file_path']}`",
            "",
            tek_satir(model["description"]),
            "",
            "| Sütun | Tip | Açıklama | Testler |",
            "|---|---|---|---|",
        ]
        for sutun_adi, sutun in model["columns"].items():
            tip = tipler.get(sutun_adi, {}).get("type", "")
            testler = ", ".join(sorted(sutun_testleri.get((model["unique_id"], sutun_adi), [])))
            satirlar.append(f"| `{sutun_adi}` | {tip} | {tek_satir(sutun['description'])} | {testler} |")

    satirlar += [
        "",
        "## İş kuralı ve mutabakat testleri",
        "",
        "Sütun testlerine ek olarak `firin_dbt/tests/` klasöründeki testler:",
        "",
        "| Test | Açıklama |",
        "|---|---|",
    ]
    for test in sorted(is_kurali_testleri, key=lambda t: t["name"]):
        satirlar.append(f"| `{test['name']}` | {tek_satir(test['description'])} |")

    (DOCS_DIR / "veri_sozlugu.md").write_text("\n".join(satirlar) + "\n", encoding="utf-8")
    print(f"Yazıldı: docs/dbt_docs.html ve docs/veri_sozlugu.md ({len(TABLO_SIRASI)} tablo)")


if __name__ == "__main__":
    main()

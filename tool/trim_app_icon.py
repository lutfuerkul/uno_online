#!/usr/bin/env python3
"""Yüklenen ikonu ortadan kare kırpar; tüm launcher boyutlarını üretir."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "assets/icons"
SRC = ICON_DIR / "app_icon_source.png"
OUT = ICON_DIR / "app_icon_source.png"
SIZES = {
    "assets/icons/app_icon.png": 512,
    "docs/icons/icon-192.png": 192,
    "docs/icons/icon-512.png": 512,
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}


def _find_upload() -> Path:
    uploads = sorted(ICON_DIR.glob("1784*.png"), key=lambda p: p.stat().st_mtime, reverse=True)
    if uploads:
        return uploads[0]
    if SRC.exists():
        return SRC
    raise SystemExit("Yüklenecek ikon bulunamadı (assets/icons/1784*.png).")


def center_crop_square(im: Image.Image) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return im.crop((left, top, left + side, top + side))


def main() -> None:
    upload = _find_upload()
    master = center_crop_square(Image.open(upload))
    master.save(OUT, format="PNG", optimize=True)
    for rel, size in SIZES.items():
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG", optimize=True)
    print(f"Kaynak: {upload.name} → {master.size[0]}×{master.size[1]} kare, {len(SIZES) + 1} dosya.")


if __name__ == "__main__":
    main()

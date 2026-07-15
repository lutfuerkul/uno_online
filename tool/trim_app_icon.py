#!/usr/bin/env python3
"""Kaynak ikondaki gri/beyaz kenar boşluğunu kırpar, tam kareye doldurur."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/icons/app_icon_source.png"
OUT = ROOT / "assets/icons/app_icon_source.png"
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

# Orijinal ikondan örneklenen kenar renkleri (sol mavi / sağ turuncu)
_EDGE_BLUE = (39, 70, 186)
_EDGE_ORANGE = (234, 95, 10)


def _is_background(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return True
    avg = (r + g + b) / 3
    neutral = max(r, g, b) - min(r, g, b) < 28
    if neutral and avg > 130:
        return True
    return False


def _is_grey_frame(r: int, g: int, b: int, a: int) -> bool:
    if a < 40:
        return False
    sat = max(r, g, b) - min(r, g, b)
    avg = (r + g + b) / 3
    return sat < 35 and avg > 115


def trim_to_content(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not _is_background(r, g, b, a):
                minx = min(minx, x)
                miny = min(miny, y)
                maxx = max(maxx, x)
                maxy = max(maxy, y)
    if maxx <= minx or maxy <= miny:
        cropped = im
    else:
        cropped = im.crop((minx, miny, maxx + 1, maxy + 1))
    cw, ch = cropped.size
    side = max(cw, ch)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - cw) // 2, (side - ch) // 2))
    return square.resize((1024, 1024), Image.Resampling.LANCZOS)


def remove_grey_frame(im: Image.Image) -> Image.Image:
    """Tasarımdaki açık gri dış halkayı sol/sağ gradyan rengiyle doldurur."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not _is_grey_frame(r, g, b, a):
                continue
            t = x / max(w - 1, 1)
            nr = int(_EDGE_BLUE[0] * (1 - t) + _EDGE_ORANGE[0] * t)
            ng = int(_EDGE_BLUE[1] * (1 - t) + _EDGE_ORANGE[1] * t)
            nb = int(_EDGE_BLUE[2] * (1 - t) + _EDGE_ORANGE[2] * t)
            px[x, y] = (nr, ng, nb, 255)
    # Launcher şeffaf köşeleri beyaz göstermesin diye opak RGB'ye çevir
    flat = Image.new("RGB", im.size, _EDGE_BLUE)
    flat.paste(im, mask=im.split()[3])
    return flat


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Kaynak bulunamadı: {SRC}")
    master = remove_grey_frame(trim_to_content(Image.open(SRC)))
    master.save(OUT, format="PNG", optimize=True)
    for rel, size in SIZES.items():
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG", optimize=True)
    print(f"İkon kırpıldı ve {len(SIZES) + 1} dosya güncellendi.")


if __name__ == "__main__":
    main()

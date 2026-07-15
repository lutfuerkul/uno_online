#!/usr/bin/env python3
"""Launcher ikonunu orijinal boyut ve renklerle üretir; sadece dış gri boşluğu doldurur."""

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


def _is_outer_grey(r: int, g: int, b: int) -> bool:
    sat = max(r, g, b) - min(r, g, b)
    avg = (r + g + b) / 3
    return sat < 28 and avg > 175


def _content_bounds(im: Image.Image) -> tuple[int, int, int, int]:
    px = im.load()
    w, h = im.size
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y][:3]
            if _is_outer_grey(r, g, b):
                continue
            minx = min(minx, x)
            miny = min(miny, y)
            maxx = max(maxx, x)
            maxy = max(maxy, y)
    if maxx <= minx or maxy <= miny:
        return 0, 0, w - 1, h - 1
    return minx, miny, maxx, maxy


def _first_color_toward_center(
    px, x: int, y: int, w: int, h: int
) -> tuple[int, int, int]:
    mx, my = w // 2, h // 2
    steps = max(abs(mx - x), abs(my - y))
    for i in range(steps + 1):
        t = i / max(steps, 1)
        sx = int(round(x + (mx - x) * t))
        sy = int(round(y + (my - y) * t))
        r, g, b = px[sx, sy][:3]
        if not _is_outer_grey(r, g, b):
            return r, g, b
    return px[x, y][:3]


def fill_outer_grey_margin(im: Image.Image) -> Image.Image:
    """İçerik kırpılmaz; yalnızca dış gri şerit, kenar renkleriyle doldurulur."""
    im = im.convert("RGB")
    px = im.load()
    w, h = im.size
    minx, miny, maxx, maxy = _content_bounds(im)

    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if not _is_outer_grey(r, g, b):
                continue
            in_margin = x < minx or x > maxx or y < miny or y > maxy
            if not in_margin:
                continue
            src_x = min(max(x, minx), maxx)
            src_y = min(max(y, miny), maxy)
            edge = px[src_x, src_y][:3]
            if _is_outer_grey(*edge):
                px[x, y] = _first_color_toward_center(px, x, y, w, h)
            else:
                px[x, y] = edge

    return im


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Kaynak bulunamadı: {SRC}")
    master = fill_outer_grey_margin(Image.open(SRC))
    if master.size != (1024, 1024):
        master = master.resize((1024, 1024), Image.Resampling.LANCZOS)
    master.save(OUT, format="PNG", optimize=True)
    for rel, size in SIZES.items():
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG", optimize=True)
    print(f"İkon güncellendi; {len(SIZES) + 1} dosya yazıldı (1024×1024, kırpma yok).")


if __name__ == "__main__":
    main()

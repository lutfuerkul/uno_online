#!/usr/bin/env python3
"""Kök dizindeki UNO sprite SVG'lerini tek kartlık PNG'lere böler.

Kaynaklar (tasarım dosyaları, repo kökünde):
  - uno_kartlari_on_yuz.svg  : 4 renk x 0-9 sayı kartları (10 sütun x 4 satır)
  - uno_ozel_kartlar_v6.svg  : +2 / ⊘ / tekrar (4 renk) + joker ve +4
  - uno_kart_arka_yuz.svg    : kart arka yüzü

Her kart hücresi 120x180 birimdir; hücre içeriği bağımsız bir SVG'ye sarılır ve
başsız Chromium ile 4x çözünürlükte (480x720), şeffaf zeminli PNG'ye çevrilip
assets/uno_cards/ altına yazılır. Flutter tarafı bu PNG'leri kullanır
(lib/widgets/card_widget.dart).

Kullanım:  python3 tool/split_uno_cards.py
"""
import os
import re
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "uno_cards")
CHROMIUM = os.environ.get("CHROMIUM_BIN", "/opt/pw-browsers/chromium")
CARD_W, CARD_H = 120, 180
SCALE = 4


def split_top_groups(svg_text):
    """Üst seviye <g transform="translate(x,y)"> gruplarını (x, y, iç içerik)
    olarak döndürür. İç içe <g> etiketlerini dengeleyerek ayrıştırır."""
    groups = []
    for m in re.finditer(r'<g transform="translate\((\d+),(\d+)\)">', svg_text):
        x, y = int(m.group(1)), int(m.group(2))
        depth = 1
        pos = m.end()
        while depth > 0:
            nxt = re.search(r"<g[\s>]|</g>", svg_text[pos:])
            if nxt is None:
                raise ValueError("dengesiz <g> etiketi")
            if svg_text[pos + nxt.start():].startswith("</g>"):
                depth -= 1
            else:
                depth += 1
            pos += nxt.end()
        inner = svg_text[m.end():pos - len("</g>")]
        groups.append((x, y, inner))
    return groups


def wrap_cell(inner):
    """Bir hücrenin içeriğini 120x180 bağımsız SVG'ye sarar. Kart alanının
    dışında kalan açıklama yazıları viewBox ile kırpılır."""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{CARD_W * SCALE}" '
        f'height="{CARD_H * SCALE}" viewBox="0 0 {CARD_W} {CARD_H}">{inner}</svg>'
    )


# Chromium'un başsız ekran görüntüsünde ~500px'lik bir minimum pencere
# genişliği var; tam kart boyutunda (480px) pencere istenirse içerik
# ölçeklenip alttan kesiliyor. Bu yüzden kart, daha büyük bir pencerede
# sol üst köşeye render edilir ve PNG sonradan tam boyuta kırpılır.
WIN_W, WIN_H = 640, 800


def render(svg_text, out_png, tmp_dir):
    svg_path = os.path.join(tmp_dir, os.path.basename(out_png) + ".svg")
    with open(svg_path, "w") as f:
        f.write(svg_text)
    subprocess.run(
        [
            CHROMIUM,
            "--headless",
            "--no-sandbox",
            "--disable-gpu",
            "--force-device-scale-factor=1",
            "--default-background-color=00000000",
            f"--window-size={WIN_W},{WIN_H}",
            f"--screenshot={out_png}",
            "file://" + svg_path,
        ],
        check=True,
        capture_output=True,
    )
    _crop_png(out_png, CARD_W * SCALE, CARD_H * SCALE)


def _read_png(path):
    d = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(d):
        ln, typ = struct.unpack(">I4s", d[pos:pos + 8])
        chunk = d[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", chunk[:10])
            assert depth == 8 and ctype in (2, 6), (depth, ctype)
            bpp = 3 if ctype == 2 else 4
        elif typ == b"IDAT":
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * bpp
    out, prev, p = bytearray(), bytearray(stride), 0
    for _ in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out += line
        prev = line
    return w, h, bpp, out


def _write_png(path, w, h, bpp, pix):
    ctype = 2 if bpp == 3 else 6
    raw = b"".join(
        b"\x00" + bytes(pix[y * w * bpp:(y + 1) * w * bpp]) for y in range(h))

    def chunk(t, c):
        return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c))

    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b""))


def _crop_png(path, cw, ch):
    w, h, bpp, pix = _read_png(path)
    assert w >= cw and h >= ch, (w, h)
    crop = bytearray()
    for y in range(ch):
        crop += pix[(y * w) * bpp:(y * w + cw) * bpp]
    _write_png(path, cw, ch, bpp, crop)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    jobs = {}  # dosya adı -> svg içeriği

    # --- Sayı kartları: satırlar kırmızı/mavi/yeşil/sarı, sütunlar 0-9 ---
    fronts = open(os.path.join(ROOT, "uno_kartlari_on_yuz.svg")).read()
    front_groups = split_top_groups(fronts)
    row_colors = ["red", "blue", "green", "yellow"]  # clip id'leriyle doğrulanıyor
    for x, y, inner in front_groups:
        col = (x - 24) // 126
        row = (y - 24) // 186
        color, value = row_colors[row], col
        # Hücre içindeki clip id'si (clip_<renk>_<sayı>_x_y) ile çapraz kontrol.
        m = re.search(r'id="clip_([a-z]+)_(\d+)_', inner)
        assert m and m.group(1) == color and int(m.group(2)) == value, (
            f"beklenmeyen hücre: ({x},{y}) -> {m and m.groups()}")
        jobs[f"{color}_{value}.png"] = wrap_cell(inner)
    assert len([j for j in jobs if "_" in j]) == 40, "40 sayı kartı bekleniyordu"

    # --- Özel kartlar: konum -> dosya adı (hücre başlıklarıyla doğrulandı) ---
    specials = open(os.path.join(ROOT, "uno_ozel_kartlar_v6.svg")).read()
    special_names = {
        (30, 30): "red_draw2",
        (190, 30): "blue_draw2",
        (350, 30): "green_draw2",
        (510, 30): "yellow_draw2",
        (670, 30): "wild_draw4",
        (830, 30): "wild",
        (990, 30): "red_skip",
        (30, 264): "blue_skip",
        (190, 264): "green_skip",
        (350, 264): "yellow_skip",
        (510, 264): "red_reverse",
        (670, 264): "blue_reverse",
        (830, 264): "green_reverse",
        (990, 264): "yellow_reverse",
    }
    special_groups = split_top_groups(specials)
    assert len(special_groups) == len(special_names)
    for x, y, inner in special_groups:
        jobs[special_names[(x, y)] + ".png"] = wrap_cell(inner)

    # --- Arka yüz ---
    back = open(os.path.join(ROOT, "uno_kart_arka_yuz.svg")).read()
    (_, _, back_inner), = split_top_groups(back)
    jobs["back.png"] = wrap_cell(back_inner)

    with tempfile.TemporaryDirectory() as tmp:
        for i, (name, svg) in enumerate(sorted(jobs.items()), 1):
            out = os.path.join(OUT_DIR, name)
            render(svg, out, tmp)
            print(f"[{i}/{len(jobs)}] {name}")
    print(f"Bitti: {len(jobs)} kart -> {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())

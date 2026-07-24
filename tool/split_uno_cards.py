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
import subprocess
import sys
import tempfile

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
            f"--window-size={CARD_W * SCALE},{CARD_H * SCALE}",
            f"--screenshot={out_png}",
            "file://" + svg_path,
        ],
        check=True,
        capture_output=True,
    )


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

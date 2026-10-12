"""
Converts source/generated art into WoW-ready textures (32-bit uncompressed TGA, power-of-two sizes)
in Simulacrum/Media/. Also renders the procedural gold backdrop edge.

    python tools/build_textures.py
"""
import math, os, random
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC, GEN, OUT = (os.path.join(ROOT, p) for p in ("art/src", "art/gen", "Simulacrum/Media"))


def save(im, name):
    w, h = im.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, f"{name}: {im.size} is not power-of-two"
    im.convert("RGBA").save(os.path.join(OUT, name + ".tga"), compression=None)
    print(f"{name}.tga {im.size}")


def fit_pot(im, w, h):
    """Paste `im` at the top-left of a transparent w x h canvas (the addon uses tex coords for the rest)."""
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(im, (0, 0))
    return canvas


def alpha_bbox(im, threshold=24):
    a = im.split()[3].point(lambda v: 255 if v > threshold else 0)
    return a.getbbox()


def banner():
    im = Image.open(os.path.join(SRC, "banner.webp")).convert("RGBA")
    b = im.resize((1024, 342), Image.LANCZOS)
    save(fit_pot(b, 1024, 512), "banner")  # tex coords: 0..1, 0..342/512
    # Crest: the "S" flag from the banner
    crest = im.crop((125, 160, 425, 460)).resize((128, 128), Image.LANCZOS)
    save(crest, "icon")


def parchment():
    im = Image.open(os.path.join(GEN, "parchment.png")).convert("RGB")
    # warm it up and add a soft vignette so it reads as old paper inside a dark frame
    im = ImageEnhance.Color(im).enhance(1.2)
    tint = Image.new("RGB", im.size, (246, 226, 190))
    im = ImageChops.multiply(im, tint)
    im = ImageEnhance.Brightness(im).enhance(1.08)
    w, h = im.size
    vig = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(vig)
    for i in range(60):
        d.rectangle((i * 3, i * 3, w - 1 - i * 3, h - 1 - i * 3), outline=int(255 * (i / 60) ** 0.6))
    vig = vig.filter(ImageFilter.GaussianBlur(40))
    dark = ImageEnhance.Brightness(im).enhance(0.55)
    im = Image.composite(im, dark, vig)
    save(im.resize((1024, 1024), Image.LANCZOS), "parchment")


def ornaments():
    c = Image.open(os.path.join(GEN, "corner.png")).convert("RGBA")
    c = c.crop(alpha_bbox(c))
    side = max(c.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(c, (0, 0))
    save(sq.resize((256, 256), Image.LANCZOS), "corner")

    dv = Image.open(os.path.join(GEN, "divider.png")).convert("RGBA")
    dv = dv.crop(alpha_bbox(dv))
    dv = dv.resize((512, max(8, round(dv.height * 512 / dv.width))), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 64), (0, 0, 0, 0))
    canvas.paste(dv, (0, (64 - dv.height) // 2))
    save(canvas, "divider")


def dungeons():
    for key in ("dm", "sfk", "hot", "rol", "wc", "sm"):
        im = Image.open(os.path.join(GEN, key + ".png")).convert("RGBA")
        save(im.resize((512, 256), Image.LANCZOS), "dungeon_" + key)


def gold(t, rnd):
    """t: 0 at the bar's centre line, 1 at its outer rim."""
    stops = [(0.0, (255, 236, 160)), (0.25, (232, 186, 82)), (0.55, (176, 124, 38)),
             (0.8, (120, 78, 22)), (0.92, (60, 38, 10)), (1.0, (20, 12, 4))]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            n = rnd.uniform(-8, 8)
            return tuple(max(0, min(255, int(a + (b - a) * k + n))) for a, b in zip(c0, c1))
    return stops[-1][1]


def edge():
    """Backdrop edge file: 8 cells (L, R, T, B, TL, TR, BL, BR) of S x S. Symmetric bar => rotation-proof."""
    S, half = 32, 9.5
    rnd = random.Random(7)
    im = Image.new("RGBA", (S * 8, S), (0, 0, 0, 0))
    px = im.load()
    c = (S - 1) / 2

    def put(cell, x, y, d):
        if d <= half:
            r, g, b = gold(d / half, rnd)
            a = 255 if d < half - 0.8 else int(255 * (half - d) / 0.8)
            px[cell * S + x, y] = (r, g, b, a)

    for y in range(S):
        for x in range(S):
            for cell in range(4):
                put(cell, x, y, abs(x - c))
            # corners: L-shaped centre line plus a round boss where the bars meet
            for cell, (sx, sy) in zip(range(4, 8), ((1, 1), (-1, 1), (1, -1), (-1, -1))):
                lx, ly = (x - c) * sx, (y - c) * sy
                if lx >= 0 and ly >= 0:
                    d = min(abs(lx) if ly >= 0 else 99, abs(ly) if lx >= 0 else 99)
                else:
                    d = math.hypot(min(lx, 0), min(ly, 0))
                d = min(d, max(0.0, math.hypot(lx, ly) - 3))
                put(cell, x, y, d)
    save(im, "edge_gold")


def white():
    save(Image.new("RGBA", (8, 8), (255, 255, 255, 255)), "white")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    banner(); parchment(); ornaments(); dungeons(); edge(); white()

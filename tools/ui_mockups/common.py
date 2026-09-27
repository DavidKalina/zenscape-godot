"""Shared helpers for the UI direction mockups (docs/ui/DIRECTIONS.md).

Glyphs are written as standalone SVG files that Godot can import: plain paths,
circles and ellipses, hex colours, fill-opacity / stroke-opacity for alpha
(never rgba(), which Godot imports as black), no filters, no gradients in the
glyphs themselves. Mockup chrome (paper, glow, wood) lives in the HTML/CSS and
maps to StyleBoxTexture / NinePatch art in Godot.
"""
import math
import os
import random
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLYPH_ROOT = os.path.join(ROOT, "docs", "ui", "glyphs")
MOCK_ROOT = os.path.join(ROOT, "docs", "ui", "mockups")
BUILD = os.environ.get("ZS_UI_BUILD", "/tmp/zs-ui-mockups")
FONT_CACHE = os.path.join(BUILD, "fonts")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
VIDEO = os.environ.get(
    "ZS_UI_VIDEO",
    os.path.expanduser("~/Documents/Projects/zenscape-godot/captures/phase3-slices-2-5.mp4"),
)

# Free fonts (SIL Open Font License), fetched for rendering only, never committed.
FONTS = {
    "Fraunces": "https://github.com/google/fonts/raw/main/ofl/fraunces/Fraunces%5BSOFT,WONK,opsz,wght%5D.ttf",
    "FrauncesItalic": "https://github.com/google/fonts/raw/main/ofl/fraunces/Fraunces-Italic%5BSOFT,WONK,opsz,wght%5D.ttf",
    "Cormorant": "https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf",
    "CormorantItalic": "https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond-Italic%5Bwght%5D.ttf",
    "Fredoka": "https://github.com/google/fonts/raw/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf",
}

# The five brushes and the rest of the shell, in palette order.
BRUSHES = [("land", "Land"), ("water", "Water"), ("meadow", "Meadow"), ("forest", "Forest"), ("path", "Path")]
FORMS = [("form-hill", "Hill"), ("form-alpine", "Alpine peak"), ("form-ridge", "Ridge"), ("form-mesa", "Mesa"), ("form-volcano", "Volcanic cone")]
SEASONS = [("season-spring", "Spring"), ("season-summer", "Summer"), ("season-autumn", "Autumn"), ("season-winter", "Winter")]

# Mood swatches from scripts/scene_look_presets.gd: sky, glow (light), ground.
# Ground is the preset's grass or foliage where it sets one, else its family's
# grass (Mountain, Winter, Moonlit are guesses close to the running game).
MOODS = [
    ("alpine_morning", "Alpine morning", "709ebd", "c5d9dc", "7f9c6c", "438f97"),
    ("golden_meadow", "Golden meadow", "7c9daf", "f2c294", "92a85c", "6c9c97"),
    ("copper_autumn", "Copper autumn", "8795ae", "e4b995", "9b804b", "78959a"),
    ("rosewater_dusk", "Rosewater dusk", "8676a1", "eac0b5", "80917b", "9a91b1"),
    ("enchanted_forest", "Enchanted forest", "6d9aa5", "bbd3bc", "6c9d7b", "529595"),
    ("halloween_hollow", "Halloween hollow", "49385d", "a7795c", "cc852f", "628775"),
    ("first_snow", "First snow", "879cb9", "d8dce7", "e6ebef", "7d9bab"),
    ("nordic_night", "Nordic night", "536884", "8d9eae", "627d7c", "6e97ac"),
    ("after_the_rain", "After the rain", "739fb5", "e0d7b7", "70a268", "619f9f"),
]

HINT_LAND = [("drag", "raise land"), ("shift", "press a hollow"), ("[ ]", "size"), ("tab", "just look")]


def ensure_dirs(*paths):
    for p in paths:
        os.makedirs(p, exist_ok=True)


def fetch_fonts():
    ensure_dirs(FONT_CACHE)
    for name, url in FONTS.items():
        path = os.path.join(FONT_CACHE, name + ".ttf")
        if not os.path.exists(path):
            subprocess.run(["curl", "-sSL", "-m", "60", "-o", path, url], check=True)


def font_faces():
    css = []
    for name in FONTS:
        family = name.replace("Italic", "")
        style = "italic" if name.endswith("Italic") else "normal"
        css.append(
            f"@font-face{{font-family:'{family}';font-style:{style};font-weight:100 900;"
            f"src:url('file://{FONT_CACHE}/{name}.ttf');}}"
        )
    # Nunito ships with the game (assets/fonts, OFL).
    css.append(f"@font-face{{font-family:'Nunito';font-weight:200 1000;src:url('file://{ROOT}/assets/fonts/Nunito.ttf');}}")
    return "\n".join(css)


def extract_frames():
    """Two real frames from the Phase 3 film, cropped above the old palette."""
    ensure_dirs(BUILD)
    frames = {"forest": 62, "island": 44}
    out = {}
    for key, t in frames.items():
        path = os.path.join(BUILD, f"bg-{key}.png")
        if not os.path.exists(path):
            subprocess.run(
                ["ffmpeg", "-v", "error", "-y", "-ss", str(t), "-i", VIDEO, "-frames:v", "1",
                 "-vf", "crop=1192:745:204:0,scale=1440:900:flags=lanczos", path],
                check=True,
            )
        out[key] = path
    return out


def svg_doc(inner, size=48, extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}"{extra}>\n{inner}\n</svg>\n')


def write_glyphs(direction, glyphs):
    folder = os.path.join(GLYPH_ROOT, direction)
    ensure_dirs(folder)
    for name, svg in glyphs.items():
        with open(os.path.join(folder, name + ".svg"), "w") as f:
            f.write(svg)
    return folder


def glyph_url(direction, name):
    return f"file://{GLYPH_ROOT}/{direction}/{name}.svg"


def page(body, css, bg=None, width=1440, height=900):
    background = f"background:#1d2626 url('file://{bg}') center/cover no-repeat;" if bg else ""
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
{font_faces()}
*{{box-sizing:border-box}}
html,body{{margin:0;padding:0}}
body{{width:{width}px;height:{height}px;position:relative;overflow:hidden;{background}}}
.abs{{position:absolute}}
img{{display:block}}
{css}
</style></head><body>
{body}
</body></html>"""


def render(html, out_png, width=1440, height=900):
    ensure_dirs(BUILD, os.path.dirname(out_png))
    src = os.path.join(BUILD, os.path.basename(out_png).replace(".png", ".html"))
    with open(src, "w") as f:
        f.write(html)
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         "--allow-file-access-from-files", "--virtual-time-budget=3000",
         f"--screenshot={out_png}", f"--window-size={width},{height}", "file://" + src],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return out_png


# ---------- small geometry helpers ----------

def f(x):
    return f"{x:.2f}".rstrip("0").rstrip(".")


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def blob_path(cx, cy, r, seed, n=9, wobble=0.16):
    """A closed, smooth, slightly irregular blob (a watercolour wash or a pebble)."""
    rng = random.Random(seed)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.12, 0.12)
        rr = r * (1 + rng.uniform(-wobble, wobble))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = []
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        if i == 0:
            d.append(f"M{f(p1[0])} {f(p1[1])}")
        d.append(f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}")
    return " ".join(d) + "Z"


def deckle_polygon(w, h, seed, amp=2.2, step=9):
    """A CSS clip-path polygon with torn paper edges."""
    rng = random.Random(seed)
    pts = []
    x = 0
    while x < w:
        pts.append((x, rng.uniform(0, amp)))
        x += rng.uniform(step * 0.6, step * 1.4)
    y = 0
    while y < h:
        pts.append((w - rng.uniform(0, amp), y))
        y += rng.uniform(step * 0.6, step * 1.4)
    x = w
    while x > 0:
        pts.append((x, h - rng.uniform(0, amp)))
        x -= rng.uniform(step * 0.6, step * 1.4)
    y = h
    while y > 0:
        pts.append((rng.uniform(0, amp), y))
        y -= rng.uniform(step * 0.6, step * 1.4)
    return "polygon(" + ",".join(f"{f(px)}px {f(py)}px" for px, py in pts) + ")"


def bezier_points(p0, p1, p2, p3, n):
    out = []
    for i in range(n):
        t = i / (n - 1)
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t**3 * p3[1]
        out.append((x, y))
    return out

#!/usr/bin/env python3
"""Paint Bigfoot's reaction bubbles and icons as layered SVGs.

Every shape is a soft gradient under a warm ink outline, with a highlight
stroke and a darker shade stroke, so the icons read as painted rather than
flat. Files are written at twice their viewBox so Godot imports them crisply;
res://scripts/reaction_bubble.gd works in viewBox units and draws them at half
scale. Re-run after editing: python3 tools/paint_reaction_icons.py
"""
import math
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "reactions"
INK = "#3f3228"
SHADOW = 'fill="#34261a" fill-opacity="0.22"'  # rgba() imports as opaque black


def svg(name, w, h, body, defs=""):
    text = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*2}" height="{h*2}" viewBox="0 0 {w} {h}">\n'
        f"<defs>{defs}</defs>\n{body}\n</svg>\n"
    )
    (OUT / f"{name}.svg").write_text(text)


def lin(id_, stops, x1=0, y1=0, x2=0, y2=1):
    s = "".join(f'<stop offset="{st[0]}" stop-color="{st[1]}" stop-opacity="{st[2] if len(st) > 2 else 1}"/>' for st in stops)
    return f'<linearGradient id="{id_}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rad(id_, stops, cx=0.36, cy=0.3, r=0.8):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


def blobs(circles, fill, ink_width=10, shadow=None):
    """Union of circles: fat ink strokes first, then fills, so only the outer edge is inked."""
    out = []
    if shadow:
        dx, dy = shadow
        out += [f'<circle cx="{x+dx}" cy="{y+dy}" r="{r+ink_width/2}" {SHADOW}/>' for x, y, r in circles]
    out += [f'<circle cx="{x}" cy="{y}" r="{r}" fill="{INK}" stroke="{INK}" stroke-width="{ink_width}"/>' for x, y, r in circles]
    out += [f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>' for x, y, r in circles]
    return "\n".join(out)


def highlight(d, width=5, opacity=0.6, color="#fffaf0"):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" opacity="{opacity}"/>'


PAPER = lin("paper", [(0, "#fcf6e8"), (0.65, "#f4e7cc"), (1, "#e9d6b2")])


def bubbles():
    speech = (
        "M 70 22 C 110 13 172 14 204 26 C 231 37 235 70 231 100 C 227 134 206 153 170 156 "
        "C 140 160 104 161 88 156 L 44 192 L 60 150 C 33 140 19 118 20 92 C 20 56 36 30 70 22 Z"
    )
    svg("bubble_speech", 240, 200, "\n".join([
        f'<path d="{speech}" transform="translate(5 6)" {SHADOW}/>',
        f'<path d="{speech}" fill="url(#paper)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>',
        highlight("M 44 64 C 50 44 72 32 102 29", 6, 0.75),
        highlight("M 122 27 C 132 26 140 26 148 27", 5, 0.6),
        highlight("M 206 120 C 200 136 186 146 168 149", 4, 0.18, INK),
    ]), PAPER)

    cloud = [(70, 82, 44), (120, 56, 46), (172, 64, 42), (198, 104, 36), (152, 128, 40), (98, 126, 40), (52, 114, 32)]
    trail = [(52, 164, 13), (35, 186, 7)]
    svg("bubble_thought", 240, 200, "\n".join([
        blobs(cloud + trail, "url(#paper)", 10, (5, 6)),
        highlight("M 38 76 C 42 56 58 44 78 42", 6, 0.75),
        highlight("M 104 24 C 118 18 134 18 146 24", 5, 0.6),
        highlight("M 186 132 C 176 150 158 162 136 164", 4, 0.18, INK),
    ]), PAPER)

    # A starburst with uneven spikes, as if cut quickly from paper.
    points = []
    cx, cy = 130, 86
    spikes = 13
    for i in range(spikes * 2):
        a = i / (spikes * 2) * math.tau - math.pi / 2
        wobble = 1.0 + 0.09 * math.sin(i * 2.7)
        r = (100 if i % 2 == 0 else 72) * wobble
        points.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.74))
    # Replace the lowest-left spike with the wedge that points at his head.
    lowest = min(range(0, len(points), 2), key=lambda k: -points[k][1] + points[k][0] * 0.9)
    points[lowest] = (40, 194)
    d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in points) + " Z"
    svg("bubble_shout", 240, 200, "\n".join([
        f'<path d="{d}" transform="translate(5 6)" {SHADOW}/>',
        f'<path d="{d}" fill="url(#shout)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>',
        highlight("M 58 70 C 66 52 84 42 106 38", 6, 0.7),
    ]), lin("shout", [(0, "#fff4d8"), (0.6, "#fbe3b0"), (1, "#f2c98a")]))


def icons():
    svg("fish", 128, 128, "\n".join([
        f'<path d="M 46 45 C 54 29 70 28 78 42" fill="#3f7c86" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>',
        f'<path d="M 50 80 C 54 94 64 96 70 84" fill="#6fa3a4" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>',
        f'<path d="M 16 64 C 28 37 66 30 88 50 L 111 31 C 105 48 105 79 111 97 L 88 78 C 66 99 28 91 16 64 Z" fill="url(#fish)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>',
        f'<path d="M 96 50 L 104 42 M 96 78 L 104 86" stroke="{INK}" stroke-width="2" opacity="0.35" stroke-linecap="round"/>',
        f'<path d="M 40 51 C 47 59 47 70 40 78" fill="none" stroke="{INK}" stroke-width="3" opacity="0.7" stroke-linecap="round"/>',
        "".join(f'<path d="M {x} {y} q 5 5 0 10" fill="none" stroke="#2f5f66" stroke-width="2" opacity="0.35"/>' for x, y in [(56, 52), (66, 50), (76, 54), (60, 64), (70, 64), (80, 64)]),
        highlight("M 32 49 C 46 40 64 39 78 46", 4, 0.6),
        f'<circle cx="29" cy="58" r="5.5" fill="#fffaf0" stroke="{INK}" stroke-width="2"/><circle cx="30" cy="58" r="2.8" fill="{INK}"/>',
        '<circle cx="28.5" cy="56.5" r="1" fill="#fff"/>',
    ]), lin("fish", [(0, "#3f7f8c"), (0.45, "#86bab7"), (1, "#ece4c8")]))

    svg("stone", 128, 128, "\n".join([
        '<ellipse cx="64" cy="106" rx="38" ry="6" fill="#34261a" fill-opacity="0.16"/>',
        f'<path d="M 22 78 C 17 56 38 37 64 38 C 93 38 111 55 108 77 C 106 97 86 104 62 104 C 38 104 25 96 22 78 Z" fill="url(#stone)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>',
        highlight("M 36 60 C 44 48 58 44 72 45", 5, 0.6),
        highlight("M 96 82 C 90 94 76 99 62 99", 4, 0.2, INK),
        "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{INK}" opacity="0.22"/>' for x, y, r in [(52, 74, 2), (78, 64, 1.6), (86, 84, 2.2), (60, 90, 1.4), (42, 84, 1.2)]),
    ]), rad("stone", [(0, "#d2ccbf"), (0.55, "#958f85"), (1, "#5f5b55")]))

    wood = lin("wood", [(0, "#a0703f"), (1, "#5e3c22")], 0, 0, 1, 1)
    leaf_fill = lin("leaf", [(0, "#a6cc6e"), (1, "#4f8a45")], 0, 0, 1, 1)
    svg("stick", 128, 128, "\n".join([
        f'<path d="M 22 102 C 46 82 72 58 106 28 M 66 66 C 74 50 76 40 73 24" fill="none" stroke="{INK}" stroke-width="17" stroke-linecap="round"/>',
        '<path d="M 22 102 C 46 82 72 58 106 28 M 66 66 C 74 50 76 40 73 24" fill="none" stroke="url(#wood)" stroke-width="10" stroke-linecap="round"/>',
        highlight("M 30 92 C 48 78 64 62 84 46", 3, 0.45, "#e2b98a"),
        f'<path d="M 44 86 l 6 -2 M 80 52 l 5 -1 M 94 40 l 4 0" stroke="{INK}" stroke-width="2" opacity="0.45" stroke-linecap="round"/>',
        f'<path d="M 73 26 C 80 10 98 6 112 10 C 106 24 92 32 73 26 Z" fill="url(#leaf)" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>',
        f'<path d="M 76 25 C 88 18 98 14 108 12" fill="none" stroke="{INK}" stroke-width="1.5" opacity="0.5"/>',
    ]), wood + leaf_fill)

    svg("leaf", 32, 32, "\n".join([
        f'<path d="M 4 28 C 4 12 16 4 28 4 C 28 18 20 28 4 28 Z" fill="url(#leaf)" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>',
        f'<path d="M 6 26 C 12 18 18 12 26 6" fill="none" stroke="{INK}" stroke-width="1.2" opacity="0.5"/>',
    ]), leaf_fill)

    crown = [(40, 62, 25), (88, 60, 25), (64, 36, 29), (64, 66, 26), (50, 42, 20), (80, 42, 20)]
    svg("tree", 128, 128, "\n".join([
        '<ellipse cx="64" cy="120" rx="30" ry="5" fill="#34261a" fill-opacity="0.16"/>',
        f'<path d="M 55 121 C 58 102 58 88 55 72 L 73 72 C 70 88 70 102 75 121 Z" fill="url(#bark)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>',
        f'<path d="M 64 110 C 64 100 64 92 63 84" stroke="{INK}" stroke-width="2" opacity="0.35" fill="none"/>',
        blobs(crown, "url(#crown)", 8),
        "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#c4de8a" opacity="0.45"/>' for x, y, r in [(54, 28, 10), (78, 34, 7), (34, 54, 7)]),
        "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#2d5a33" opacity="0.35"/>' for x, y, r in [(52, 78, 12), (82, 76, 11), (98, 62, 8)]),
    ]), lin("bark", [(0, "#8a5a34"), (1, "#5b3a22")], 0, 0, 1, 0) + rad("crown", [(0, "#a9cf72"), (0.55, "#629e50"), (1, "#3a6c3d")], 0.4, 0.25, 0.85))

    bands = ["#d8674f", "#e89a4f", "#eccb62", "#8dbb62", "#5f9cc4", "#8a76b8"]
    arcs = []
    for i, color in enumerate(bands):
        r = 50 - i * 7
        arcs.append(f'<path d="M {64-r} 98 A {r} {r} 0 0 1 {64+r} 98" fill="none" stroke="{color}" stroke-width="7.5"/>')
    svg("rainbow", 128, 128, "\n".join([
        f'<path d="M 17.5 98 A 46.5 46.5 0 0 1 110.5 98" fill="none" stroke="{INK}" stroke-width="{7*6+8}"/>',
        '<path d="M 17.5 98 A 46.5 46.5 0 0 1 110.5 98" fill="none" stroke="#fbf3e2" stroke-width="44"/>',
        *arcs,
        highlight("M 26 70 C 36 50 52 40 70 38", 3, 0.45),
        blobs([(12, 100, 11), (24, 96, 13), (36, 102, 9), (22, 106, 9)], "url(#puff)", 6),
        blobs([(104, 100, 11), (116, 98, 12), (94, 104, 9), (110, 107, 9)], "url(#puff)", 6),
    ]), rad("puff", [(0, "#ffffff"), (1, "#ddd6ca")], 0.4, 0.3, 0.9))

    svg("fire", 128, 128, "\n".join([
        f'<g stroke="{INK}" stroke-width="3.5" stroke-linejoin="round">'
        '<rect x="26" y="100" width="76" height="14" rx="7" fill="#7a4d2c" transform="rotate(-10 64 107)"/>'
        '<rect x="26" y="100" width="76" height="14" rx="7" fill="#8c5a33" transform="rotate(12 64 107)"/></g>',
        f'<path d="M 64 16 C 78 40 98 52 94 80 C 92 98 78 108 64 108 C 48 108 34 98 34 80 C 34 62 50 56 52 40 C 58 50 60 56 64 60 C 68 46 66 32 64 16 Z" fill="url(#flame)" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>',
        '<path d="M 64 56 C 72 70 80 78 78 90 C 76 100 70 104 64 104 C 56 104 50 98 50 90 C 50 80 58 74 64 56 Z" fill="url(#core)"/>',
        highlight("M 44 76 C 44 66 50 60 54 52", 3, 0.5, "#fff2c8"),
    ]), lin("flame", [(0, "#f7c65a"), (0.55, "#ef8a3c"), (1, "#cf4a35")]) + lin("core", [(0, "#fff0b8"), (1, "#f7c65a")]))

    q = "M 42 44 C 42 26 56 17 68 17 C 85 17 95 30 93 44 C 91 58 75 62 69 72 L 68 82"
    svg("question", 128, 128, "\n".join([
        f'<path d="{q}" fill="none" stroke="{INK}" stroke-width="23" stroke-linecap="round" stroke-linejoin="round"/>',
        f'<path d="{q}" fill="none" stroke="url(#amber)" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>',
        highlight("M 48 38 C 50 28 60 23 68 23", 3.5, 0.6),
        f'<circle cx="68" cy="104" r="10" fill="url(#amber)" stroke="{INK}" stroke-width="4.5"/>',
        highlight("M 63 101 C 64 98 66 97 68 97", 2.5, 0.6),
    ]), lin("amber", [(0, "#f1bd5e"), (1, "#c07a2c")]))

    svg("exclaim", 128, 128, "\n".join([
        f'<path d="M 52 22 C 52 13 76 13 76 22 L 69 80 C 68 85 60 85 59 80 Z" fill="url(#ember)" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>',
        highlight("M 58 24 L 62 66", 3.5, 0.55),
        f'<circle cx="64" cy="102" r="10" fill="url(#ember)" stroke="{INK}" stroke-width="4.5"/>',
        highlight("M 59 99 C 60 96 62 95 64 95", 2.5, 0.6),
    ]), lin("ember", [(0, "#ee8a52"), (1, "#c0452e")]))

    svg("dot", 32, 32, "\n".join([
        f'<circle cx="16" cy="16" r="10" fill="url(#dot)" stroke="{INK}" stroke-width="3"/>',
        highlight("M 11 13 C 12 10 14 9 16 9", 2, 0.6),
    ]), rad("dot", [(0, "#9b8672"), (1, "#5e4a3a")]))

    svg("puff", 64, 64, "\n".join([
        blobs([(22, 36, 14), (38, 28, 16), (46, 40, 12), (32, 44, 12)], "url(#puff)", 5),
    ]), rad("puff", [(0, "#ffffff"), (1, "#d6cfc4")], 0.4, 0.3, 0.9))

    svg("cloud", 128, 128, "\n".join([
        blobs([(36, 64, 22), (62, 48, 28), (90, 58, 24), (74, 74, 20), (48, 78, 18)], "url(#storm)", 8),
        highlight("M 42 46 C 48 34 60 28 72 28", 4, 0.5),
    ]), rad("storm", [(0, "#dfe6ec"), (0.6, "#a9b6c2"), (1, "#74838f")], 0.4, 0.25, 0.9))

    svg("drop", 24, 32, "\n".join([
        f'<path d="M 12 3 C 18 12 21 18 21 22 C 21 28 17 30 12 30 C 7 30 3 28 3 22 C 3 18 6 12 12 3 Z" fill="url(#drop)" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>',
        highlight("M 8 22 C 8 19 9 17 10 15", 1.8, 0.7),
    ]), lin("drop", [(0, "#a7d3ee"), (1, "#4f8fc0")]))

    arms = []
    for i in range(6):
        a = i * math.pi / 3
        ex, ey = 64 + math.cos(a) * 40, 64 + math.sin(a) * 40
        mx, my = 64 + math.cos(a) * 24, 64 + math.sin(a) * 24
        arms.append(f"M 64 64 L {ex:.1f} {ey:.1f}")
        for side in (-1, 1):
            b = a + side * 0.7
            arms.append(f"M {mx:.1f} {my:.1f} L {mx+math.cos(b)*12:.1f} {my+math.sin(b)*12:.1f}")
    d = " ".join(arms)
    svg("snowflake", 128, 128, "\n".join([
        f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>',
        f'<path d="{d}" fill="none" stroke="url(#ice)" stroke-width="5.5" stroke-linecap="round"/>',
        f'<circle cx="64" cy="64" r="8" fill="#f2f8fc" stroke="{INK}" stroke-width="3"/>',
    ]), rad("ice", [(0, "#ffffff"), (1, "#9fc6e0")], 0.5, 0.5, 0.7))

    star = []
    for i in range(10):
        a = i * math.pi / 5 - math.pi / 2
        r = 28 if i % 2 == 0 else 12
        star.append(f"{84+math.cos(a)*r:.1f} {42+math.sin(a)*r:.1f}")
    svg("star", 128, 128, "\n".join([
        '<path d="M 72 28 L 8 102 L 30 118 L 96 54 Z" fill="url(#trail)"/>',
        f'<path d="M {" L ".join(star)} Z" fill="url(#gold)" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>',
        highlight("M 80 32 L 86 22", 2.5, 0.7),
    ]), lin("gold", [(0, "#fbe08a"), (1, "#e9a53a")]) + lin("trail", [(0, "#f8d678", 0.95), (1, "#f8d678", 0)], 1, 0, 0, 1))

    svg("bolt", 128, 128, "\n".join([
        f'<path d="M 72 10 L 34 70 L 60 70 L 48 118 L 98 50 L 69 50 L 86 10 Z" fill="url(#bolt)" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>',
        highlight("M 70 18 L 44 62", 3, 0.6),
    ]), lin("bolt", [(0, "#fdeb95"), (1, "#f0b03a")]))

    svg("heart", 128, 128, "\n".join([
        f'<path d="M 64 108 C 30 84 15 64 19 44 C 23 25 48 19 64 40 C 80 19 105 25 109 44 C 113 64 98 84 64 108 Z" fill="url(#heart)" stroke="{INK}" stroke-width="4.5" stroke-linejoin="round"/>',
        highlight("M 30 46 C 32 36 40 31 48 32", 4.5, 0.65),
        highlight("M 98 60 C 92 76 80 88 68 97", 4, 0.2, INK),
    ]), rad("heart", [(0, "#f3a2a0"), (0.5, "#d85d66"), (1, "#a93a48")]))

    leaves = [(34, 62, -30, "#8fbf5e"), (52, 54, -8, "#d9a14a"), (72, 52, 10, "#6fa651"), (90, 60, 32, "#c9773f"), (62, 60, 0, "#a9c96a")]
    leaf_paths = "".join(
        f'<path d="M 0 0 C -6 -12 -2 -24 0 -30 C 2 -24 6 -12 0 0 Z" transform="translate({x} {y}) rotate({r}) scale(1.4)" fill="{c}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
        for x, y, r, c in leaves
    )
    svg("nest", 128, 128, "\n".join([
        '<ellipse cx="64" cy="104" rx="46" ry="7" fill="#34261a" fill-opacity="0.16"/>',
        leaf_paths,
        # An arc, not a curve pair: Godot's rasterizer drops that gradient-filled crescent.
        f'<path d="M 16 68 A 48 26 0 0 0 112 68 Z" fill="url(#weave)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>',
        f'<ellipse cx="64" cy="68" rx="48" ry="6" fill="#4a3020" stroke="{INK}" stroke-width="3"/>',
        f'<path d="M 24 76 C 44 84 84 84 104 76 M 32 86 C 50 92 78 92 96 86" fill="none" stroke="{INK}" stroke-width="2" opacity="0.35"/>',
        highlight("M 26 72 C 40 78 56 80 72 80", 3, 0.45, "#f0cf9a"),
    ]), lin("weave", [(0, "#b98452"), (1, "#6f4a2a")]))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    bubbles()
    icons()
    print("\n".join(sorted(p.name for p in OUT.glob("*.svg"))))

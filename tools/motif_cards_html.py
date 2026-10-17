#!/usr/bin/env python3
"""Draw motif cards and motif plans as an HTML page of maps.

    python tools/motif_cards_html.py docs/design/motifs/brainstorm/round1-x [--open]
    python tools/motif_cards_html.py docs/design/motifs/plans/<slug>/plan.md [--open]

A folder: every motif-*.md card in it, drawn to index.html there. A file
(a card or a plan): that one, drawn to <file>.html beside it.

Each panel: the name, lenses, pitch and fit, a top view and a side view
drawn from the `Layout:` block (the JSON in docs/design/motifs/
motif-brief.md; a plan's extra layers in .claude/skills/motif-plan/
plan-format.md), the moments numbered on both and listed, the play and set
pieces, and, for a plan, tables of its collectibles, enemies and landing.
The toolbar switches layers on and off. A card without a Layout block shows
its ASCII instead. The page is self-contained (inline SVG and a few lines
of script).
"""
import argparse
import html
import json
import pathlib
import re
import subprocess
import sys

LINK_STYLE = {
    "rope": 'stroke="#8a5a2b" stroke-width="2" stroke-dasharray="6 4"',
    "stair": 'stroke="#6b6b6b" stroke-width="4"',
    "stones": 'stroke="#4d7a8c" stroke-width="2.5" stroke-dasharray="1 5" stroke-linecap="round"',
    "span": 'stroke="#b39461" stroke-width="4"',
    "climb": 'stroke="#c0392b" stroke-width="1.5" stroke-dasharray="3 3"',
}
PILOT = "#1f6fd1"
THREAT = "#c0392b"
MOMENT = "#7b2cbf"
PICKUP = {"token": "#f1c40f", "flown": "#5dade2", "buried": "#a0522d", "part": "#e67e22", "moment": MOMENT}
LAYERS = ["links", "routes", "moments", "notes", "tips", "landing", "collectibles", "enemies"]
W, H, PAD = 560, 380, 28
e = html.escape


def field(text, name, para=False):
    # "Name: text" or a "## Name" heading, up to the next field, heading or fence
    stop = r"^\w[\w ]*:|^#|^```|\Z" + (r"|\n\s*\n" if para else "")
    m = re.search(rf"^(?:{name}:|#+ {name}\s*$)\s*(.+?)(?={stop})", text, re.M | re.S)
    return m.group(1).strip() if m else ""


def layout_of(text):
    m = re.search(r"^#*\s*Layout:?.*?```(?:json)?\s*\n(.*?)```", text, re.M | re.S)
    if not m:
        return None, ""
    try:
        return json.loads(m.group(1)), ""
    except json.JSONDecodeError as err:
        return None, f"Layout block is not valid JSON: {err}"


def shade(t):
    # low isles a deep green, high ones pale stone
    a, b = (70, 110, 70), (215, 205, 175)
    return "#%02x%02x%02x" % tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Frame:
    def __init__(self, xs, ys, flip):
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        self.s = min((W - 2 * PAD) / max(x1 - x0, 1e-3), (H - 2 * PAD) / max(y1 - y0, 1e-3))
        self.x0, self.y0 = x0, y0
        self.ox = (W - self.s * (x1 - x0)) / 2
        self.oy = (H - self.s * (y1 - y0)) / 2
        self.flip = flip

    def p(self, x, y):
        px, py = self.ox + (x - self.x0) * self.s, self.oy + (y - self.y0) * self.s
        return px, (H - py if self.flip else py)


def tri(x, y, fill, stroke):
    return f'<polygon points="{x:.1f},{y - 7:.1f} {x - 6:.1f},{y + 5:.1f} {x + 6:.1f},{y + 5:.1f}" fill="{fill}" stroke="{stroke}"/>'


def poly(f, pts, pick, colour, width=2.5, dash=""):
    if not pts or len(pts) < 2:
        return ""
    d = " ".join("%.1f,%.1f" % f.p(*pick(q)) for q in pts)
    dash = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<polyline points="{d}" fill="none" stroke="{colour}" stroke-width="{width}"{dash} '
            f'stroke-linejoin="round" marker-end="url(#arr{colour[1:]})"/>')


class View:
    """One SVG: the isles drawn by the subclass, the layers in groups."""

    def __init__(self, L, title, pick, xs, ys, flip):
        self.L, self.pick = L, pick
        self.f = Frame(xs, ys, flip)
        self.g = {k: [] for k in LAYERS}
        self.base = [f'<rect width="{W}" height="{H}" fill="#eaf1f6"/>',
                     f'<text x="8" y="16" class="vt">{e(title)}</text>']

    def at(self, q):
        return self.f.p(*self.pick(q))

    def layers(self):
        L, g = self.L, self.g
        g["routes"].append(poly(self.f, L.get("pilot"), self.pick, PILOT))
        g["routes"].append(poly(self.f, L.get("threat"), self.pick, THREAT))
        for t in L.get("tips", []):
            if len(t) == 3:
                g["tips"].append(tri(*self.at(t), "#e67e22", "#7a3e00"))
        end = L.get("end")
        if end and len(end) == 3:
            x, y = self.at(end)
            g["routes"].append(f'<text x="{x:.1f}" y="{y + 6:.1f}" class="star">&#9733;</text>')
        for n in L.get("notes", []):
            if len(n.get("at", [])) == 3:
                x, y = self.at(n["at"])
                g["notes"].append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="2.5" fill="#444"/>'
                                  f'<text x="{x + 5:.1f}" y="{y - 4:.1f}" class="nt">{e(n.get("text", ""))}</text>')
        for c in L.get("collectibles", []):
            if len(c.get("at", [])) == 3:
                x, y = self.at(c["at"])
                col = PICKUP.get(c.get("kind"), "#f1c40f")
                ring = ' stroke="#1f6fd1" stroke-width="2"' if c.get("plane") else ' stroke="#333"'
                g["collectibles"].append(f'<rect x="{x - 5:.1f}" y="{y - 5:.1f}" width="10" height="10" '
                                         f'transform="rotate(45 {x:.1f} {y:.1f})" fill="{col}"{ring}/>')
        for n, en in enumerate(L.get("enemies", []), 1):
            g["enemies"].append(poly(self.f, en.get("route"), self.pick, THREAT, 2, "8 3"))
            wake = en.get("wake") or {}
            if len(wake.get("at", [])) == 3 and wake.get("r"):
                x, y = self.at(wake["at"])
                g["enemies"].append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{wake["r"] * self.f.s:.1f}" '
                                    f'fill="#c0392b" fill-opacity="0.07" stroke="#c0392b" stroke-dasharray="4 3"/>')
            if len(en.get("sleep", [])) == 3:
                x, y = self.at(en["sleep"])
                g["enemies"].append(f'<rect x="{x - 7:.1f}" y="{y - 7:.1f}" width="14" height="14" fill="#c0392b" stroke="#fff"/>'
                                    f'<text x="{x:.1f}" y="{y + 4:.1f}" class="mn">E{n}</text>')
        for k, m in enumerate(L.get("moments", []), 1):
            if len(m.get("at", [])) == 3:
                x, y = self.at(m["at"])
                g["moments"].append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="9" fill="{MOMENT}" stroke="#fff" stroke-width="1.5"/>'
                                    f'<text x="{x:.1f}" y="{y + 4:.1f}" class="mn">{k}</text>')

    def svg(self, labels):
        self.layers()
        out = [f'<svg viewBox="0 0 {W} {H}" width="{W}" height="{H}" class="view">'] + self.base
        out += [f'<g class="L-{k}">{"".join(v)}</g>' for k, v in self.g.items()]
        out += labels + ["</svg>"]
        return "\n".join(out)


def extent(L, key, rk):
    xs = []
    for i in L.get("isles", []):
        xs += [i[key] - i.get(rk, 10), i[key] + i.get(rk, 10)]
    return xs


def points(L, ax):
    out = [q[ax] for k in ("pilot", "threat") for q in L.get(k, [])]
    out += [c["at"][ax] for c in L.get("collectibles", []) if len(c.get("at", [])) == 3]
    out += [en["sleep"][ax] for en in L.get("enemies", []) if len(en.get("sleep", [])) == 3]
    return out


def top_view(L):
    isles = L.get("isles", [])
    xs, zs = extent(L, "x", "rx") + points(L, 0), extent(L, "z", "rz") + points(L, 2)
    if not xs:
        return ""
    v = View(L, "top (x east, z south)", lambda q: (q[0], q[2]), xs, zs, False)
    f = v.f
    tops = [i.get("top", 0) for i in isles] or [0]
    lo, hi = min(tops), max(tops)
    for i in isles:
        cx, cz = f.p(i["x"], i["z"])
        t = (i.get("top", 0) - lo) / max(hi - lo, 1e-3)
        v.base.append(f'<ellipse cx="{cx:.1f}" cy="{cz:.1f}" rx="{i.get("rx", 10) * f.s:.1f}" '
                      f'ry="{i.get("rz", 10) * f.s:.1f}" fill="{shade(t)}" stroke="#333"/>')
    by_id = {str(i["id"]): i for i in isles}
    for k in L.get("links", []):
        a, b = by_id.get(str(k.get("from"))), by_id.get(str(k.get("to")))
        if a and b:
            (ax, az), (bx, bz) = f.p(a["x"], a["z"]), f.p(b["x"], b["z"])
            v.g["links"].append(f'<line x1="{ax:.1f}" y1="{az:.1f}" x2="{bx:.1f}" y2="{bz:.1f}" '
                                f'{LINK_STYLE.get(k.get("kind"), LINK_STYLE["span"])}/>')
    land = L.get("landing")
    if land and len(land) == 4:
        (ax, az), (bx, bz) = f.p(land[0], land[1]), f.p(land[2], land[3])
        v.g["landing"].append(f'<line x1="{ax:.1f}" y1="{az:.1f}" x2="{bx:.1f}" y2="{bz:.1f}" stroke="#e0b100" '
                              f'stroke-width="7" stroke-opacity="0.8" stroke-dasharray="14 4"/>'
                              f'<text x="{bx + 6:.1f}" y="{bz:.1f}" class="lb">landing</text>')
    labels = []
    for i in isles:
        cx, cz = f.p(i["x"], i["z"])
        labels.append(f'<text x="{cx:.1f}" y="{cz:.1f}" class="il">{e(str(i["id"]))} {e(i.get("name", ""))} ({i.get("top", 0):g} m)</text>')
        if i.get("set_piece"):
            labels.append(f'<text x="{cx:.1f}" y="{cz + 13:.1f}" class="sp">@ {e(i["set_piece"])}</text>')
    return v.svg(labels)


def side_view(L):
    isles = L.get("isles", [])
    if not isles:
        return ""
    wide_x = (max(i["x"] for i in isles) - min(i["x"] for i in isles)) >= (max(i["z"] for i in isles) - min(i["z"] for i in isles))
    ax, key, rk = (0, "x", "rx") if wide_x else (2, "z", "rz")
    hs = extent(L, key, rk) + points(L, ax)
    ys = [i.get("top", 0) for i in isles] + [i.get("keel", i.get("top", 0) - 15) for i in isles] + points(L, 1)
    v = View(L, f"side (along {key}, y up)", lambda q: (q[ax], q[1]), hs, ys, True)
    f = v.f
    tops = [i.get("top", 0) for i in isles]
    lo, hi = min(tops), max(tops)
    labels = []
    for i in sorted(isles, key=lambda i: -i.get("top", 0)):
        top, keel = i.get("top", 0), i.get("keel", i.get("top", 0) - 15)
        (x0, y0), (x1, _), (xm, yk) = f.p(i[key] - i.get(rk, 10), top), f.p(i[key] + i.get(rk, 10), top), f.p(i[key], keel)
        t = (top - lo) / max(hi - lo, 1e-3)
        v.base.append(f'<polygon points="{x0:.1f},{y0:.1f} {x1:.1f},{y0:.1f} {xm:.1f},{yk:.1f}" fill="#5d5650" '
                      f'fill-opacity="0.85" stroke="#2b2622"/><line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" '
                      f'y2="{y0:.1f}" stroke="{shade(t)}" stroke-width="4"/>')
        labels.append(f'<text x="{(x0 + x1) / 2:.1f}" y="{y0 - 5:.1f}" class="il">{e(str(i["id"]))}</text>')
    return v.svg(labels)


def table(title, head, rows):
    if not rows:
        return ""
    th = "".join(f"<th>{e(h)}</th>" for h in head)
    body = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f'<h3>{title}</h3><table><tr>{th}</tr>{body}</table>'


def xyz(q):
    return e(", ".join("%g" % v for v in q)) if q else ""


def readouts(L):
    out = []
    ms = L.get("moments", [])
    out.append(table("Moments", ["#", "moment", "what happens"],
                     [[str(k), f'<b>{e(m.get("label", ""))}</b>', e(m.get("note", ""))] for k, m in enumerate(ms, 1)]))
    cs = L.get("collectibles", [])
    out.append(table("Collectibles", ["kind", "name", "where", "needs plane", "how"],
                     [[f'<span style="color:{PICKUP.get(c.get("kind"), "#333")}">&#9670;</span> {e(c.get("kind", ""))}',
                       e(c.get("name", "")), xyz(c.get("at")), "yes" if c.get("plane") else "",
                       e(c.get("how", ""))] for c in cs]))
    ens = L.get("enemies", [])
    out.append(table("Enemies", ["", "who", "sleeps at", "wakes when", "does"],
                     [[f"E{n}", e(en.get("kind", en.get("id", ""))), xyz(en.get("sleep")),
                       e((en.get("wake") or {}).get("by", "")), e(en.get("note", ""))] for n, en in enumerate(ens, 1)]))
    land = L.get("landing_note")
    if land:
        out.append(f'<h3>Landing</h3><p>{e(land)}</p>')
    return "".join(out)


def panel(path):
    text = path.read_text(encoding="utf-8")
    name = re.search(r"^# (.+)$", text, re.M)
    name = name.group(1) if name else path.stem
    L, err = layout_of(text)
    parts = [f'<section class="card" id="{path.stem}"><h2>{e(name)}</h2>',
             f'<p class="meta">{e(path.name)} · {e(field(text, "Lenses"))}</p>',
             f'<p class="pitch">{e(field(text, "Pitch", True))}</p>',
             f'<p class="fit"><b>Fit:</b> {e(field(text, "Fit", True))}</p>']
    if L:
        parts.append(f'<div class="views">{top_view(L)}{side_view(L)}</div>')
    else:
        if err:
            parts.append(f'<p class="err">{e(err)}</p>')
        parts += [f"<pre>{e(b)}</pre>" for b in re.findall(r"```[a-z]*\s*\n(.*?)```", text, re.S)[:2]]
    for f in ("Play", "Set pieces"):
        v = field(text, f)
        if v:
            parts.append(f'<p class="play"><b>{f}:</b> {e(v)}</p>'.replace("\n", "<br>"))
    if L:
        parts.append(readouts(L))
    for f in ("Threat", "Kit asks", "Kit"):
        v = field(text, f)
        if v:
            parts.append(f"<details><summary>{f}</summary><p>{e(v)}</p></details>".replace("\n", "<br>"))
    parts.append("</section>")
    return "\n".join(parts)


DEFS = "".join(
    f'<marker id="arr{c[1:]}" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">'
    f'<path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>' for c in (PILOT, THREAT, "#e0b100"))

STYLE = """
body{font:14px/1.45 -apple-system,Segoe UI,sans-serif;margin:24px;background:#f6f4ef;color:#222}
.bar{position:sticky;top:0;background:#f6f4ef;padding:6px 0;z-index:2}.bar label{margin-right:12px}
.card{background:#fff;border-radius:8px;padding:16px 20px;margin:0 0 24px;box-shadow:0 1px 4px #0002}
.card h2{margin:0 0 4px}.meta{color:#666;margin:0}.pitch{font-size:15px}.card h3{margin:14px 0 4px;font-size:14px}
.views{display:flex;gap:12px;flex-wrap:wrap}.view{border-radius:6px}
.vt{font-size:11px;fill:#555}.il{font-size:11px;fill:#111;text-anchor:middle;font-weight:600}
.sp{font-size:10px;fill:#6b3a00;text-anchor:middle}.lb{font-size:10px;fill:#7a6200}
.nt{font-size:10px;fill:#333;font-style:italic}.mn{font-size:10px;fill:#fff;text-anchor:middle;font-weight:700}
.star{font-size:18px;fill:#d4a000;text-anchor:middle}pre{background:#f1efe8;padding:8px;overflow:auto;font-size:11px}
table{border-collapse:collapse;font-size:13px}td,th{border-bottom:1px solid #e3e0d8;padding:3px 10px 3px 0;text-align:left;vertical-align:top}
.err{color:#b00}.legend span{margin-right:14px}
""" + "".join(f"body.hide-{k} .L-{k}{{display:none}}" for k in LAYERS)

LEGEND = (f'<p class="legend"><span style="color:{PILOT}">&#9632; pilot route</span>'
          f'<span style="color:{THREAT}">&#9632; threat route</span>'
          '<span style="color:#8a5a2b">- - rope bridge</span><span style="color:#6b6b6b">&#9473; stair</span>'
          '<span style="color:#b39461">&#9473; span</span><span style="color:#4d7a8c">&middot;&middot; floating stones</span>'
          '<span style="color:#c0392b">- - threat climb</span><span style="color:#e67e22">&#9650; tips</span>'
          '<span style="color:#e0b100">&#9632; landing</span><span style="color:#d4a000">&#9733; end</span>'
          f'<span style="color:{MOMENT}">&#9679; moment</span><span style="color:#c0392b">&#9632; enemy sleeps, '
          '- - wakes within</span><span style="color:#f1c40f">&#9670; collectible (blue edge: needs the plane)</span>'
          '<span>isle colour: low green &rarr; high pale</span></p>')

BAR = ('<div class="bar">' + "".join(
    f'<label><input type="checkbox" checked onchange="document.body.classList.toggle(\'hide-{k}\',!this.checked)"> {k}</label>'
    for k in LAYERS) + "</div>")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("path", help="a round folder, or one card or plan .md")
    ap.add_argument("--open", action="store_true", help="open the page when written (Mac)")
    a = ap.parse_args()
    path = pathlib.Path(a.path)
    if path.is_dir():
        files, out, title = sorted(path.glob("motif-*.md")), path / "index.html", path.name
    else:
        files, out, title = [path], path.with_suffix(".html"), f"{path.parent.name}/{path.name}"
    if not files:
        sys.exit(f"no motif-*.md cards in {path}")
    page = (f"<!doctype html><meta charset=utf-8><title>{e(title)}</title><style>{STYLE}</style>"
            f"<svg width=0 height=0><defs>{DEFS}</defs></svg><h1>{e(title)}</h1>{BAR}{LEGEND}"
            + "\n".join(panel(f) for f in files))
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out} ({len(files)} {'cards' if path.is_dir() else 'file'})")
    if a.open and sys.platform == "darwin":
        subprocess.run(["open", str(out)])


if __name__ == "__main__":
    main()

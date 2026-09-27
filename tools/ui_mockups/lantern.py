"""Direction B: Lantern. Luminous line glyphs floating in the air, no panels."""
import math
from common import (BRUSHES, FORMS, SEASONS, MOODS, svg_doc, glyph_url, polar, f, page, bezier_points)

NAME = "lantern"
W = "#fbf6ea"
GLOW = {"land": "#f2d7a6", "water": "#bfe6ee", "meadow": "#dcefb8", "forest": "#bfe3c8", "path": "#f1dcc4",
        "mood": "#f3cfe0", "look": "#fbf6ea", "photo": "#fbf6ea"}


def _g(inner, width=1.8):
    return svg_doc(f'<g fill="none" stroke="{W}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">\n{inner}\n</g>')


def glyph_inner():
    F = f'fill="{W}" stroke="none"'
    g = {}
    g["land"] = f'''<path d="M7 35A17 14 0 0 1 41 35"/><path d="M15.5 35A8.5 7 0 0 1 32.5 35" stroke-opacity=".5"/>
<path d="M4 35H44" stroke-opacity=".55"/><circle cx="24" cy="15.5" r="1.6" {F}/><circle cx="31" cy="12.5" r="1" {F} fill-opacity=".6"/>'''
    g["water"] = f'''<path d="M24 6L32.66 21A10 10 0 1 1 15.34 21Z"/><path d="M19 27A5 5 0 0 0 23 31.5" stroke-opacity=".6"/>
<path d="M14 42H34" stroke-opacity=".55"/><circle cx="10" cy="42" r="1" {F}/><circle cx="38" cy="42" r="1" {F}/>'''
    g["meadow"] = f'''<path d="M24 40V16"/><path d="M24 40Q23 30 13 23"/><path d="M24 40Q25 30 35 23"/>
<path d="M17 40H31" stroke-opacity=".55"/><circle cx="24" cy="12.5" r="1.9" {F}/><circle cx="11.5" cy="21.5" r="1.4" {F}/><circle cx="36.5" cy="21.5" r="1.4" {F}/>'''
    g["forest"] = f'''<path d="M24 6L35.5 33H12.5Z"/><path d="M24 33V41"/><path d="M18.6 25L24 18.6L29.4 25" stroke-opacity=".55"/>
<circle cx="24" cy="3.2" r="1.1" {F}/>'''
    pts = bezier_points((13, 43), (13, 32), (35, 32), (33, 23), 5)[:-1] + bezier_points((33, 23), (31, 14), (18, 17), (22, 6), 5)
    dots = "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(3.1 - 2.1 * i / (len(pts) - 1))}" {F} fill-opacity="{f(1 - .45 * i / (len(pts) - 1))}"/>' for i, (x, y) in enumerate(pts))
    g["path"] = dots
    g["look"] = f'''<path d="M5 24Q24 8 43 24Q24 40 5 24Z"/><circle cx="24" cy="24" r="5.5"/><circle cx="24" cy="24" r="1.8" {F}/>'''
    g["photo"] = f'''<path d="M8 16V10H14M34 10H40V16M40 32V38H34M14 38H8V32"/><circle cx="24" cy="24" r="6.5"/><circle cx="24" cy="24" r="1.6" {F}/>'''
    g["mood"] = f'''<circle cx="24" cy="24" r="11"/><path d="M24 13A11 11 0 0 1 24 35A6 11 0 0 0 24 13Z" {F} fill-opacity=".9"/>
<circle cx="37.5" cy="11" r="1.1" {F}/><circle cx="41" cy="18" r=".8" {F}/><circle cx="8" cy="34" r=".9" {F} fill-opacity=".6"/>'''
    g["craft"] = f'''<path d="M24 6L32 21.5Q28 31 24 42Q20 31 16 21.5Z"/><path d="M24 42V26.5"/><circle cx="24" cy="23" r="2.1"/>'''
    g["world"] = f'''<circle cx="24" cy="24" r="11.5"/><ellipse cx="24" cy="24" rx="20" ry="6" transform="rotate(-18 24 24)" stroke-opacity=".6"/>
<circle cx="42.4" cy="17.8" r="1.8" {F}/><path d="M17 26Q21 21.5 25 24T31.5 23" stroke-opacity=".6"/>'''
    g["rock"] = f'''<path d="M9 34L14 22L23 16L33 19L39 34Z"/><path d="M23 16L25 26L14 22M25 26L39 34M25 26L20 34" stroke-opacity=".5"/>'''
    g["form-hill"] = f'''<path d="M6 36A18 12 0 0 1 42 36"/><path d="M4 36H44" stroke-opacity=".5"/><circle cx="24" cy="19.5" r="1.3" {F}/>'''
    g["form-alpine"] = f'''<path d="M5 36L16 18L21 25L29 10L43 36"/><path d="M13 23L16 21L19 23M26 15.5L29 13.5L32 15.5" stroke-opacity=".6"/><path d="M4 36H44" stroke-opacity=".5"/>'''
    g["form-ridge"] = f'''<path d="M4 36L11 28L15 30L21 21L25 25L30 17L35 23L39 21L44 36"/><path d="M4 36H44" stroke-opacity=".5"/>'''
    g["form-mesa"] = f'''<path d="M5 36L13 20H35L43 36"/><path d="M11 26H37M8.5 31H39.5" stroke-opacity=".45"/><path d="M4 36H44" stroke-opacity=".5"/>'''
    g["form-volcano"] = f'''<path d="M5 36L19 18H29L43 36"/><path d="M4 36H44" stroke-opacity=".5"/>
<circle cx="24" cy="14" r="1.5" {F}/><circle cx="22" cy="9.5" r="1.1" {F} fill-opacity=".75"/><circle cx="25.5" cy="5.5" r=".8" {F} fill-opacity=".5"/>'''
    petals = "".join(f'<circle cx="{f(polar(24,24,6,a)[0])}" cy="{f(polar(24,24,6,a)[1])}" r="4.4"/>' for a in range(-90, 270, 72))
    g["season-spring"] = petals + f'<circle cx="24" cy="24" r="1.6" {F}/>'
    rays = "".join(f'<path d="M{f(polar(24,24,10,a)[0])} {f(polar(24,24,10,a)[1])}L{f(polar(24,24,13.5,a)[0])} {f(polar(24,24,13.5,a)[1])}"/>' for a in range(0, 360, 45))
    g["season-summer"] = f'<circle cx="24" cy="24" r="6"/>' + rays
    g["season-autumn"] = f'''<path d="M10 38C10 22 22 10 38 10C38 26 26 38 10 38Z"/><path d="M10 38L31 17" stroke-opacity=".55"/>'''
    arms = "".join(f'<path d="M{f(polar(24,24,3.5,a)[0])} {f(polar(24,24,3.5,a)[1])}L{f(polar(24,24,13,a)[0])} {f(polar(24,24,13,a)[1])}"/>'
                   f'<circle cx="{f(polar(24,24,16,a)[0])}" cy="{f(polar(24,24,16,a)[1])}" r="1.2" {F}/>' for a in range(-90, 270, 60))
    g["season-winter"] = arms
    return g


def glyphs():
    out = {k: _g(v) for k, v in glyph_inner().items()}
    # The halo sprite for selection, as concentric circles with stepped opacity
    # (no gradients, so it imports cleanly; Godot can also use a GradientTexture2D).
    rings = "".join(f'<circle cx="48" cy="48" r="{r}" fill="#ffffff" fill-opacity=".05"/>' for r in range(46, 12, -4))
    out["halo"] = svg_doc(rings, 96)
    return out


CSS = f"""
.cap{{font-family:'Cormorant';font-weight:600;font-size:13px;letter-spacing:.32em;text-transform:uppercase;color:{W};
  text-shadow:0 0 6px rgba(255,240,210,.55),0 1px 2px rgba(10,20,24,.7);white-space:nowrap}}
.lit{{filter:drop-shadow(0 0 3px rgba(255,246,222,.85)) drop-shadow(0 0 10px rgba(255,236,200,.45)) drop-shadow(0 1px 1.5px rgba(10,20,24,.55))}}
.dim{{filter:drop-shadow(0 1px 1.5px rgba(10,20,24,.65)) drop-shadow(0 0 6px rgba(10,20,24,.45));opacity:.86}}
.node{{position:absolute;width:0;height:0}}
.node > *{{position:absolute;transform:translate(-50%,-50%)}}
.ring{{border:1px solid rgba(251,246,234,.22);border-radius:50%;background:radial-gradient(circle,rgba(10,20,24,.30),rgba(10,20,24,.12) 70%,rgba(10,20,24,0))}}
.halo{{border-radius:50%;background:radial-gradient(circle,rgba(255,244,214,.42) 0%,rgba(255,236,196,.18) 38%,rgba(255,236,196,0) 70%)}}
.veil{{background:linear-gradient(180deg,rgba(18,28,32,.34),rgba(18,28,32,.46));backdrop-filter:blur(10px);border-radius:22px;
  border:1px solid rgba(251,246,234,.12);box-shadow:0 0 30px rgba(255,240,210,.06) inset}}
.keyb{{display:inline-block;border:1px solid rgba(251,246,234,.55);border-radius:9px;padding:0 7px;margin:0 6px 0 0;letter-spacing:.12em;line-height:16px}}
"""


def arc_positions(n, cx=720, cy=816, spacing=84, bow=0.00016):
    xs = [cx + (i - (n - 1) / 2) * spacing for i in range(n)]
    return [(x, cy + bow * (x - cx) ** 2) for x in xs]


def node(x, y, inner):
    return f'<div class="node" style="left:{f(x)}px;top:{f(y)}px">{inner}</div>'


def glyph_node(x, y, gid, state="", size=34, ring=54, label=None, colour=None, strength=.6, bsize=.55):
    colour = colour or GLOW.get(gid, W)
    out = []
    if state == "sel":
        out.append(f'<div class="halo" style="width:150px;height:150px;background:radial-gradient(circle,{colour}99 0%,{colour}44 34%,{colour}00 68%)"></div>')
        r = 31 + 16 * bsize
        motes = ""
        for i in range(5):
            a = -150 + i * 30
            mx, my = polar(0, 0, r, a)
            lit = i < round(strength * 5)
            motes += f'<circle cx="{f(mx+60)}" cy="{f(my+60)}" r="{2.6 if lit else 1.6}" fill="{colour if lit else W}" fill-opacity="{1 if lit else .35}"/>'
        out.append(f'<svg width="120" height="120" viewBox="0 0 120 120" class="lit"><circle cx="60" cy="60" r="{f(r)}" fill="none" stroke="{colour}" stroke-opacity=".75" stroke-width="1.2"'
                   f' stroke-dasharray="{f(2*math.pi*r*0.60)} {f(2*math.pi*r*0.08)} 1 400" transform="rotate(-30 60 60)"/>{motes}</svg>')
        out.append(f'<div class="ring" style="width:{ring}px;height:{ring}px;border-color:rgba(251,246,234,.6)"></div>')
    elif state == "hov":
        out.append(f'<div class="halo" style="width:96px;height:96px;background:radial-gradient(circle,{colour}66 0%,{colour}22 40%,{colour}00 70%)"></div>')
        out.append(f'<div class="ring" style="width:{ring+4}px;height:{ring+4}px;border-color:rgba(251,246,234,.4)"></div>')
    elif ring:
        out.append(f'<div class="ring" style="width:{ring}px;height:{ring}px"></div>')
    cls = "lit" if state in ("sel", "hov") else "dim"
    out.append(f'<img class="{cls}" src="{glyph_url(NAME, gid)}" style="width:{size}px;height:{size}px">')
    if label:
        out.append(f'<div class="cap" style="transform:translate(-50%,0);top:{ring/2+10}px">{label}</div>')
    return node(x, y, "".join(out))


def palette(held="land", hover=None, mood_open=False, cy=800):
    items = [g for g, _ in BRUSHES] + ["sep", "mood", "look", "photo"]
    pos = arc_positions(len(items), cy=cy, spacing=80)
    # A faint constellation thread strung through the glyphs.
    d = "M" + "L".join(f"{f(x)} {f(y)}" for x, y in pos)
    out = [f'<svg class="abs" style="left:0;top:0;overflow:visible" width="1" height="1"><path d="{d}" fill="none" stroke="{W}" stroke-opacity=".28" stroke-width="1" stroke-dasharray="2 5" stroke-linecap="round"/></svg>']
    titles = dict(BRUSHES + [("mood", "Mood"), ("look", "Look"), ("photo", "Photo")])
    for (x, y), gid in zip(pos, items):
        if gid == "sep":
            out.append(node(x, y, f'<svg width="10" height="10" class="dim"><path d="M5 1L9 5L5 9L1 5Z" fill="{W}" fill-opacity=".7"/></svg>'))
            continue
        small = gid in ("mood", "look", "photo")
        state = "sel" if (gid == held or (gid == "mood" and mood_open)) else ("hov" if gid == hover else "")
        if gid == "mood" and mood_open:
            state = "hov"
        label = titles[gid] if state in ("sel", "hov") else None
        out.append(glyph_node(x, y, gid, state, 32 if small else 40, 50 if small else 62, label))
    return "".join(out)


def backdrop(top=640):
    return (f'<div class="abs" style="left:0;right:0;top:{top}px;bottom:0;'
            f'background:radial-gradient(ellipse 52% 90% at 50% 100%,rgba(10,20,24,.62),rgba(10,20,24,.3) 55%,rgba(10,20,24,0) 100%)"></div>')


def corner_backdrop():
    return ('<div class="abs" style="right:0;top:0;width:360px;height:180px;'
            'background:radial-gradient(ellipse 70% 80% at 100% 0%,rgba(10,20,24,.42),rgba(10,20,24,0) 100%)"></div>')


def top_right():
    return (glyph_node(1322, 50, "craft", "", 32, 54, None) + glyph_node(1394, 50, "world", "", 32, 54, None)
            + node(1322, 94, '<div class="cap" style="font-size:11px;opacity:.75">Craft</div>')
            + node(1394, 94, '<div class="cap" style="font-size:11px;opacity:.75">World</div>'))


def forms_fan(cx, cy, selected="form-alpine", radius=112):
    out = [f'<div class="abs" style="left:{cx-170}px;top:{cy-190}px;width:340px;height:220px;'
           f'background:radial-gradient(ellipse 50% 55% at 50% 72%,rgba(10,20,24,.34),rgba(10,20,24,0))"></div>']
    for i, (gid, title) in enumerate(FORMS):
        a = -150 + i * 30
        x, y = polar(cx, cy, radius, a)
        sel = gid == selected
        out.append(glyph_node(x, y, gid, "hov" if sel else "", 32, 46 if sel else 44, None))
        # a faint thread from the land glyph to each form
        x0, y0 = polar(cx, cy, 38, a)
        x1, y1 = polar(cx, cy, radius - 26, a)
        out.append(f'<svg class="abs" style="left:0;top:0;overflow:visible" width="1" height="1"><path d="M{f(x0)} {f(y0)}L{f(x1)} {f(y1)}" stroke="{W}" stroke-opacity="{.5 if sel else .16}" stroke-width="1" stroke-dasharray="1 4" stroke-linecap="round"/></svg>')
    title = dict(FORMS)[selected]
    out.append(node(cx, cy - radius - 44, f'<div class="cap">{title}</div>'))
    return "".join(out)


def cursor(cx, cy, w=250, h=100, colour=GLOW["land"], strength=.7):
    rx, ry = w / 2, h / 2
    motes = ""
    n = 44
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx + rx * math.cos(a), ry + ry * math.sin(a)
        front = (math.sin(a) + 1) / 2
        motes += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(1.1 + 1.5*front)}" fill="{W}" fill-opacity="{f((.25 + .7*front) * (.5 + .5*strength))}"/>'
    inner = (f'<ellipse cx="{rx}" cy="{ry}" rx="{rx*.5}" ry="{ry*.5}" fill="none" stroke="{colour}" stroke-opacity=".55" stroke-width="1"/>')
    rise = "".join(f'<circle cx="{f(rx + dx)}" cy="{f(ry - dy)}" r="{r}" fill="{W}" fill-opacity="{o}"/>' for dx, dy, r, o in
                   ((-8, 26, 1.6, .8), (6, 44, 1.2, .6), (-3, 64, 1, .4), (10, 78, .8, .3), (-30, 18, 1.2, .5), (34, 30, 1, .45)))
    return (f'<div class="abs" style="left:{cx-rx-30}px;top:{cy-ry-100}px;width:{w+60}px;height:{h+130}px">'
            f'<div class="abs" style="left:30px;top:100px;width:{w}px;height:{h}px;border-radius:50%;'
            f'background:radial-gradient(ellipse,rgba(255,240,205,.30),rgba(255,236,196,.10) 45%,rgba(255,236,196,0) 72%)"></div>'
            f'<div class="abs" style="left:{30+rx-1}px;top:{100+ry-80}px;width:2px;height:80px;background:linear-gradient(0deg,rgba(255,244,214,.75),rgba(255,244,214,0))"></div>'
            f'<svg class="abs lit" style="left:30px;top:100px;overflow:visible" width="{w}" height="{h}">{motes}{inner}{rise}'
            f'<circle cx="{rx}" cy="{ry}" r="2.4" fill="{W}"/></svg></div>')


def hint(pairs, y=870):
    parts = []
    for i, (k, v) in enumerate(pairs):
        if i: parts.append('<span style="opacity:.45;margin:0 12px">◆</span>')
        parts.append(f'<span class="keyb">{k}</span>{v}')
    return f'<div class="abs cap" style="left:0;right:0;top:{y}px;text-align:center;font-size:13px;letter-spacing:.2em;opacity:.95">{"".join(parts)}</div>'


def orb(sky, glow, ground, size=44, sel=False, water=None):
    return (f'<div style="width:{size}px;height:{size}px;border-radius:50%;position:relative;'
            f'background:radial-gradient(circle at 62% 38%,#{glow} 0%,#{glow} 12%,rgba(0,0,0,0) 30%),'
            f'linear-gradient(180deg,#{sky} 0%,#{sky} 38%,#{glow} 56%,#{ground} 64%,#{ground} 100%);'
            f'box-shadow:0 0 {18 if sel else 10}px #{glow}{"cc" if sel else "88"},inset -4px -6px 10px rgba(0,0,0,.28),inset 3px 4px 8px rgba(255,255,255,.35);'
            f'border:1px solid rgba(251,246,234,{.9 if sel else .35})"></div>')


def mood_arc(selected="rosewater_dusk", cx=720, cy=718):
    out = [f'<div class="abs" style="left:{cx-400}px;top:{cy-90}px;width:800px;height:170px;background:radial-gradient(ellipse 50% 50% at 50% 55%,rgba(10,20,24,.30),rgba(10,20,24,0))"></div>']
    n = len(MOODS)
    for i, (mid, title, sky, glow, ground, water) in enumerate(MOODS):
        x = cx + (i - (n - 1) / 2) * 66
        y = cy + 0.00022 * (x - cx) ** 2
        sel = mid == selected
        out.append(node(x, y - (8 if sel else 0), orb(sky, glow, ground, 54 if sel else 42, sel)))
        if sel:
            out.append(node(x, y - 60, f'<div class="cap">{title}</div>'))
    return "".join(out)


def drawer(x, y, season="season-autumn"):
    seasons = ""
    for i, (gid, title) in enumerate(SEASONS):
        sel = gid == season
        seasons += (f'<div style="display:flex;flex-direction:column;align-items:center;width:52px;position:relative">'
                    + (f'<div class="halo" style="position:absolute;width:70px;height:70px;left:-9px;top:-17px"></div>' if sel else "")
                    + f'<img class="{"lit" if sel else "dim"}" src="{glyph_url(NAME, gid)}" style="width:30px;height:30px;position:relative">'
                    f'<div class="cap" style="font-size:9.5px;letter-spacing:.22em;margin-top:4px;opacity:{1 if sel else .6}">{title}</div></div>')
    chips = ""
    for gid, title, colour in (("meadow", "Grass", "80917b"), ("rock", "Rock", "8a8190"), ("water", "Water", "9a91b1")):
        chips += (f'<div style="display:flex;flex-direction:column;align-items:center;width:64px;gap:5px">'
                  f'<div style="width:30px;height:30px;border-radius:50%;background:#{colour};border:1px solid rgba(251,246,234,.8);'
                  f'box-shadow:0 0 12px #{colour}cc,inset -3px -4px 6px rgba(0,0,0,.25),inset 2px 3px 5px rgba(255,255,255,.3)"></div>'
                  f'<div class="cap" style="font-size:9.5px;letter-spacing:.22em;display:flex;align-items:center;gap:4px">'
                  f'<img src="{glyph_url(NAME, gid)}" style="width:14px;height:14px">{title}</div></div>')
    return (f'<div class="abs veil" style="left:{x}px;top:{y}px;width:260px;padding:16px 14px 14px">'
            f'<div style="display:flex;justify-content:space-between;padding:0 4px">{seasons}</div>'
            f'<div style="height:1px;margin:14px 20px;background:linear-gradient(90deg,rgba(251,246,234,0),rgba(251,246,234,.35),rgba(251,246,234,0))"></div>'
            f'<div style="display:flex;justify-content:space-around">{chips}</div></div>')


def create_frame(bgs):
    pos = arc_positions(9, cy=800, spacing=80)
    lx, ly = pos[0]
    body = (backdrop() + corner_backdrop() + top_right() + cursor(1120, 612) + forms_fan(lx, ly) + palette()
            + hint([("drag", "raise land"), ("shift", "hollow"), ("[ ]", "size"), ("tab", "look")]))
    return page(body, CSS, bgs["forest"])


def mood_frame(bgs):
    body = (backdrop(560) + corner_backdrop() + top_right() + mood_arc() + drawer(1052, 596) + palette(mood_open=True)
            + hint([("click", "a mood"), ("hold", "compare"), ("esc", "close")]))
    return page(body, CSS, bgs["island"])


SHEET_CSS = """
.sheet-bg{position:absolute;inset:-60px;background-size:cover;filter:blur(26px) brightness(.5) saturate(.8)}
.sheet{position:relative;padding:40px 56px;display:flex;flex-direction:column;gap:30px}
.sheet-title{font-family:'Cormorant';font-weight:500;font-size:44px;letter-spacing:.06em;color:#fbf6ea}
.sheet-sub{font-family:'Cormorant';font-style:italic;font-size:19px;color:#efe7d6;opacity:.85;margin-top:-24px}
.sheet-h{font-family:'Cormorant';font-weight:600;font-size:13px;letter-spacing:.28em;text-transform:uppercase;color:#fbf6ea;opacity:.85}
.sheet-n{font-family:'Cormorant';font-size:15px;color:#efe7d6;opacity:.8;max-width:380px;line-height:1.3}
.row{display:flex;gap:40px;align-items:flex-start;flex-wrap:wrap}
.stage{position:relative;border-radius:14px;overflow:hidden;background-size:cover}
"""


def _card(title, inner, note="", w=None):
    style = f"width:{w}px;" if w else ""
    return (f'<div style="{style}display:flex;flex-direction:column;gap:10px"><div class="sheet-h">{title}</div>{inner}'
            + (f'<div class="sheet-n">{note}</div>' if note else "") + "</div>")


def stage(bg, w, h, inner, pos="center"):
    return f'<div class="stage" style="width:{w}px;height:{h}px;background-image:url(file://{bg});background-position:{pos}">{inner}</div>'


def sheet(bgs):
    names = [g for g, _ in BRUSHES] + ["mood", "look", "photo", "craft", "world"] + [g for g, _ in FORMS] + [g for g, _ in SEASONS] + ["rock"]
    cells = "".join(f'<div style="display:flex;flex-direction:column;align-items:center;width:76px;gap:6px"><img class="lit" src="{glyph_url(NAME, n)}" style="width:52px;height:52px">'
                    f'<div class="cap" style="font-size:9px;letter-spacing:.2em;opacity:.7">{n.replace("form-","").replace("season-","")}</div></div>' for n in names)
    glyph_panel = f'<div style="width:1328px;padding:20px 24px;border-radius:16px;background:rgba(10,20,24,.45);display:flex;flex-wrap:wrap;gap:14px 6px">{cells}</div>'
    def st(state, label, **kw):
        return (f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px">'
                + stage(bgs["forest"], 150, 150, glyph_node(75, 70, "water", state, 36, 58, "Water" if state else None, **kw), "58% 78%")
                + f'<div class="sheet-n" style="text-align:center;max-width:150px">{label}</div></div>')
    states = st("", "idle: dim, thin ring") + st("hov", "hover: lifts 3px, halo breathes in") + st("sel", "selected: halo, size ring, strength motes")
    sizes = "".join(st("sel", lbl, strength=t, bsize=s) for s, t, lbl in ((.1, .2, "small, soft"), (1, 1, "wide, strong")))
    painting = stage(bgs["forest"], 300, 150, glyph_node(150, 92, "water", "sel", 30, 50, None) + cursor(150, 40, 150, 56, GLOW["water"]), "60% 80%")
    fan = stage(bgs["forest"], 420, 230, forms_fan(210, 200), "30% 90%")
    curs = stage(bgs["island"], 300, 180, cursor(150, 110, 150, 60, strength=.3), "62% 70%") + stage(bgs["island"], 300, 180, cursor(150, 110, 260, 104, strength=1), "62% 70%")
    moods = stage(bgs["island"], 700, 190, mood_arc(cx=350, cy=120), "50% 80%")
    drw = stage(bgs["island"], 300, 190, drawer(20, 18), "80% 70%")
    hint_stage = stage(bgs["forest"], 700, 44, hint([("drag", "raise land"), ("shift", "hollow"), ("[ ]", "size"), ("tab", "look")], 14), "50% 95%")
    body = (f'<div class="sheet-bg" style="background-image:url(file://{bgs["forest"]})"></div><div class="sheet">'
            '<div class="sheet-title">B · Lantern</div><div class="sheet-sub">Luminous line glyphs that float in the air. No panels, no chrome; the world is the surface.</div>'
            + _card("Glyph set (docs/ui/glyphs/lantern)", glyph_panel)
            + '<div class="row">' + _card("Brush states", f'<div style="display:flex;gap:14px">{states}</div>')
            + _card("Size ring + strength motes", f'<div style="display:flex;gap:14px">{sizes}</div>', "The ring around the held glyph widens with [ ]; the five motes on its arc light up with Shift [ ].")
            + _card("While painting", painting, "Every other glyph fades to nothing; the held glyph sinks to a small lantern at the bottom edge.", 300) + '</div>'
            + '<div class="row">' + _card("Land forms fan out above Land", fan)
            + _card("Cursor: a ring of motes", f'<div style="display:flex;gap:14px">{curs}</div>', "Motes brighten toward the viewer; a thin beam marks the centre. Strength = mote brightness.") + '</div>'
            + '<div class="row">' + _card("Mood orbs", moods) + _card("Customise veil", drw) + '</div>'
            + _card("Hint line", hint_stage)
            + '</div>')
    return page(body, CSS + SHEET_CSS, None, 1440, 1330)

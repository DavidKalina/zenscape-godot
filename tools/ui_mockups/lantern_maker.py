"""Direction B2: Lantern Maker. Lantern's luminous glyphs in a Mario Maker 2 layout.

Layout (design units at 1440x900; every group is anchored to a screen edge and
scaled by min(W/1440, H/900), the way Godot anchors plus a content scale would):

  top centre    parts bar: 5 brushes + 3 empty future slots, forms fan below the held brush
  left middle   hand modes: paint, the other way, grab/look, undo (the wisp)
  right middle  Mood, World, Craft
  bottom right  Photo, the big "play" button
  bottom centre season scrubber + hint line
"""
import math
from common import (BRUSHES, FORMS, SEASONS, MOODS, svg_doc, glyph_url, polar, f, page)
import lantern

NAME = "lantern-maker"
W = lantern.W
GLOW = dict(lantern.GLOW, paint="#f2d7a6", lower="#d9c9f2", grab="#fbf6ea", undo="#f6e3a8", world="#cfe3f2", craft="#f1dcc4")
DW, DH = 1440, 900          # design size
SLOT = 56                   # hit target and ring diameter
GAP = 16                    # grid gap
PITCH = SLOT + GAP          # 72
MARGIN = 24


# ------------------------------------------------------------------ glyphs

def _g(inner, width=1.8):
    return svg_doc(f'<g fill="none" stroke="{W}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">\n{inner}\n</g>')


def new_glyphs():
    F = f'fill="{W}" stroke="none"'
    g = {}
    # Paint: a brush nib laying a stroke of light.
    g["paint"] = (f'<path d="M33 8L40 15L22 33L15 26Z"/><path d="M15 26Q9 28 8.5 36Q8 40 12 39.5Q20 39 22 33"/>'
                  f'<path d="M29 12L36 19" stroke-opacity=".5"/><circle cx="36" cy="36" r="1.5" {F}/><circle cx="41" cy="31" r="1" {F} fill-opacity=".7"/>')
    # The other way: a hollow pressed into the ground, with a downward chevron.
    g["lower"] = (f'<path d="M5 30H13A11 9 0 0 0 35 30H43"/><path d="M17.5 30A6.5 5 0 0 0 30.5 30" stroke-opacity=".5"/>'
                  f'<path d="M24 8V20M19 15.5L24 20.5L29 15.5"/>')
    # Grab / look: an open hand.
    g["grab"] = (f'<path d="M16 31V17.5A2 2 0 0 1 20 17.5V26M20 25V13A2 2 0 0 1 24 13V25M24 25V14.5A2 2 0 0 1 28 14.5V26M28 26V19A2 2 0 0 1 32 19V30'
                 f'Q32 39 24 40Q17.5 40.5 14 35L9.5 28.5A2 2 0 0 1 13 26L16 29"/>'
                 f'<path d="M36 10A6 6 0 0 1 40 16" stroke-opacity=".55"/><path d="M40 16l.2-3.2M40 16l-3-.9" stroke-opacity=".55"/>')
    # Undo: the wisp, a little lantern spirit whose tail curls back into an undo arrow.
    g["undo"] = (f'<circle cx="20" cy="24" r="9"/><path d="M13.5 17.5L12.5 10.5L18 15.3M22 15.3L27.5 10.5L26.5 17.5"/>'
                 f'<circle cx="17" cy="24" r="1.4" {F}/><circle cx="23" cy="24" r="1.4" {F}/><path d="M18.5 28Q20 29.2 21.5 28" stroke-width="1.4"/>'
                 f'<path d="M29 25A9 9 0 1 0 38 16" /><path d="M38 16l-4.2-1.2M38 16l1-4.3"/><circle cx="9" cy="33" r="1" {F} fill-opacity=".6"/>')
    dots = "".join(f'<circle cx="{f(polar(24,24,10,a)[0])}" cy="{f(polar(24,24,10,a)[1])}" r=".9" {F} fill-opacity=".55"/>' for a in range(0, 360, 30))
    g["slot-empty"] = dots + '<path d="M24 20V28M20 24H28" stroke-opacity=".45"/>'
    return g


def glyphs():
    out = {k: _g(v) for k, v in lantern.glyph_inner().items()}
    out.update({k: _g(v) for k, v in new_glyphs().items()})
    # Legibility plate: a soft dark disc of stepped circles (no gradient) to sit under every glyph.
    out["underglow"] = svg_doc("".join(f'<circle cx="48" cy="48" r="{r}" fill="#08141a" fill-opacity=".09"/>' for r in range(46, 20, -4)), 96)
    out["halo"] = svg_doc("".join(f'<circle cx="48" cy="48" r="{r}" fill="#ffffff" fill-opacity=".05"/>' for r in range(46, 12, -4)), 96)
    return out


# ------------------------------------------------------------------ CSS

CSS = f"""
.cap{{font-family:'Cormorant';font-weight:600;font-size:13px;letter-spacing:.24em;text-transform:uppercase;color:{W};
  text-shadow:0 0 3px rgba(8,20,26,.95),0 0 10px rgba(8,20,26,.7),0 0 6px rgba(255,240,210,.35);white-space:nowrap}}
.g-lit{{filter:drop-shadow(0 0 1.5px rgba(8,20,26,.95)) drop-shadow(0 0 4px rgba(255,246,222,.85)) drop-shadow(0 0 12px rgba(255,236,200,.4))}}
.g-dim{{filter:drop-shadow(0 0 1.5px rgba(8,20,26,.95)) drop-shadow(0 0 6px rgba(8,20,26,.55));opacity:.9}}
.anchor{{position:absolute;width:0;height:0;transform-origin:0 0}}
.n{{position:absolute;width:0;height:0}}
.n > *{{position:absolute;transform:translate(-50%,-50%)}}
.plate{{position:absolute;border-radius:999px;background:rgba(8,18,24,.40);box-shadow:0 0 26px 12px rgba(8,18,24,.36)}}
.ring{{border-radius:50%;border:1px solid rgba(251,246,234,.30)}}
.under{{border-radius:50%;background:radial-gradient(circle,rgba(8,18,24,.62) 0%,rgba(8,18,24,.42) 45%,rgba(8,18,24,0) 72%)}}
.halo{{border-radius:50%}}
.keyb{{display:inline-block;border:1px solid rgba(251,246,234,.6);border-radius:9px;padding:0 7px;margin:0 6px 0 0;letter-spacing:.1em;line-height:16px}}
.veil{{background:rgba(8,18,24,.46);backdrop-filter:blur(10px);border-radius:24px;border:1px solid rgba(251,246,234,.14);box-shadow:0 0 26px 8px rgba(8,18,24,.3)}}
"""


def n(x, y, inner):
    return f'<div class="n" style="left:{f(x)}px;top:{f(y)}px">{inner}</div>'


def thread(points, opacity=.3, dash="1.5 5"):
    d = "M" + "L".join(f"{f(x)} {f(y)}" for x, y in points)
    return (f'<svg style="position:absolute;left:0;top:0;overflow:visible" width="1" height="1"><path d="{d}" fill="none" stroke="{W}" '
            f'stroke-opacity="{opacity}" stroke-width="1" stroke-dasharray="{dash}" stroke-linecap="round"/></svg>')


def slot(x, y, gid, state="", size=SLOT, glyph=34, colour=None, label=None, label_side="below"):
    """One button: dark under-glow (legibility), ring, optional tinted halo, glyph, optional label."""
    colour = colour or GLOW.get(gid, W)
    parts = [f'<div class="under" style="width:{size*1.6}px;height:{size*1.6}px"></div>']
    if state == "held":
        parts.append(f'<div class="halo" style="width:{size*2.3}px;height:{size*2.3}px;background:radial-gradient(circle,{colour}a0 0%,{colour}40 32%,{colour}00 66%)"></div>')
        parts.append(f'<div class="ring" style="width:{size}px;height:{size}px;border:1.5px solid {colour}"></div>')
        parts.append(f'<div class="ring" style="width:{size+10}px;height:{size+10}px;border-color:{colour}55"></div>')
    elif state == "hov":
        parts.append(f'<div class="halo" style="width:{size*1.7}px;height:{size*1.7}px;background:radial-gradient(circle,{colour}60 0%,{colour}00 64%)"></div>')
        parts.append(f'<div class="ring" style="width:{size+4}px;height:{size+4}px;border-color:rgba(251,246,234,.6)"></div>')
    elif state == "ghost":
        pass
    else:
        parts.append(f'<div class="ring" style="width:{size}px;height:{size}px"></div>')
    cls = "g-lit" if state in ("held", "hov") else "g-dim"
    parts.append(f'<img class="{cls}" src="{glyph_url(NAME, gid)}" style="width:{glyph}px;height:{glyph}px">')
    if label:
        if label_side == "below":
            parts.append(f'<div class="cap" style="transform:translate(-50%,0);top:{size/2+10}px">{label}</div>')
        elif label_side == "right":
            parts.append(f'<div class="cap" style="transform:translate(0,-50%);left:{size/2+14}px">{label}</div>')
        else:
            parts.append(f'<div class="cap" style="transform:translate(-100%,-50%);left:{-size/2-14}px">{label}</div>')
    return n(x, y, "".join(parts))


def anchor(ax, ay, s, inner, opacity=1, shift=(0, 0)):
    return (f'<div class="anchor" style="left:{f(ax + shift[0])}px;top:{f(ay + shift[1])}px;transform:scale({s});opacity:{opacity}">{inner}</div>')


# ------------------------------------------------------------------ groups (local coordinates)

BAR_ITEMS = [g for g, _ in BRUSHES] + ["slot-empty"] * 3
BAR_W = len(BAR_ITEMS) * SLOT + (len(BAR_ITEMS) - 1) * GAP + 2 * 20
BAR_Y = MARGIN + 36          # slot centre, 60


def bar_x(i):
    return -BAR_W / 2 + 20 + SLOT / 2 + i * PITCH


def top_bar(held="land", hover=None, wheel=True, form="form-alpine"):
    out = [f'<div class="plate" style="left:{-BAR_W/2}px;top:{BAR_Y-40}px;width:{BAR_W}px;height:80px"></div>']
    out.append(thread([(bar_x(0), BAR_Y), (bar_x(4), BAR_Y)], .25))
    for i, gid in enumerate(BAR_ITEMS):
        if gid == "slot-empty":
            out.append(slot(bar_x(i), BAR_Y, gid, "ghost", glyph=30))
            continue
        st = "held" if gid == held else ("hov" if gid == hover else "")
        out.append(slot(bar_x(i), BAR_Y, gid, st, glyph=36))
        if gid == "land" and st == "held":
            # a tiny badge of the form in hand on the Land slot (Mario Maker shows the variant on the part)
            out.append(n(bar_x(i) + 20, BAR_Y + 20, f'<div style="width:22px;height:22px;border-radius:50%;background:rgba(8,18,24,.7);border:1px solid {GLOW["land"]};display:flex;align-items:center;justify-content:center">'
                                                   f'<img class="g-lit" src="{glyph_url(NAME, form)}" style="width:16px;height:16px"></div>'))
    if wheel and held == "land":
        out.append(forms_wheel(bar_x(0), BAR_Y, form))
    return "".join(out)


def forms_wheel(cx, cy, selected="form-alpine", radius=146):
    out = [f'<div style="position:absolute;left:{cx-210}px;top:{cy+10}px;width:420px;height:250px;'
           f'background:radial-gradient(ellipse 50% 56% at 50% 40%,rgba(8,18,24,.55),rgba(8,18,24,.3) 55%,rgba(8,18,24,0) 100%)"></div>']
    # an arc of light the forms sit on
    arc = [polar(cx, cy, radius, a) for a in range(160, 19, -5)]
    out.append(thread(arc, .22, "1 4"))
    for i, (gid, title) in enumerate(FORMS):
        a = 150 - i * 30
        x, y = polar(cx, cy, radius, a)
        sel = gid == selected
        x0, y0 = polar(cx, cy, 40, a)
        x1, y1 = polar(cx, cy, radius - 30, a)
        out.append(thread([(x0, y0), (x1, y1)], .6 if sel else .2, "1 4"))
        out.append(slot(x, y, gid, "held" if sel else "", 52, 32, GLOW["land"]))
        out.append(n(x, y + 38, f'<div class="cap" style="font-size:{11 if sel else 10}px;letter-spacing:.16em;opacity:{1 if sel else .72}">{title}</div>'))
    return "".join(out)


MODES = [("paint", "Paint"), ("lower", "Other way"), ("grab", "Look"), ("undo", "Undo")]
COL_TOP = -(len(MODES) * SLOT + (len(MODES) - 1) * GAP) / 2 - 12


def col_y(i):
    return COL_TOP + 12 + SLOT / 2 + i * PITCH


def left_column(mode="paint", hover=None, undo_frame=0):
    h = len(MODES) * SLOT + (len(MODES) - 1) * GAP + 24
    x = MARGIN + 40
    out = [f'<div class="plate" style="left:{x-40}px;top:{COL_TOP}px;width:80px;height:{h}px"></div>']
    for i, (gid, title) in enumerate(MODES):
        st = "held" if gid == mode else ("hov" if gid == hover else "")
        y = col_y(i)
        if gid == "undo":
            out.append(n(x, y - SLOT / 2 - GAP / 2, '<div style="width:34px;height:1px;background:linear-gradient(90deg,rgba(251,246,234,0),rgba(251,246,234,.4),rgba(251,246,234,0))"></div>'))
            out.append(undo_slot(x, y, undo_frame, st))
        else:
            out.append(slot(x, y, gid, st, glyph=34, label=title if st else None, label_side="right"))
    return "".join(out)


def undo_slot(x, y, frame=0, state=""):
    """The wisp: idle bob (0), hop with tail spin on press (1), rewind sparkle (2)."""
    dy, rot, sparks = ((0, 0, 0), (-7, -24, 0), (-3, -200, 1))[frame]
    extra = ""
    if sparks:
        for a in range(0, 360, 45):
            px, py = polar(0, 0, 30, a)
            extra += n(x + px, y + py, f'<div style="width:3px;height:3px;border-radius:50%;background:{GLOW["undo"]};box-shadow:0 0 6px {GLOW["undo"]}"></div>')
    base = slot(x, y, "undo", "held" if frame else state, glyph=0, colour=GLOW["undo"])
    wisp = n(x, y + dy, f'<img class="g-lit" src="{glyph_url(NAME, "undo")}" style="width:38px;height:38px;transform:translate(-50%,-50%) rotate({rot if frame == 1 else 0}deg)">')
    shadow = n(x, y + 20, f'<div style="width:{18 - abs(dy)}px;height:3px;border-radius:50%;background:rgba(255,240,200,.35)"></div>')
    return base + shadow + wisp + extra


RIGHT = [("mood", "Mood"), ("world", "World"), ("craft", "Craft")]


def right_column(open_=None, hover=None):
    h = len(RIGHT) * SLOT + (len(RIGHT) - 1) * GAP + 24
    x = -(MARGIN + 40)
    out = [f'<div class="plate" style="left:{x-40}px;top:{COL_TOP}px;width:80px;height:{h}px"></div>']
    for i, (gid, title) in enumerate(RIGHT):
        st = "held" if gid == open_ else ("hov" if gid == hover else "")
        out.append(slot(x, col_y(i), gid, st, glyph=34, label=title if st == "hov" else None, label_side="left"))
    return "".join(out)


def photo_button(state=""):
    x, y = -(MARGIN + 46), -(MARGIN + 46 + 28)
    size = 84
    colour = "#fbe7c4"
    return (n(x, y, f'<div class="under" style="width:150px;height:150px"></div>'
                    f'<div class="halo" style="width:170px;height:170px;background:radial-gradient(circle,{colour}66 0%,{colour}22 36%,{colour}00 66%)"></div>'
                    f'<div class="ring" style="width:{size}px;height:{size}px;border:1.5px solid rgba(251,246,234,.75)"></div>'
                    f'<div class="ring" style="width:{size+12}px;height:{size+12}px;border-color:rgba(251,246,234,.25)"></div>'
                    f'<img class="g-lit" src="{glyph_url(NAME, "photo")}" style="width:46px;height:46px">')
            + n(x, y + size / 2 + 18, '<div class="cap" style="font-size:12px">Photo</div>'))


def scrubber(season_at=.62, y=-58, w=360):
    out = [f'<div class="plate" style="left:{-w/2-18}px;top:{y-16}px;width:{w+36}px;height:32px;box-shadow:0 0 18px 8px rgba(8,18,24,.3)"></div>']
    out.append(f'<div style="position:absolute;left:{-w/2}px;top:{y}px;width:{w}px;height:1px;background:rgba(251,246,234,.45)"></div>')
    for i, (gid, title) in enumerate(SEASONS):
        x = -w / 2 + w * (i + .5) / 4
        out.append(n(x, y, f'<img class="g-dim" src="{glyph_url(NAME, gid)}" style="width:18px;height:18px;opacity:.75">'))
    for i in range(17):
        x = -w / 2 + w * i / 16
        out.append(n(x, y, f'<div style="width:1px;height:{7 if i % 4 == 0 else 4}px;background:rgba(251,246,234,.5)"></div>'))
    hx = -w / 2 + w * season_at
    out.append(n(hx, y, f'<div style="width:14px;height:14px;border-radius:50%;background:{W};box-shadow:0 0 8px rgba(255,240,210,.9),0 0 18px rgba(255,220,170,.6)"></div>'))
    return "".join(out)


def hint(pairs, y=-24):
    parts = []
    for i, (k, v) in enumerate(pairs):
        if i: parts.append('<span style="opacity:.45;margin:0 12px">◆</span>')
        parts.append(f'<span class="keyb">{k}</span>{v}')
    return n(0, y, f'<div class="cap" style="font-size:12px;letter-spacing:.18em">{"".join(parts)}</div>')


def cursor(cx, cy, w=250, h=100, colour=GLOW["land"], strength=.6, form="form-alpine", puff=0):
    """Size = the ring. Strength = five lit motes on the front arc. The form in hand floats on the beam."""
    rx, ry = w / 2, h / 2
    grow = 1 + .08 * puff
    motes = ""
    nm = 44
    for i in range(nm):
        a = 2 * math.pi * i / nm
        x, y = rx + rx * grow * math.cos(a), ry + ry * grow * math.sin(a)
        front = (math.sin(a) + 1) / 2
        motes += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(1 + 1.3*front)}" fill="{W}" fill-opacity="{f(.3 + .55*front)}"/>'
    strength_dots = ""
    for i in range(5):
        a = math.radians(60 + i * 15)
        x, y = rx + rx * 1.14 * math.cos(a), ry + ry * 1.3 * math.sin(a)
        lit = i < round(strength * 5)
        strength_dots += f'<circle cx="{f(x)}" cy="{f(y)}" r="{3.4 if lit else 2}" fill="{colour if lit else W}" fill-opacity="{1 if lit else .35}" stroke="#08141a" stroke-opacity=".6" stroke-width=".8"/>'
    under = (f'<ellipse cx="{rx}" cy="{ry}" rx="{rx*1.06}" ry="{ry*1.06}" fill="none" stroke="#08141a" stroke-opacity=".28" stroke-width="7"/>')
    inner = f'<ellipse cx="{rx}" cy="{ry}" rx="{rx*.5}" ry="{ry*.5}" fill="none" stroke="{colour}" stroke-opacity=".6" stroke-width="1"/>'
    rise = "".join(f'<circle cx="{f(rx + dx)}" cy="{f(ry - dy)}" r="{r}" fill="{W}" fill-opacity="{o}"/>' for dx, dy, r, o in
                   ((-8, 26, 1.6, .8), (6, 44, 1.2, .6), (-3, 64, 1, .4), (-30, 18, 1.2, .5), (34, 30, 1, .45))[: 3 + 2 * puff])
    tag = (f'<div style="position:absolute;left:{30+rx-17}px;top:{100+ry-120}px;width:34px;height:34px;border-radius:50%;background:rgba(8,18,24,.55);'
           f'border:1px solid {colour};box-shadow:0 0 12px {colour}88;display:flex;align-items:center;justify-content:center">'
           f'<img class="g-lit" src="{glyph_url(NAME, form)}" style="width:24px;height:24px"></div>') if form else ""
    return (f'<div style="position:absolute;left:{cx-rx-30}px;top:{cy-ry-100}px;width:{w+60}px;height:{h+130}px">'
            f'<div style="position:absolute;left:30px;top:100px;width:{w}px;height:{h}px;border-radius:50%;'
            f'background:radial-gradient(ellipse,rgba(255,240,205,{.38 if puff else .28}),rgba(255,236,196,.10) 45%,rgba(255,236,196,0) 72%)"></div>'
            f'<div style="position:absolute;left:{30+rx-1}px;top:{100+ry-84}px;width:2px;height:84px;background:linear-gradient(0deg,rgba(255,244,214,.8),rgba(255,244,214,0))"></div>'
            f'<svg style="position:absolute;left:30px;top:100px;overflow:visible" class="g-lit" width="{w}" height="{h}">{under}{motes}{inner}{rise}{strength_dots}'
            f'<circle cx="{rx}" cy="{ry}" r="2.4" fill="{W}"/></svg>{tag}</div>')


def orb(sky, glow, ground, size=44, sel=False):
    return (f'<div style="width:{size}px;height:{size}px;border-radius:50%;'
            f'background:radial-gradient(circle at 62% 36%,#{glow} 0%,#{glow} 12%,rgba(0,0,0,0) 30%),'
            f'linear-gradient(180deg,#{sky} 0%,#{sky} 38%,#{glow} 56%,#{ground} 64%,#{ground} 100%);'
            f'box-shadow:0 0 0 3px rgba(8,18,24,.45),0 0 {18 if sel else 10}px #{glow}{"cc" if sel else "88"},inset -4px -6px 10px rgba(0,0,0,.28),inset 3px 4px 8px rgba(255,255,255,.35);'
            f'border:1px solid rgba(251,246,234,{.95 if sel else .45})"></div>')


def mood_fan(selected="rosewater_dusk"):
    """Orbs pour out of the Mood slot in a crescent that bows toward the centre of the screen."""
    mx, my = -(MARGIN + 40), col_y(0)
    out = [f'<div style="position:absolute;left:-340px;top:-330px;width:260px;height:640px;'
           f'background:radial-gradient(ellipse 50% 50% at 60% 50%,rgba(8,18,24,.42),rgba(8,18,24,0))"></div>']
    pts = []
    count = len(MOODS)
    for i in range(count):
        y = -232 + i * 58
        x = -216 + 0.0011 * y * y
        pts.append((x, y))
    out.append(thread([(mx, my)] + [pts[0]], .35))
    out.append(thread(pts, .22))
    for (x, y), (mid, title, sky, glow, ground, water) in zip(pts, MOODS):
        sel = mid == selected
        out.append(n(x, y, orb(sky, glow, ground, 56 if sel else 44, sel)))
        if sel:
            out.append(thread([(x - 30, y), (-368, y)], .45))
    return "".join(out)


def drawer(x, y, season="season-autumn", title="Rosewater dusk"):
    seasons = ""
    for gid, label in SEASONS:
        sel = gid == season
        seasons += (f'<div style="display:flex;flex-direction:column;align-items:center;width:56px;position:relative">'
                    + (f'<div style="position:absolute;width:76px;height:76px;left:-10px;top:-17px;border-radius:50%;background:radial-gradient(circle,#f2d7a699 0%,#f2d7a600 64%)"></div>' if sel else "")
                    + f'<div style="width:44px;height:44px;border-radius:50%;border:1px solid rgba(251,246,234,{.7 if sel else .25});display:flex;align-items:center;justify-content:center;position:relative">'
                    f'<img class="{"g-lit" if sel else "g-dim"}" src="{glyph_url(NAME, gid)}" style="width:28px;height:28px"></div>'
                    f'<div class="cap" style="font-size:9.5px;letter-spacing:.16em;margin-top:6px;opacity:{1 if sel else .7}">{label}</div></div>')
    chips = ""
    for gid, label, colour in (("meadow", "Grass", "80917b"), ("rock", "Rock", "8a8190"), ("water", "Water", "9a91b1")):
        chips += (f'<div style="display:flex;flex-direction:column;align-items:center;width:70px;gap:6px">'
                  f'<div style="width:44px;height:44px;border-radius:50%;display:flex;align-items:center;justify-content:center;border:1px solid rgba(251,246,234,.25)">'
                  f'<div style="width:30px;height:30px;border-radius:50%;background:#{colour};border:1px solid rgba(251,246,234,.85);'
                  f'box-shadow:0 0 12px #{colour}cc,inset -3px -4px 6px rgba(0,0,0,.25),inset 2px 3px 5px rgba(255,255,255,.3)"></div></div>'
                  f'<div class="cap" style="font-size:9.5px;letter-spacing:.16em;display:flex;align-items:center;gap:4px">'
                  f'<img src="{glyph_url(NAME, gid)}" style="width:14px;height:14px">{label}</div></div>')
    return (f'<div class="veil" style="position:absolute;left:{x}px;top:{y}px;width:272px;padding:18px 14px 16px">'
            f'<div class="cap" style="font-size:13px;text-align:center">{title}</div>'
            f'<div class="cap" style="font-size:9.5px;opacity:.6;text-align:center;margin:4px 0 14px">tune this mood</div>'
            f'<div style="display:flex;justify-content:space-between;padding:0 2px">{seasons}</div>'
            f'<div style="height:1px;margin:14px 20px;background:linear-gradient(90deg,rgba(251,246,234,0),rgba(251,246,234,.35),rgba(251,246,234,0))"></div>'
            f'<div style="display:flex;justify-content:space-around">{chips}</div></div>')


# ------------------------------------------------------------------ screens

LAND_HINT = [("drag", "raise land"), ("right drag", "the other way"), ("[ ]", "size"), ("shift [ ]", "strength")]


def screen(W_, H_, bg, *, held="land", wheel=True, mode="paint", mood=False, painting=False, cursor_at=None,
           bg_filter=None, hint_pairs=LAND_HINT, undo_frame=0):
    s = min(W_ / DW, H_ / DH)
    bg_style = f"background:url('file://{bg}') center/cover;"
    body = [f'<div style="position:absolute;inset:0;{bg_style}{"filter:" + bg_filter if bg_filter else ""}"></div>']
    if cursor_at:
        cx, cy = cursor_at
        body.append(cursor(cx * W_ / DW, cy * H_ / DH, 250 * s, 100 * s, GLOW.get(held, W), .6 if not painting else .8,
                           "form-alpine" if held == "land" else None, 1 if painting else 0))
    fade = .16 if painting else 1
    if painting:
        # The bar lifts away; only the held brush stays, small, at the top centre.
        body.append(anchor(W_ / 2, 0, s, slot(0, 34, held, "held", 44, 28)
                           + n(22, 52, f'<img class="g-lit" src="{glyph_url(NAME, "form-alpine")}" style="width:16px;height:16px">')))
    else:
        body.append(anchor(W_ / 2, 0, s, top_bar(held, wheel=wheel)))
    body.append(anchor(0, H_ / 2, s, left_column(mode, undo_frame=undo_frame), fade, (-14 if painting else 0, 0)))
    body.append(anchor(W_, H_ / 2, s, right_column("mood" if mood else None) + (mood_fan() + drawer(-640, -150) if mood else ""), fade, (14 if painting else 0, 0)))
    body.append(anchor(W_, H_, s, photo_button(), fade))
    if not painting:
        body.append(anchor(W_ / 2, H_, s, scrubber() + hint(hint_pairs)))
    return page("".join(body), CSS, None, W_, H_)


def create_frame(bgs):
    return screen(DW, DH, bgs["forest"], cursor_at=(1110, 612))


def create_1080(bgs):
    return screen(1920, 1080, bgs["forest1080"], cursor_at=(1080, 600))


def mood_frame(bgs):
    return screen(DW, DH, bgs["island"], wheel=False, mood=True,
                  hint_pairs=[("click", "a mood"), ("hold", "compare with now"), ("esc", "close")])


def paint_frame(bgs):
    return screen(DW, DH, bgs["forest"], painting=True, cursor_at=(1060, 600))


def snow_frame(bgs):
    # Legibility check: the main view over a washed-out, near-white frame standing in for First snow in fog.
    return screen(DW, DH, bgs["island"], cursor_at=(1000, 610), bg_filter="brightness(1.9) contrast(.55) saturate(.25)")


# ------------------------------------------------------------------ sheet

SHEET_CSS = """
.sheet-bg{position:absolute;inset:-60px;background-size:cover;filter:blur(26px) brightness(.5) saturate(.8)}
.sheet{position:relative;padding:40px 56px;display:flex;flex-direction:column;gap:28px}
.sheet-title{font-family:'Cormorant';font-weight:500;font-size:44px;letter-spacing:.06em;color:#fbf6ea}
.sheet-sub{font-family:'Cormorant';font-style:italic;font-size:19px;color:#efe7d6;opacity:.85;margin-top:-22px}
.sheet-h{font-family:'Cormorant';font-weight:600;font-size:13px;letter-spacing:.26em;text-transform:uppercase;color:#fbf6ea;opacity:.85}
.sheet-n{font-family:'Cormorant';font-size:15px;color:#efe7d6;opacity:.85;max-width:380px;line-height:1.3}
.row{display:flex;gap:36px;align-items:flex-start;flex-wrap:wrap}
.stage{position:relative;border-radius:14px;overflow:hidden;background-size:cover}
"""


def _card(title, inner, note="", w=None):
    style = f"width:{w}px;" if w else ""
    return (f'<div style="{style}display:flex;flex-direction:column;gap:10px"><div class="sheet-h">{title}</div>{inner}'
            + (f'<div class="sheet-n">{note}</div>' if note else "") + "</div>")


def stage(bg, w, h, inner, pos="center", filt=""):
    return (f'<div class="stage" style="width:{w}px;height:{h}px">'
            f'<div style="position:absolute;inset:0;background:url(file://{bg}) {pos}/cover;{("filter:" + filt) if filt else ""}"></div>{inner}</div>')


def sheet(bgs):
    names = [g for g, _ in BRUSHES] + ["slot-empty"] + [g for g, _ in MODES] + ["mood", "world", "craft", "photo"] + [g for g, _ in FORMS] + [g for g, _ in SEASONS] + ["rock"]
    cells = "".join(f'<div style="display:flex;flex-direction:column;align-items:center;width:72px;gap:6px"><img class="g-lit" src="{glyph_url(NAME, g)}" style="width:48px;height:48px">'
                    f'<div class="cap" style="font-size:9px;letter-spacing:.16em;opacity:.75">{g.replace("form-","").replace("season-","").replace("slot-empty","future")}</div></div>' for g in names)
    glyph_panel = f'<div style="width:1328px;padding:18px 20px;border-radius:16px;background:rgba(8,18,24,.45);display:flex;flex-wrap:wrap;gap:12px 2px">{cells}</div>'
    snow = "brightness(1.9) contrast(.55) saturate(.25)"

    def st(state, label, filt=""):
        return (f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px">'
                + stage(bgs["island"], 130, 130, slot(65, 58, "water", state, glyph=36, label="Water" if state else None), "60% 72%", filt)
                + f'<div class="sheet-n" style="text-align:center;max-width:130px">{label}</div></div>')
    states = st("", "idle") + st("hov", "hover") + st("held", "in hand") + st("held", "in hand, over snow", snow) + st("", "idle, over snow", snow)
    wisp = "".join(f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px">'
                   + stage(bgs["forest"], 110, 110, undo_slot(55, 55, fr), "20% 60%")
                   + f'<div class="sheet-n" style="text-align:center;max-width:110px">{lbl}</div></div>'
                   for fr, lbl in ((0, "idle: bobs, blinks"), (1, "press: hops, tail whips"), (2, "undone: spins back, sparks")))
    wheel = stage(bgs["forest"], 420, 250, n(210, 0, "") + f'<div style="position:absolute;left:210px;top:0">{top_bar_fragment()}</div>', "40% 20%")
    curs = "".join(stage(bgs["island"], 250, 170, cursor(125, 110, w, h, GLOW["land"], st_, "form-alpine"), "62% 70%")
                   for w, h, st_ in ((130, 52, .2), (230, 92, 1)))
    modes = stage(bgs["forest"], 230, 330, f'<div style="position:absolute;left:-10px;top:165px">{left_column("paint", hover="grab")}</div>', "10% 50%")
    moods = stage(bgs["island"], 680, 250, f'<div style="position:absolute;left:670px;top:130px">{mood_fan_compact()}</div>', "70% 60%")
    drw = stage(bgs["island"], 300, 250, drawer(14, 18), "80% 70%")
    photo = stage(bgs["forest"], 170, 170, f'<div style="position:absolute;left:170px;top:190px">{photo_button()}</div>', "90% 90%")
    scrub = stage(bgs["forest"], 780, 90, f'<div style="position:absolute;left:390px;top:90px">{scrubber()}{hint(LAND_HINT)}</div>', "50% 95%")
    body = (f'<div class="sheet-bg" style="background-image:url(file://{bgs["forest"]})"></div><div class="sheet">'
            '<div class="sheet-title">B2 · Lantern Maker</div><div class="sheet-sub">Lantern\'s light, laid out like Mario Maker 2: parts on top, hands on the left, the world on the right, Photo as the play button.</div>'
            + _card("Glyph set (docs/ui/glyphs/lantern-maker)", glyph_panel)
            + '<div class="row">' + _card("Slot states, with the under-glow plate", f'<div style="display:flex;gap:12px">{states}</div>',
                                          "Every glyph sits on a soft dark under-glow and carries a 1.5 px dark rim before its light glow, so it holds up over bright fog and snow.")
            + _card("Undo wisp", f'<div style="display:flex;gap:12px">{wisp}</div>') + '</div>'
            + '<div class="row">' + _card("Forms wheel under Land", wheel, "Hold Land, or click it again: the forms swing down on an arc. Release over one to pick it.")
            + _card("Cursor: size = ring, strength = lit motes", f'<div style="display:flex;gap:12px">{curs}</div>', "The form in hand floats on the beam.")
            + _card("Hand modes", modes) + '</div>'
            + '<div class="row">' + _card("Mood orbs from the right column", moods) + _card("Customise veil", drw) + _card("Photo, the play button", photo) + '</div>'
            + _card("Season scrubber + hint line", scrub)
            + '</div>')
    return page(body, CSS + SHEET_CSS, None, 1440, 1560)


def top_bar_fragment():
    # Just Land and its wheel, re-centred for the sheet.
    return (f'<div class="plate" style="left:-60px;top:{BAR_Y-40}px;width:120px;height:80px"></div>'
            + slot(0, BAR_Y - 20, "land", "held", glyph=36) + forms_wheel(0, BAR_Y - 20))


def mood_fan_compact():
    out = [slot(-50, -80, "mood", "held", glyph=34)]
    for i, (mid, title, sky, glow, ground, water) in enumerate(MOODS):
        x = -140 - i * 56
        y = -80 + 0.0009 * (x + 360) ** 2 * 0 + (18 if i % 2 else 0) * 0
        sel = mid == "rosewater_dusk"
        out.append(n(x, 0, orb(sky, glow, ground, 56 if sel else 44, sel)))
        if sel:
            out.append(n(x, -44, f'<div class="cap">{title}</div>'))
    out.append(thread([(-50, -80), (-140, 0), (-140 - 8 * 56, 0)], .25))
    return "".join(out)


JOBS = {
    "create": (create_frame, 1440, 900),
    "create-1080": (create_1080, 1920, 1080),
    "mood": (mood_frame, 1440, 900),
    "paint": (paint_frame, 1440, 900),
    "snowtest": (snow_frame, 1440, 900),
    "sheet": (sheet, 1440, None),
}

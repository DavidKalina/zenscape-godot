"""Direction C: Toy Box. Painted wooden tokens in a chunky tray."""
import math
from common import (BRUSHES, FORMS, SEASONS, MOODS, svg_doc, glyph_url, polar, f, page)

NAME = "toy-box"
D = "#4a3829"        # outline, a warm dark brown
C = "#fff6e3"        # cream
SH = "#ead8b6"       # cream shade
TOKEN = {"land": "#d9a764", "water": "#62b0cb", "meadow": "#9ccb66", "forest": "#4f9a67", "path": "#d69570",
         "mood": "#e89bb0", "look": "#f1e4c9", "photo": "#f1e4c9", "craft": "#d8b27f", "world": "#d8b27f"}


def dark(hexcol, k=.72):
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % (int(r * k), int(g * k), int(b * k))


def _o(w=2.6):
    return f'stroke="{D}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"'


def glyph_inner():
    O = _o()
    g = {}
    land = "M6 37C10 25 16 16 24 16C32 16 38 25 42 37Z"
    g["land"] = (f'<path d="{land}" fill="{C}"/><path d="M29 18.5C35 22 38.5 29 40.5 37H31C32 30.5 31 24 29 18.5Z" fill="{SH}"/>'
                 f'<path d="{land}" fill="none" {O}/><path d="M15 29Q17 23 21.5 20.5" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>')
    drop = "M24 6C21 12 13.5 19 13.5 26.5C13.5 32.6 18.2 37.5 24 37.5C29.8 37.5 34.5 32.6 34.5 26.5C34.5 19 27 12 24 6Z"
    g["water"] = (f'<path d="{drop}" fill="{C}"/><path d="M30 18C33 22 34.5 25 34.5 27.5C34.5 32.6 30.5 37 25 37.5C30 33 31.5 25 30 18Z" fill="{SH}"/>'
                  f'<path d="{drop}" fill="none" {O}/><ellipse cx="19.5" cy="27" rx="2.2" ry="3.6" fill="#ffffff"/><path d="M11 42.5H37" fill="none" {O}/>')
    blade = "M24 40C19.5 32 19.5 21 24 10C28.5 21 28.5 32 24 40Z"
    g["meadow"] = "".join(f'<g transform="rotate({a} 24 40) scale(1)"><path d="{blade}" fill="{C}" {O}/></g>' for a in (-36, 36)) + \
        f'<path d="{blade}" fill="{C}" {O}/><path d="M24 36V16" fill="none" stroke="{SH}" stroke-width="2.2" stroke-linecap="round"/><path d="M12 41H36" fill="none" {O}/>'
    tiers = ["M24 17L38 34H10Z", "M24 11L35 26H13Z", "M24 5.5L32 18H16Z"]
    g["forest"] = f'<rect x="20.5" y="33" width="7" height="8" rx="1.5" fill="#b98a5e" {O}/>' + "".join(f'<path d="{t}" fill="{C}" {O}/>' for t in tiers) + \
        f'<path d="M27 28L33 32.5M26 20.5L30.5 24" fill="none" stroke="{SH}" stroke-width="2.2" stroke-linecap="round"/>'
    road = "M11 42C12 34 34 34 33 25C32 17 17 19 21 7"
    g["path"] = (f'<path d="{road}" fill="none" stroke="{D}" stroke-width="11" stroke-linecap="round"/>'
                 f'<path d="{road}" fill="none" stroke="{C}" stroke-width="6" stroke-linecap="round"/>'
                 f'<circle cx="17.5" cy="37" r="1.3" fill="{D}"/><circle cx="29" cy="31.5" r="1.3" fill="{D}"/><circle cx="25" cy="18.5" r="1.3" fill="{D}"/>')
    eye = "M4.5 24Q24 6.5 43.5 24Q24 41.5 4.5 24Z"
    g["look"] = (f'<path d="{eye}" fill="{C}" {O}/><circle cx="24" cy="24" r="8" fill="#6fa5b8" {O}/><circle cx="24" cy="24" r="3.4" fill="{D}"/>'
                 f'<circle cx="27" cy="21" r="1.8" fill="#ffffff"/>')
    body = "M7 18Q7 15 10 15H15.5L18.5 10.5H29.5L32.5 15H38Q41 15 41 18V35Q41 38 38 38H10Q7 38 7 35Z"
    g["photo"] = (f'<path d="{body}" fill="{C}" {O}/><circle cx="24" cy="26" r="7.5" fill="#6fa5b8" {O}/>'
                  f'<circle cx="21.5" cy="23.5" r="2" fill="#ffffff"/><rect x="33" y="18.5" width="5" height="3.2" rx="1.2" fill="#f2c46b" stroke="{D}" stroke-width="1.8"/>')
    cloud = "M12 38Q6.5 38 6.5 33Q6.5 28.2 11.5 28Q12.6 21.5 19.5 21.5Q25.5 21.5 27.6 26.4Q29.2 25 31.8 25Q37.2 25 37.8 30.2Q42 30.8 42 34.2Q42 38 37.5 38Z"
    rays = "".join(f'<path d="M{f(polar(31,16,11,a)[0])} {f(polar(31,16,11,a)[1])}L{f(polar(31,16,14.5,a)[0])} {f(polar(31,16,14.5,a)[1])}" {O}/>' for a in (-150, -110, -70, -30, 10))
    g["mood"] = f'{rays}<circle cx="31" cy="16" r="8" fill="#f6c35b" {O}/><path d="{cloud}" fill="{C}" {O}/><path d="M13 33.5Q15 30.5 18.5 31" fill="none" stroke="{SH}" stroke-width="2.2" stroke-linecap="round"/>'
    g["craft"] = (f'<g transform="rotate(-40 24 24)"><rect x="21.2" y="17" width="5.6" height="26" rx="2.6" fill="#c99a68" {O}/>'
                  f'<path d="M12 9.5H33Q37 9.5 37 13.5V16Q37 19.5 33 19.5H12Q10 19.5 10 17.5V11.5Q10 9.5 12 9.5Z" fill="#a9b6bc" {O}/>'
                  f'<path d="M14 12.5H30" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/></g>')
    isl = "M13 25Q15 18.5 21 20Q24.5 15.5 29.5 19Q35 19.5 34.5 25Q31 30 24.5 29Q17.5 30.5 13 25Z"
    g["world"] = (f'<circle cx="24" cy="24" r="17" fill="#7fc0d4" {O}/><path d="{isl}" fill="#9ccc6e" stroke="{D}" stroke-width="2.2" stroke-linejoin="round"/>'
                  f'<path d="M12 15Q15.5 10.5 21 9.5" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>'
                  f'<path d="M24 22.5V18.5" fill="none" stroke="{D}" stroke-width="2"/><circle cx="24" cy="17.5" r="2.6" fill="#4f9a67" stroke="{D}" stroke-width="1.8"/>')
    stone = "M8 36L12.5 23.5L21 16.5L32 17.5L39.5 26.5L41 36Z"
    g["rock"] = (f'<path d="{stone}" fill="#b8b3a8"/><path d="M21 16.5L24.5 26L12.5 23.5Z" fill="#d6d2c8"/><path d="M24.5 26L39.5 26.5L41 36L27 36Z" fill="#9c978c"/>'
                 f'<path d="{stone}" fill="none" {O}/>')
    base = f'<ellipse cx="24" cy="38.5" rx="20" ry="5.5" fill="#8fbf63" {_o(2.2)}/>'
    hill = "M8.5 38C11 27.5 17 21 24 21C31 21 37 27.5 39.5 38Z"
    g["form-hill"] = base + f'<path d="{hill}" fill="#a6d474" {O}/><path d="M16 30Q18.5 25.5 22.5 24" fill="none" stroke="#d4efb1" stroke-width="2.4" stroke-linecap="round"/>'
    peaks = "M6 38L16 18.5L21 25L28.5 9.5L42 38Z"
    g["form-alpine"] = (base + f'<path d="{peaks}" fill="#a9a8b8" {O}/><path d="M28.5 9.5L35.2 23.5L31.5 21.5L28.5 24L25.5 21L23.4 20.3Z" fill="#ffffff" {_o(2)}/>'
                        f'<path d="M16 18.5L19.8 23.5L17 22.8L14.2 24.3L12.8 24.6Z" fill="#ffffff" {_o(2)}/>')
    ridge = "M4.5 38L11 28L15 30.5L20.5 21L25 25.5L30.5 16.5L35 23L39 21L43.5 38Z"
    g["form-ridge"] = base + f'<path d="{ridge}" fill="#8faa86" {O}/><path d="M30.5 16.5L32 28M20.5 21L21.5 30" fill="none" stroke="#6f8a68" stroke-width="2" stroke-linecap="round"/>'
    mesa = "M6 38L12.5 20H35.5L42 38Z"
    g["form-mesa"] = (base + f'<path d="{mesa}" fill="#d38b5b"/><path d="M11 24.5H37L38.5 29H9.5Z" fill="#eaa877"/><path d="M8 33.5H40L41 36H7Z" fill="#b8704a"/>'
                      f'<path d="{mesa}" fill="none" {O}/>')
    cone = "M5 38L19 17H29L43 38Z"
    g["form-volcano"] = (base + f'<path d="{cone}" fill="#7d6b66" {O}/><ellipse cx="24" cy="17" rx="5" ry="2" fill="#f08a3c" stroke="{D}" stroke-width="2"/>'
                         f'<path d="M22 19Q20.5 25 21.8 29.5" fill="none" stroke="#f08a3c" stroke-width="2.6" stroke-linecap="round"/>'
                         f'<circle cx="22" cy="10" r="3.6" fill="#eeeae4" stroke="{D}" stroke-width="2"/><circle cx="27" cy="7" r="3" fill="#eeeae4" stroke="{D}" stroke-width="2"/>')
    petals = "".join(f'<circle cx="{f(polar(24,24,7,a)[0])}" cy="{f(polar(24,24,7,a)[1])}" r="6" fill="#f6b8c8" {O}/>' for a in range(-90, 270, 72))
    g["season-spring"] = petals + f'<circle cx="24" cy="24" r="4" fill="#f6d36b" {O}/>'
    rays = "".join(f'<rect x="21.8" y="3.5" width="4.4" height="8" rx="2.2" fill="#f6c35b" {_o(2)} transform="rotate({a} 24 24)"/>' for a in range(0, 360, 45))
    g["season-summer"] = rays + f'<circle cx="24" cy="24" r="9.5" fill="#f6c35b" {O}/><circle cx="21" cy="21" r="2.2" fill="#fff0b8"/>'
    leaf = "M24 42L24 36M24 36C14 34 8 26 10 14L16 17L18 8L24 13L30 8L32 17L38 14C40 26 34 34 24 36Z"
    g["season-autumn"] = f'<path d="{leaf}" fill="#e8894a" {O}/><path d="M24 35V17M24 28L17 22M24 24L31 19" fill="none" stroke="#b85f2c" stroke-width="2" stroke-linecap="round"/>'
    arms = "".join(f'M24 24L{f(polar(24,24,16,a)[0])} {f(polar(24,24,16,a)[1])}' for a in range(-90, 270, 60))
    ticks = "".join(f'M{f(polar(*polar(24,24,10,a),5,a-135)[0])} {f(polar(*polar(24,24,10,a),5,a-135)[1])}L{f(polar(24,24,10,a)[0])} {f(polar(24,24,10,a)[1])}L{f(polar(*polar(24,24,10,a),5,a+135)[0])} {f(polar(*polar(24,24,10,a),5,a+135)[1])}' for a in range(-90, 270, 60))
    g["season-winter"] = (f'<path d="{arms}{ticks}" fill="none" stroke="{D}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'
                          f'<path d="{arms}{ticks}" fill="none" stroke="#e4f3fa" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
    return g


def glyphs():
    out = {k: svg_doc(v) for k, v in glyph_inner().items()}
    # Token face (tint in Godot via modulate) and its side, as separate pieces.
    out["token-face"] = svg_doc(f'<circle cx="24" cy="22" r="20" fill="#ffffff" {_o(2.4)}/><path d="M11 15Q15 8.5 22 7.5" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-opacity=".6"/>')
    out["token-side"] = svg_doc(f'<path d="M4 22V26A20 20 0 0 0 44 26V22" fill="#ffffff" {_o(2.4)}/>')
    return out


WOOD = ("repeating-linear-gradient(4deg,rgba(120,78,36,.07) 0 2px,rgba(255,255,255,.05) 2px 5px,rgba(120,78,36,.04) 5px 9px),"
        "linear-gradient(180deg,#e6c493,#d2a870)")
CSS = f"""
.fr{{font-family:'Fredoka';font-weight:600;color:{D}}}
.tray{{position:relative;background:{WOOD};border:2.6px solid {D};border-radius:32px;
  box-shadow:0 7px 0 #a8794a,0 7px 0 2.6px {D},0 16px 26px rgba(24,16,8,.45),inset 0 3px 0 rgba(255,255,255,.4),inset 0 -4px 8px rgba(110,70,30,.22)}}
.tok{{position:relative;border-radius:50%;border:2.6px solid {D};display:flex;align-items:center;justify-content:center}}
.pill{{position:absolute;left:50%;transform:translateX(-50%);background:{C};border:2.4px solid {D};border-radius:14px;padding:0 10px;
  font-family:'Fredoka';font-weight:600;font-size:14px;line-height:22px;color:{D};white-space:nowrap;box-shadow:0 3px 0 {D}}}
.well{{border-radius:50%;background:radial-gradient(circle at 50% 40%,#b58a58,#9d7446);box-shadow:inset 0 4px 6px rgba(60,36,14,.55),0 1px 0 rgba(255,255,255,.45);border:2.2px solid {D}}}
.peg{{width:12px;height:12px;border-radius:50%;border:2px solid {D}}}
.hole{{width:12px;height:12px;border-radius:50%;background:#8e6538;box-shadow:inset 0 2px 3px rgba(40,24,8,.7);border:1.5px solid rgba(74,56,41,.6)}}
.dowel{{width:8px;height:52px;border-radius:5px;background:linear-gradient(90deg,#b98a57,#e4c18e,#b98a57);border:2px solid {D};margin:0 10px;align-self:center}}
.tile{{position:relative;width:58px;height:58px;border-radius:16px;background:{C};border:2.6px solid {D};display:flex;align-items:center;justify-content:center}}
.bubble{{position:absolute;background:{C};border:2.6px solid {D};border-radius:18px;padding:6px 14px;box-shadow:0 4px 0 {D},0 10px 16px rgba(24,16,8,.35);
  font-family:'Fredoka';font-weight:500;font-size:15px;color:{D};white-space:nowrap;display:flex;align-items:center;gap:6px}}
.kc{{display:inline-block;background:#fffdf6;border:2px solid {D};border-radius:7px;padding:0 6px;font-weight:600;font-size:12px;line-height:17px;box-shadow:0 2px 0 {D};margin-right:2px}}
"""


def token(gid, size=60, state="", label=None, colour=None, glyph_size=None, lift=None):
    colour = colour or TOKEN.get(gid, C)
    side = 5 if not state == "sel" else 9
    lift = lift if lift is not None else (-10 if state == "sel" else (-4 if state == "hov" else 0))
    gs = glyph_size or int(size * .62)
    face = (f'background:radial-gradient(circle at 34% 28%,rgba(255,255,255,.45),rgba(255,255,255,0) 42%),{colour};'
            f'box-shadow:0 {side}px 0 {dark(colour)},0 {side}px 0 2.6px {D}{",0 0 0 5px #fff6e3,0 0 0 7.6px " + D if state == "sel" else ""};')
    rot = "rotate(-6deg)" if state == "hov" else ""
    out = (f'<div style="position:relative;width:{size}px;height:{size + 12}px;display:flex;justify-content:center">'
           f'<div style="position:absolute;bottom:0;left:50%;width:{size*.9}px;height:12px;transform:translateX(-50%);border-radius:50%;background:rgba(60,36,14,{.35 if state == "sel" else 0})"></div>'
           f'<div class="tok" style="width:{size}px;height:{size}px;{face}transform:translateY({lift}px) {rot}">'
           f'<img src="{glyph_url(NAME, gid)}" style="width:{gs}px;height:{gs}px"></div>')
    if label:
        out += f'<div class="pill" style="top:{size + 10 + lift}px">{label}</div>'
    return out + "</div>"


def size_strength(colour, size=.55, strength=.6):
    d = 14 + 30 * size
    pegs = "".join(f'<div class="peg" style="background:{colour}"></div>' if i < round(strength * 5) else '<div class="hole"></div>' for i in range(5))
    return (f'<div style="display:flex;align-items:center;gap:8px">'
            f'<div class="well" style="width:56px;height:56px;display:flex;align-items:center;justify-content:center">'
            f'<div style="width:{d}px;height:{d}px;border-radius:50%;background:radial-gradient(circle at 35% 30%,rgba(255,255,255,.5),rgba(255,255,255,0) 45%),{colour};border:2.2px solid {D}"></div></div>'
            f'<div style="display:flex;flex-direction:column-reverse;gap:3px">{pegs}</div></div>')


def palette(held="land", hover=None, mood_open=False):
    items = []
    for gid, title in BRUSHES:
        st = "sel" if gid == held else ("hov" if gid == hover else "")
        items.append(token(gid, 60, st, title if st else None))
    items.append('<div class="dowel"></div>')
    items.append(size_strength(TOKEN[held]))
    items.append('<div class="dowel"></div>')
    for gid, title in (("mood", "Mood"), ("look", "Look"), ("photo", "Photo")):
        st = "sel" if (gid == "mood" and mood_open) else ("hov" if gid == hover else "")
        items.append(token(gid, 50, st, title if st else None))
    return f'<div class="tray" style="display:flex;align-items:flex-end;gap:12px;padding:14px 26px 12px">{"".join(items)}</div>'


def shelf(inner, notch_left=None):
    notch = ""
    if notch_left is not None:
        notch = (f'<div style="position:absolute;left:{notch_left}px;bottom:-15px;width:24px;height:16px;background:#d2a870;'
                 f'border-left:2.6px solid {D};border-right:2.6px solid {D}"></div>')
    return f'<div class="tray" style="border-radius:26px;display:flex;gap:12px;align-items:flex-end;padding:12px 18px 14px">{inner}{notch}</div>'


def forms_shelf(selected="form-alpine"):
    items = []
    for gid, title in FORMS:
        sel = gid == selected
        lift = "-8px" if sel else "0"
        side = 8 if sel else 4
        badge = (f'<div style="position:absolute;right:-8px;top:-8px;width:22px;height:22px;border-radius:50%;background:#f6c35b;border:2.4px solid {D};'
                 f'display:flex;align-items:center;justify-content:center"><svg width="12" height="12" viewBox="0 0 12 12"><path d="M2.5 6.5L5 9L9.5 3.5" fill="none" stroke="{D}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg></div>') if sel else ""
        pill = f'<div class="pill" style="top:66px;font-size:13px">{title}</div>' if sel else ""
        items.append(f'<div style="position:relative;height:66px"><div class="tile" style="transform:translateY({lift});box-shadow:0 {side}px 0 #d9c29c,0 {side}px 0 2.6px {D}">'
                     f'<img src="{glyph_url(NAME, gid)}" style="width:46px;height:46px">{badge}</div>{pill}</div>')
    return shelf("".join(items), 40)


def top_right():
    out = []
    for right, gid, title in ((100, "craft", "Craft"), (28, "world", "World")):
        out.append(f'<div class="abs" style="right:{right}px;top:22px">{token(gid, 58, "", None, "#d8b27f", 38)}'
                   f'<div class="pill" style="top:74px;font-size:13px">{title}</div></div>')
    return "".join(out)


def cursor(cx, cy, w=240, h=96, gid="form-alpine", colour=TOKEN["land"], bubble=True):
    rx, ry = w / 2, h / 2
    dashes = ""
    for i in range(24):
        a = 2 * math.pi * (i + .5) / 24
        x1, y1 = rx + (rx - 1) * math.cos(a), ry + (ry - 1) * math.sin(a)
        dashes += f'<circle cx="{f(x1)}" cy="{f(y1)}" r="1.4" fill="{D}"/>'
    ring = (f'<ellipse cx="{rx}" cy="{ry}" rx="{rx-1}" ry="{ry-1}" fill="{colour}" fill-opacity=".18" stroke="{D}" stroke-width="9"/>'
            f'<ellipse cx="{rx}" cy="{ry}" rx="{rx-1}" ry="{ry-1}" fill="none" stroke="{C}" stroke-width="5"/>{dashes}'
            f'<ellipse cx="{rx}" cy="{ry}" rx="12" ry="5" fill="#3c2a18" fill-opacity=".35"/>')
    marker = (f'<div class="abs" style="left:{rx-22}px;top:{ry-92}px;width:44px">'
              f'<div class="tok" style="width:44px;height:44px;background:radial-gradient(circle at 34% 28%,rgba(255,255,255,.5),rgba(255,255,255,0) 42%),{colour};'
              f'box-shadow:0 4px 0 {dark(colour)},0 4px 0 2.6px {D}"><img src="{glyph_url(NAME, gid)}" style="width:32px;height:32px"></div>'
              f'<div style="margin:3px auto 0;width:5px;height:38px;border-radius:3px;background:{C};border:2px solid {D}"></div></div>')
    bub = ""
    if bubble:
        bub = (f'<div class="bubble" style="right:{rx + 34}px;top:{ry - 104}px"><span class="kc">drag</span> raise land '
               f'<span style="opacity:.4">·</span> <span class="kc">shift</span> hollow</div>'
               f'<svg class="abs" style="left:{rx - 38}px;top:{ry - 98}px;overflow:visible" width="16" height="20"><path d="M0 2L14 9L0 16" fill="{C}" stroke="{D}" stroke-width="2.6" stroke-linejoin="round"/><path d="M-1.5 1V17" stroke="{C}" stroke-width="3.4"/></svg>')
    return (f'<div class="abs" style="left:{cx-rx}px;top:{cy-ry}px;width:{w}px;height:{h}px">'
            f'<svg width="{w}" height="{h}" style="overflow:visible;position:absolute;filter:drop-shadow(0 3px 3px rgba(24,16,8,.3))">{ring}</svg>{marker}{bub}</div>')


def candy(sky, glow, ground, water, size=50, sel=False, i=0):
    s = size
    svg = (f'<svg width="{s}" height="{s}" viewBox="0 0 50 50"><defs><clipPath id="cd{i}{int(sel)}"><circle cx="25" cy="25" r="22"/></clipPath></defs>'
           f'<g clip-path="url(#cd{i}{int(sel)})"><rect width="50" height="50" fill="#{sky}"/><circle cx="33" cy="18" r="6.5" fill="#{glow}" stroke="{D}" stroke-width="1.8"/>'
           f'<path d="M0 32Q12 22 26 29T50 27V50H0Z" fill="#{ground}" stroke="{D}" stroke-width="2"/><path d="M12 41Q25 37 38 41Q25 45 12 41Z" fill="#{water}"/></g>'
           f'<circle cx="25" cy="25" r="22" fill="none" stroke="{D}" stroke-width="2.6"/><path d="M11 17Q14 10.5 21 8.5" fill="none" stroke="#ffffff" stroke-opacity=".7" stroke-width="3" stroke-linecap="round"/></svg>')
    lift = -8 if sel else 0
    side = 8 if sel else 4
    return (f'<div style="position:relative;width:{s}px;height:{s + 8}px"><div style="width:{s}px;height:{s}px;border-radius:50%;transform:translateY({lift}px);'
            f'box-shadow:0 {side}px 0 {dark("#" + ground)},0 {side}px 0 2.6px {D}{",0 0 0 4px #fff6e3,0 0 0 6.6px " + D if sel else ""}">{svg}</div></div>')


def mood_shelf(selected="rosewater_dusk"):
    items = []
    for i, (mid, title, sky, glow, ground, water) in enumerate(MOODS):
        sel = mid == selected
        pill = f'<div class="pill" style="top:56px;font-size:13px">{title}</div>' if sel else ""
        items.append(f'<div style="position:relative">{candy(sky, glow, ground, water, 50, sel, i)}{pill}</div>')
    return shelf("".join(items))


def drawer(season="season-autumn"):
    seasons = ""
    for gid, title in SEASONS:
        sel = gid == season
        seasons += (f'<div style="position:relative;display:flex;flex-direction:column;align-items:center;width:52px">'
                    f'{token(gid, 44, "sel" if sel else "", None, C if not sel else "#fbe1c4", 34, -6 if sel else 0)}'
                    f'<div class="fr" style="font-size:11px;margin-top:2px;opacity:{1 if sel else .7}">{title}</div></div>')
    pots = ""
    for gid, title, colour in (("meadow", "Grass", "#80917b"), ("rock", "Rock", "#8a8190"), ("water", "Water", "#9a91b1")):
        pots += (f'<div style="display:flex;flex-direction:column;align-items:center;width:62px">'
                 f'<svg width="48" height="52" viewBox="0 0 48 52"><rect x="10" y="4" width="28" height="8" rx="3" fill="#c9b8a0" stroke="{D}" stroke-width="2.4"/>'
                 f'<path d="M8 14Q8 11 11 11H37Q40 11 40 14V44Q40 48 36 48H12Q8 48 8 44Z" fill="#fffdf6" stroke="{D}" stroke-width="2.6"/>'
                 f'<path d="M10.5 22H37.5V44Q37.5 45.8 35.5 45.8H12.5Q10.5 45.8 10.5 44Z" fill="{colour}"/>'
                 f'<path d="M13 16V40" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-opacity=".8"/></svg>'
                 f'<div class="fr" style="font-size:11px;display:flex;align-items:center;gap:2px"><img src="{glyph_url(NAME, gid)}" style="width:15px;height:15px">{title}</div></div>')
    knob = f'<div style="position:absolute;left:50%;bottom:-13px;transform:translateX(-50%);width:34px;height:14px;border-radius:0 0 10px 10px;background:#b98a57;border:2.4px solid {D};border-top:none"></div>'
    return (f'<div class="tray" style="border-radius:22px;width:290px;padding:12px 14px 16px">'
            f'<div style="display:flex;justify-content:space-between;padding:0 4px">{seasons}</div>'
            f'<div style="height:2.4px;background:{D};opacity:.25;margin:8px 4px 10px;border-radius:2px"></div>'
            f'<div style="display:flex;justify-content:space-around">{pots}</div>{knob}</div>')


def create_frame(bgs):
    body = (top_right() + cursor(1110, 616)
            + f'<div class="abs" style="left:330px;top:652px">{forms_shelf()}</div>'
            + f'<div class="abs" style="left:0;right:0;top:760px;display:flex;justify-content:center">{palette()}</div>')
    return page(body, CSS, bgs["forest"])


def mood_frame(bgs):
    body = (top_right()
            + f'<div class="abs" style="left:318px;top:666px">{mood_shelf()}</div>'
            + f'<div class="abs" style="left:1004px;top:562px">{drawer()}</div>'
            + f'<div class="abs" style="left:0;right:0;top:760px;display:flex;justify-content:center">{palette(mood_open=True)}</div>'
            + f'<div class="bubble" style="left:470px;top:600px"><span class="kc">click</span> a mood <span style="opacity:.4">·</span> <span class="kc">hold</span> compare with now</div>')
    return page(body, CSS, bgs["island"])


SHEET_CSS = """
.sheet-bg{position:absolute;inset:-60px;background-size:cover;filter:blur(26px) brightness(.6) saturate(.85)}
.sheet{position:relative;padding:40px 56px;display:flex;flex-direction:column;gap:30px}
.sheet-title{font-family:'Fredoka';font-weight:600;font-size:44px;color:#fff6e3;text-shadow:0 3px 0 #4a3829}
.sheet-sub{font-family:'Fredoka';font-weight:400;font-size:18px;color:#f3e6cc;margin-top:-22px}
.sheet-h{font-family:'Fredoka';font-weight:600;font-size:16px;color:#fff6e3}
.sheet-n{font-family:'Fredoka';font-weight:400;font-size:13.5px;color:#f3e6cc;opacity:.9;max-width:360px;line-height:1.35}
.row{display:flex;gap:40px;align-items:flex-start;flex-wrap:wrap}
.stage{position:relative;border-radius:18px;overflow:hidden;background-size:cover;border:2.6px solid #4a3829}
"""


def _card(title, inner, note="", w=None):
    style = f"width:{w}px;" if w else ""
    return (f'<div style="{style}display:flex;flex-direction:column;gap:10px"><div class="sheet-h">{title}</div>{inner}'
            + (f'<div class="sheet-n">{note}</div>' if note else "") + "</div>")


def sheet(bgs):
    names = [g for g, _ in BRUSHES] + ["mood", "look", "photo", "craft", "world"] + [g for g, _ in FORMS] + [g for g, _ in SEASONS] + ["rock"]
    cells = "".join(f'<div style="display:flex;flex-direction:column;align-items:center;width:76px;gap:4px"><img src="{glyph_url(NAME, n)}" style="width:56px;height:56px">'
                    f'<div class="fr" style="font-size:11px;opacity:.75">{n.replace("form-","").replace("season-","")}</div></div>' for n in names)
    glyph_panel = f'<div class="tray" style="width:1320px;padding:18px 22px;display:flex;flex-wrap:wrap;gap:12px 6px">{cells}</div>'
    def st(state, label):
        return (f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px"><div class="tray" style="width:120px;height:120px;display:flex;align-items:center;justify-content:center;padding-bottom:12px">'
                f'{token("water", 60, state, "Water" if state else None)}</div><div class="sheet-n" style="text-align:center;max-width:140px">{label}</div></div>')
    states = st("", "idle: resting in the tray") + st("hov", "hover: hops 4px, tips 6°") + st("sel", "selected: pops up with a squash, cream collar, name pill")
    ss = "".join(f'<div style="display:flex;flex-direction:column;align-items:center;gap:6px"><div class="tray" style="padding:10px 14px">{size_strength(TOKEN["water"], s, t)}</div><div class="sheet-n">{lbl}</div></div>'
                 for s, t, lbl in ((.1, .2, "small, soft"), (.55, .6, "medium"), (1, 1, "wide, strong")))
    painting = (f'<div class="stage" style="width:300px;height:150px;background-image:url(file://{bgs["forest"]});background-position:60% 90%">'
                f'<div class="abs" style="left:74px;top:70px"><div class="tray" style="display:flex;gap:10px;align-items:flex-end;padding:10px 16px 20px;border-radius:26px 26px 0 0">'
                f'{token("water", 52, "sel")}{size_strength(TOKEN["water"])}</div></div></div>')
    curs = "".join(f'<div class="stage" style="width:300px;height:190px;background-image:url(file://{bgs["island"]});background-position:62% 70%">{cursor(150, 130, w, h, "water", TOKEN["water"], False)}</div>'
                   for w, h in ((140, 56), (250, 100)))
    body = (f'<div class="sheet-bg" style="background-image:url(file://{bgs["forest"]})"></div><div class="sheet">'
            '<div class="sheet-title">C · Toy Box</div><div class="sheet-sub">Painted wooden tokens in a chunky tray. Every tool is a thing you can pick up.</div>'
            + _card("Glyph set (docs/ui/glyphs/toy-box)", glyph_panel)
            + '<div class="row">' + _card("Token states", f'<div style="display:flex;gap:16px">{states}</div>')
            + _card("Size well + strength pegs", f'<div style="display:flex;gap:16px">{ss}</div>', "The painted dot in the well grows with [ ]; pegs fill bottom-up with Shift [ ], each one clicking in.")
            + _card("While painting", painting, "The tray sinks below the screen edge; the held token and its well ride up on a stub.", 300) + '</div>'
            + '<div class="row">' + _card("Land forms shelf", forms_shelf())
            + _card("Cursor: pin marker on a stitched ring", f'<div style="display:flex;gap:16px">{curs}</div>', "The marker bobs; when a stroke starts it squashes down into the ground and the ring's stitches spin.") + '</div>'
            + '<div class="row">' + _card("Mood candies", mood_shelf()) + _card("Customise drawer", drawer()) + '</div>'
            + _card("Hint bubble (rides beside the cursor)", '<div style="position:relative;height:50px;width:520px"><div class="bubble" style="left:0;top:0"><span class="kc">drag</span> raise land <span style="opacity:.4">·</span> <span class="kc">shift</span> hollow <span style="opacity:.4">·</span> <span class="kc">[ ]</span> size <span style="opacity:.4">·</span> <span class="kc">tab</span> look</div></div>')
            + '</div>')
    return page(body, CSS + SHEET_CSS, None, 1440, 1330)

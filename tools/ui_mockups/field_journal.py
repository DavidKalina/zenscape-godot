"""Direction A: Field Journal. Ink glyphs on torn watercolour paper."""
import math
from common import (BRUSHES, FORMS, SEASONS, MOODS, svg_doc, glyph_url, blob_path, deckle_polygon, polar, f, page)

NAME = "field-journal"
INK = "#3a2e24"
PAPER = "#f2e8d3"
LIGHT = "#f6eedc"
WASH = {"land": "#c99a5b", "water": "#6fa7b3", "meadow": "#9fbf6c", "forest": "#5d8f6a", "path": "#c7a07c",
        "mood": "#c98fa6", "look": "#98a9ae", "photo": "#98a9ae", "form": "#c99a5b", "season": "#d39a5f"}


def _g(inner, colour=INK, width=2.2):
    return svg_doc(f'<g fill="none" stroke="{colour}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round">\n{inner}\n</g>')


def _fill(colour=INK):
    return f'fill="{colour}" stroke="none"'


def glyph_inner(c=INK):
    F = _fill(c)
    g = {}
    g["land"] = f'''<path d="M5.5 36.5C11 35.5 14.5 16.5 23.5 15C32 13.8 36.5 30.5 42.5 36"/>
<path d="M4 38.2Q16 37 24 38T44 38.4"/>
<path d="M17 22Q19.5 18 23 17.2" stroke-width="1.3"/>
<g stroke-width="1.4"><path d="M29.5 21.5l2.2 5.2"/><path d="M32.5 24.5l2.4 5"/><path d="M35.5 28.5l2 4.2"/><path d="M10.8 36.2l-1-3"/><path d="M12.4 36.2l.5-3.4"/></g>'''
    g["water"] = f'''<path d="M24 6.5C22 11 15.2 18.5 15.2 25C15.2 30.2 19.2 33.8 24.2 33.8C29 33.8 33 30.2 32.8 25C32.6 18.6 26 11.4 24 6.5Z"/>
<path d="M19.6 25.8Q19.9 29.2 23.2 30.4" stroke-width="1.4"/>
<path d="M9 40.5Q16.5 37.2 24 39.6Q31.5 42 39 38.8"/>
<path d="M15.5 44.6Q20 43 24.5 44.2Q29 45.3 33 43.8" stroke-width="1.5"/>'''
    g["meadow"] = f'''<path d="M24 40.5Q22.6 27 17.2 15.5"/><path d="M24.6 40.5Q26 28.5 31 17.5"/>
<path d="M22.5 40.5Q17 32.5 9.8 28"/><path d="M26.4 40.5Q31.8 33.5 38.6 30.6"/><path d="M24.3 40.5Q24.6 31 26.4 23"/>
<circle cx="31.3" cy="15.4" r="2.4" {F}/><circle cx="16.9" cy="13.4" r="1.6" {F}/>
<path d="M8 41.5Q24 40 40.5 42"/>'''
    g["forest"] = f'''<path d="M24 5.5L16.5 16.8L20.4 16.6L13.2 26.4L18 26.2L9.8 35.4L38.4 35.6L30.2 26.2L35 26.4L27.8 16.6L31.6 16.8Z"/>
<path d="M24 35.6V42.2"/><path d="M20 30.5l3-3M26.5 21.5l2-2" stroke-width="1.3"/>
<path d="M15 42.8Q24 41.8 33.5 43"/>'''
    g["path"] = f'''<path d="M8.5 44C13 37 28.5 35.5 27 28.5C25.8 22.8 17.5 20.5 21 13.5C22.6 10.4 25 8.8 27 7.5"/>
<path d="M21.5 44C25 38.5 38.5 35.2 34.5 27C31.6 21.2 24.8 20 26.8 13.4C27.5 11 28.6 9.6 29.8 8.6" stroke-width="1.8"/>
<ellipse cx="17.6" cy="40.2" rx="1.7" ry="1" {F}/><ellipse cx="29.4" cy="32.2" rx="1.4" ry=".9" {F}/><ellipse cx="23.6" cy="20.4" rx="1.2" ry=".8" {F}/><ellipse cx="27.4" cy="11.6" rx=".9" ry=".6" {F}/>'''
    g["look"] = f'''<path d="M4.8 24.5Q14 13 24 13Q34 13 43.2 24.5Q34 35.5 24 35.5Q14 35.5 4.8 24.5Z"/>
<circle cx="24" cy="24.3" r="6.6"/><circle cx="24" cy="24.3" r="2.6" {F}/>
<path d="M13 13.5l-2-3.4M24 10V6M35 13.5l2-3.4" stroke-width="1.5"/>'''
    g["photo"] = f'''<path d="M7.5 17.5Q7.5 15.6 9.5 15.6H15.6L18.6 11.4H29.4L32.4 15.6H38.5Q40.5 15.6 40.5 17.6V35Q40.5 37 38.5 37H9.5Q7.5 37 7.5 35Z"/>
<circle cx="24" cy="26.2" r="6.8"/><path d="M20.4 24.4Q21.4 22.4 23.6 22" stroke-width="1.3"/>
<circle cx="35.4" cy="20.4" r="1.4" {F}/>'''
    rays = "".join(
        f'<path d="M{f(polar(22,25,12.5,a)[0])} {f(polar(22,25,12.5,a)[1])}L{f(polar(22,25,16.5,a)[0])} {f(polar(22,25,16.5,a)[1])}"/>'
        for a in (110, 145, 180, 215, 250))
    g["mood"] = f'''<circle cx="22" cy="25" r="9"/><path d="M22 16A9 9 0 0 1 22 34Z" {F} fill-opacity=".9"/>
<g stroke-width="1.6">{rays}</g><circle cx="36.5" cy="12.5" r="1.3" {F}/><circle cx="40" cy="20" r=".9" {F}/><circle cx="38" cy="33.5" r="1.1" {F}/>'''
    g["craft"] = f'''<g transform="rotate(-38 24 24)"><path d="M22.6 18.6H25.4V41.6Q24 43 22.6 41.6Z"/>
<path d="M13 10.5H31Q34 10.5 35 14.5Q34 18.5 31 18.5H13Q11.8 18.5 11.8 17.3V11.7Q11.8 10.5 13 10.5Z"/></g>
<path d="M36 30l1.6 3.4M40.5 27.5l-3.2 1.4M39.8 34.6l-1.8-1.2" stroke-width="1.5"/>'''
    g["world"] = f'''<circle cx="24" cy="24" r="16"/>
<path d="M13.5 24.5Q15.5 19.5 20.5 20.5Q24 17 28.5 20Q33.5 20.5 33 25Q30 28.6 24.5 27.8Q18 29.2 13.5 24.5Z" {F} fill-opacity=".85"/>
<path d="M13 33q3-1.6 6 0t6 0M27 12.5q2.5-1.2 5 0" stroke-width="1.3"/>'''
    g["rock"] = f'''<path d="M8 35.5L12.5 23L21 15.5L31.5 17L38.8 26L40.5 35.8Z"/>
<path d="M21 15.5L24.5 26L12.5 23M24.5 26L31.5 17M24.5 26L27 35.8" stroke-width="1.4"/>
<path d="M5 37.8Q24 36.8 43.5 38.2"/>'''
    g["form-hill"] = f'''<path d="M5 37C12 35 15 21.5 24 21C33 20.6 36 35 43 37"/>
<path d="M4 38.5Q24 37.4 44 38.8"/><g stroke-width="1.4"><path d="M30.5 26l2 4.4"/><path d="M33.6 29.5l1.8 3.6"/></g>'''
    g["form-alpine"] = f'''<path d="M4.5 38L15.5 17.5L20.5 24.5L28 10.5L43.5 38"/>
<path d="M12.3 23.5L14.6 24.8L16.6 22.4L18.9 24.4" stroke-width="1.4"/><path d="M24.2 17.8L26.4 19.4L28.4 16.8L30.6 19.3L32.3 18.2" stroke-width="1.4"/>
<g stroke-width="1.3"><path d="M33 27l2.4 4.5"/><path d="M36.2 29.6l2 3.6"/></g><path d="M3.5 39.5Q24 38.5 44.5 39.8"/>'''
    g["form-ridge"] = f'''<path d="M3.5 37L10.5 29L14 31L20 22L24 25.5L29.5 18.5L34 23.5L38 21.5L44.5 37"/>
<g stroke-width="1.3"><path d="M20 22l1.4 7"/><path d="M29.5 18.5l1.6 8"/><path d="M38 21.5l.6 6"/></g><path d="M3 38.6Q24 37.6 45 38.8"/>'''
    g["form-mesa"] = f'''<path d="M4 38L10.5 36.5L14 21H34L37.5 36.5L44 38"/>
<path d="M13.2 25.8Q24 26.8 34.8 25.8M12 31.2Q24 32.2 36.2 31.2" stroke-width="1.3"/>
<path d="M14 21Q24 19.6 34 21" stroke-width="1.3"/>'''
    g["form-volcano"] = f'''<path d="M4 38L18.5 16.5Q24 19 29.5 16.5L44 38"/><path d="M18.5 16.5Q24 14.5 29.5 16.5"/>
<path d="M24 13C21 10.5 26 8.5 23.5 5.5M27.8 12.6C27 10.5 30 9.5 29 7.5" stroke-width="1.5"/>
<path d="M22 20Q20.5 26 21.5 30.5M26.5 20.5Q28.5 24 28 27" stroke-width="1.3"/><path d="M3 39.5Q24 38.5 45 39.8"/>'''
    petals = "".join(
        f'<circle cx="{f(polar(24,23,6.6,a)[0])}" cy="{f(polar(24,23,6.6,a)[1])}" r="4.6"/>' for a in range(-90, 270, 72))
    g["season-spring"] = f'''{petals}<circle cx="24" cy="23" r="2.2" {F}/><path d="M24 34.5Q23 39 26 43" stroke-width="1.6"/>'''
    sunrays = "".join(
        f'<path d="M{f(polar(24,24,11,a)[0])} {f(polar(24,24,11,a)[1])}L{f(polar(24,24,15.5 if a % 90 == 0 else 14,a)[0])} {f(polar(24,24,15.5 if a % 90 == 0 else 14,a)[1])}"/>'
        for a in range(0, 360, 45))
    g["season-summer"] = f'''<circle cx="24" cy="24" r="7"/><g stroke-width="1.8">{sunrays}</g><path d="M20.5 22Q21.5 19.8 24 19.4" stroke-width="1.3"/>'''
    g["season-autumn"] = f'''<path d="M12 36C10 22 20 10 38 9C38 26 28 37 12 36Z"/><path d="M12 36Q22 24 34 13" stroke-width="1.5"/>
<path d="M18 29.5l-.6-5M22.6 24.6l-.4-5.2M27 20l5 .6M21 27.5l5.2.4" stroke-width="1.2"/><path d="M12 36L7.5 41.5"/>'''
    arms = []
    for a in range(-90, 270, 60):
        x1, y1 = polar(24, 24, 15, a)
        arms.append(f'<path d="M24 24L{f(x1)} {f(y1)}"/>')
        bx, by = polar(24, 24, 9.5, a)
        l1 = polar(bx, by, 4, a - 145)
        l2 = polar(bx, by, 4, a + 145)
        arms.append(f'<path d="M{f(l1[0])} {f(l1[1])}L{f(bx)} {f(by)}L{f(l2[0])} {f(l2[1])}" stroke-width="1.5"/>')
    g["season-winter"] = "".join(arms) + f'<circle cx="24" cy="24" r="1.8" {F}/>'
    return g


def glyphs():
    out = {k: _g(v) for k, v in glyph_inner().items()}
    # Light ink for glyphs that sit on the coloured ribbons.
    light = glyph_inner(LIGHT)
    for k in ("craft", "world"):
        out[k + "-light"] = _g(light[k], LIGHT)
    # A reusable wash (white so Godot can modulate it to any brush colour).
    out["wash"] = svg_doc(f'<path d="{blob_path(24,24,19,7)}" fill="#ffffff" fill-opacity=".62" stroke="#ffffff" stroke-opacity=".9" stroke-width="1.1"/>')
    out["ink-circle"] = svg_doc(f'<path d="{blob_path(24,24,20,3,n=7,wobble=.07)}" fill="none" stroke="{INK}" stroke-width="1.6" stroke-linecap="round"/>')
    return out


# ------------------------------------------------------------------ CSS

NOISE = ("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='240' height='240'>"
         "<filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/>"
         "<feColorMatrix values='0 0 0 0 .32 0 0 0 0 .24 0 0 0 0 .15 0 0 0 .11 0'/></filter>"
         "<filter id='m'><feTurbulence type='fractalNoise' baseFrequency='.018' numOctaves='3' seed='4' stitchTiles='stitch'/>"
         "<feColorMatrix values='0 0 0 0 .55 0 0 0 0 .42 0 0 0 0 .25 0 0 0 .16 0'/></filter>"
         "<rect width='100%' height='100%' filter='url(%23m)'/><rect width='100%' height='100%' filter='url(%23n)'/></svg>")

CSS = f"""
.paper{{background:{PAPER} url("{NOISE}");}}
.shadow{{filter:drop-shadow(0 3px 2px rgba(40,28,16,.28)) drop-shadow(0 10px 18px rgba(20,14,8,.28));}}
.label{{font-family:'Fraunces';font-style:italic;font-variation-settings:'SOFT' 100,'WONK' 1,'opsz' 14;color:{INK};}}
.pal{{position:relative;display:flex;align-items:flex-end;padding:10px 22px 8px 22px;gap:2px;}}
.btn{{position:relative;width:70px;height:74px;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;}}
.btn img.gl{{width:42px;height:42px;position:relative;z-index:2;opacity:.82}}
.btn .t{{font-size:14px;margin-top:2px;position:relative;z-index:2;opacity:.78;white-space:nowrap}}
.btn.sel img.gl,.btn.sel .t,.btn.hov img.gl,.btn.hov .t{{opacity:1}}
.btn .wash{{position:absolute;left:50%;top:4px;width:62px;height:56px;transform:translate(-50%,0);z-index:1}}
.btn .under{{position:absolute;bottom:-3px;left:50%;transform:translateX(-50%);z-index:1}}
.btn.hov img.gl{{transform:rotate(-4deg) translateY(-2px)}}
.sprig{{width:14px;height:60px;margin:0 6px;align-self:center;opacity:.55}}
.key{{display:inline-block;font-family:'Fraunces';font-style:normal;font-size:11px;line-height:14px;padding:0 4px;border:1.3px solid {INK};border-radius:4px 3px 5px 3px;margin:0 3px;transform:translateY(-1px)}}
.hint{{display:inline-flex;align-items:center;gap:6px;padding:5px 16px 5px 16px;font-size:14px;white-space:nowrap}}
.hint .dot{{opacity:.45;margin:0 4px}}
.slip{{position:relative;display:flex;gap:4px;padding:8px 16px 6px 16px;align-items:flex-end}}
.form{{width:74px;display:flex;flex-direction:column;align-items:center;position:relative}}
.form img.gl{{width:40px;height:40px;position:relative;z-index:2;opacity:.8}}
.form .t{{font-size:12px;opacity:.72;position:relative;z-index:2;white-space:nowrap}}
.form.sel img.gl,.form.sel .t{{opacity:1}}
.form .wash{{position:absolute;left:50%;top:0;width:54px;height:48px;transform:translateX(-50%);z-index:1}}
.ribbon{{position:absolute;top:0;width:52px;height:92px;clip-path:polygon(0 0,100% 0,100% 100%,50% 84%,0 100%);display:flex;justify-content:center;padding-top:34px;}}
.ribbon img{{width:32px;height:32px}}
.ribbon-cap{{position:absolute;font-family:'Fraunces';font-style:italic;font-variation-settings:'SOFT' 100,'WONK' 1;font-size:14px;color:{LIGHT};text-shadow:0 1px 2px rgba(20,14,8,.8),0 0 8px rgba(20,14,8,.5);width:64px;text-align:center}}
.swatch{{position:relative;width:58px;height:62px;display:flex;flex-direction:column;align-items:center}}
.chip{{display:flex;flex-direction:column;align-items:center;width:62px}}
"""


def wash_svg(colour, seed, w=62, h=56, opacity=.55):
    return (f'<svg class="wash" viewBox="0 0 48 44" preserveAspectRatio="none" style="width:{w}px;height:{h}px">'
            f'<path d="{blob_path(24,22,17.5,seed)}" fill="{colour}" fill-opacity="{opacity}" stroke="{colour}" stroke-opacity=".75" stroke-width=".9"/>'
            f'<path d="{blob_path(25,23,11,seed+11)}" fill="{colour}" fill-opacity=".22"/></svg>')


def underline_svg(w=46):
    return (f'<svg class="under" width="{w}" height="8" viewBox="0 0 46 8"><path d="M2 5.2C10 3.2 20 2.6 30 3.4C36 3.9 40 4.4 44 3.2" '
            f'fill="none" stroke="{INK}" stroke-width="1.8" stroke-linecap="round" stroke-opacity=".85"/></svg>')


def sprig():
    return (f'<svg class="sprig" viewBox="0 0 14 60"><path d="M7 56Q6 30 7.5 4" fill="none" stroke="{INK}" stroke-width="1.3" stroke-linecap="round"/>'
            f'<path d="M7 40Q3 37 2 33M7.2 28Q11 25 12 21M7.4 17Q4 14.5 3.5 11" fill="none" stroke="{INK}" stroke-width="1.1" stroke-linecap="round"/></svg>')


def button(gid, title, state="", colour=None, seed=1):
    colour = colour or WASH.get(gid, "#b9a58a")
    wash = wash_svg(colour, seed) if state == "sel" else ""
    under = underline_svg() if state in ("sel", "hov") else ""
    return (f'<div class="btn {state}">{wash}<img class="gl" src="{glyph_url(NAME, gid)}">'
            f'<div class="t label">{title}</div>{under}</div>')


def nib(size=.55, strength=.65, colour=WASH["land"], w=64):
    """Size is the ring, strength the ink level in the well."""
    r_max = 26
    r = 8 + (r_max - 8) * size
    level = 32 + r - 2 * r * strength
    return (f'<svg width="{w}" height="{w}" viewBox="0 0 64 64" style="align-self:center">'
            f'<defs><clipPath id="well{int(size*100)}{int(strength*100)}"><circle cx="32" cy="32" r="{f(r)}"/></clipPath></defs>'
            f'<circle cx="32" cy="32" r="{r_max}" fill="none" stroke="{INK}" stroke-opacity=".28" stroke-width="1" stroke-dasharray="1.5 3.5"/>'
            f'<g clip-path="url(#well{int(size*100)}{int(strength*100)})"><path d="M0 {f(level)}Q16 {f(level-2.2)} 32 {f(level)}T64 {f(level)}V64H0Z" fill="{colour}" fill-opacity=".72"/></g>'
            f'<path d="{blob_path(32,32,r,5,n=8,wobble=.035)}" fill="none" stroke="{INK}" stroke-width="1.8"/>'
            f'<circle cx="32" cy="32" r="1.6" fill="{INK}"/></svg>')


def palette(held="land", hover=None, mood=False, collapsed=False, seed=3):
    items = []
    for i, (gid, title) in enumerate(BRUSHES):
        state = "sel" if gid == held else ("hov" if gid == hover else "")
        items.append(button(gid, title, state, seed=i + 2))
    items.append(sprig())
    items.append(f'<div style="width:78px;display:flex;flex-direction:column;align-items:center;justify-content:center;height:74px">{nib(colour=WASH.get(held, WASH["land"]))}</div>')
    items.append(sprig())
    items.append(button("mood", "Mood", "sel" if mood else ("hov" if hover == "mood" else ""), seed=9))
    items.append(button("look", "Look", "hov" if hover == "look" else ""))
    items.append(button("photo", "Photo", "hov" if hover == "photo" else ""))
    w, h = 770, 98
    return (f'<div class="shadow" style="width:{w}px;height:{h}px;transform:rotate(-.5deg)">'
            f'<div class="paper pal" style="width:{w}px;height:{h}px;justify-content:center;clip-path:{deckle_polygon(w,h,seed)}">{"".join(items)}</div></div>')


def tape(x, y, rot, w=62, h=20):
    """Washi tape holding a paper piece to the screen."""
    return (f'<div class="abs" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;transform:rotate({rot}deg);'
            f'background:repeating-linear-gradient(90deg,rgba(214,186,132,.62) 0 6px,rgba(226,204,158,.62) 6px 12px);'
            f'clip-path:{deckle_polygon(w,h,int(x+y),1.2,3)};filter:drop-shadow(0 1px 1px rgba(40,28,16,.25))"></div>')


def collapsed_tab(held="land"):
    w, h = 170, 70
    title = dict(BRUSHES)[held]
    return (f'<div class="shadow" style="width:{w}px;height:{h}px;transform:rotate(-1deg)">'
            f'<div class="paper pal" style="width:{w}px;height:{h}px;clip-path:{deckle_polygon(w,h,21)};padding:4px 14px;align-items:center">'
            f'<div class="btn sel" style="height:62px">{wash_svg(WASH[held],2,52,46)}<img class="gl" src="{glyph_url(NAME, held)}" style="width:36px;height:36px"><div class="t label" style="font-size:12px">{title}</div></div>'
            f'{nib(.55,.65,WASH[held],56)}</div></div>')


def forms_slip(selected="form-alpine", seed=12):
    items = []
    for i, (gid, title) in enumerate(FORMS):
        sel = gid == selected
        wash = wash_svg(WASH["form"], 30 + i, 54, 48, .5) if sel else ""
        items.append(f'<div class="form {"sel" if sel else ""}">{wash}<img class="gl" src="{glyph_url(NAME, gid)}"><div class="t label">{title}</div></div>')
    w, h = 408, 76
    return (f'<div class="shadow" style="width:{w}px;height:{h}px;transform:rotate(.7deg)">'
            f'<div class="paper slip" style="width:{w}px;height:{h}px;clip-path:{deckle_polygon(w,h,seed,1.8,7)}">{"".join(items)}</div></div>')


def hint_slip(pairs, seed=5, w=470):
    parts = []
    for i, (k, v) in enumerate(pairs):
        if i: parts.append('<span class="dot">·</span>')
        parts.append(f'<span class="key">{k}</span><span>{v}</span>')
    return (f'<div class="shadow" style="display:inline-block;transform:rotate(.3deg)">'
            f'<div class="paper hint label" style="width:{w}px;justify-content:center;clip-path:{deckle_polygon(w,30,seed,1.6,6)}">{"".join(parts)}</div></div>')


def ribbons():
    out = []
    for right, colour, gid, cap in ((104, "#a65a4b", "craft", "Craft"), (40, "#4d6283", "world", "World")):
        tex = "repeating-linear-gradient(90deg,rgba(255,255,255,.05) 0 1px,rgba(0,0,0,.04) 1px 3px)"
        out.append(f'<div class="abs shadow" style="right:{right}px;top:0;width:52px;height:92px">'
                   f'<div class="ribbon" style="background:{tex},linear-gradient(180deg,{colour},{colour});">'
                   f'<img src="{glyph_url(NAME, gid + "-light")}"></div></div>'
                   f'<div class="ribbon-cap" style="right:{right-6}px;top:96px">{cap}</div>')
    return "".join(out)


def cursor(cx, cy, w=250, h=104, tag="form-alpine"):
    rx, ry = w / 2 - 6, h / 2 - 6
    ticks = ""
    for a in (0, 90, 180, 270):
        x1, y1 = w / 2 + (rx - 7) * math.cos(math.radians(a)), h / 2 + (ry - 3.5) * math.sin(math.radians(a))
        x2, y2 = w / 2 + (rx + 5) * math.cos(math.radians(a)), h / 2 + (ry + 2.5) * math.sin(math.radians(a))
        ticks += f'<path d="M{f(x1)} {f(y1)}L{f(x2)} {f(y2)}"/>'
    arc1 = f"M{f(w/2 - rx*math.cos(math.radians(20)))} {f(h/2 - ry*math.sin(math.radians(20)))}A{f(rx)} {f(ry)} 0 1 0 {f(w/2 + rx*math.cos(math.radians(35)))} {f(h/2 - ry*math.sin(math.radians(35)))}"
    arc2 = f"M{f(w/2 + rx*math.cos(math.radians(55)))} {f(h/2 - ry*math.sin(math.radians(55)))}A{f(rx)} {f(ry)} 0 0 0 {f(w/2 - rx*math.cos(math.radians(40)))} {f(h/2 - ry*math.sin(math.radians(40)))}"
    ring = f'<path d="{arc1}"/><path d="{arc2}"/>{ticks}'
    svg = (f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" style="overflow:visible">'
           f'<ellipse cx="{w/2}" cy="{h/2}" rx="{rx*.55}" ry="{ry*.55}" fill="{WASH["land"]}" fill-opacity=".16"/>'
           f'<g fill="none" stroke="{LIGHT}" stroke-opacity=".55" stroke-width="4.2" stroke-linecap="round">{ring}</g>'
           f'<g fill="none" stroke="{INK}" stroke-opacity=".9" stroke-width="1.8" stroke-linecap="round">{ring}</g>'
           f'<ellipse cx="{w/2}" cy="{h/2}" rx="{rx*.42}" ry="{ry*.42}" fill="none" stroke="{INK}" stroke-opacity=".6" stroke-width="1.2" stroke-dasharray="2 5"/>'
           f'<path d="M{w/2-6} {h/2}H{w/2+6}M{w/2} {h/2-4}V{h/2+4}" stroke="{INK}" stroke-width="1.6" stroke-linecap="round"/>'
           f'<path d="M{w/2 + rx*.72} {h/2 - ry*.72}Q{w/2+rx*.9} {h/2-ry*1.25} {w/2+rx*.98} {h/2-ry*1.55}" fill="none" stroke="{INK}" stroke-width="1" stroke-opacity=".7"/></svg>')
    tagw = 46
    tag_html = (f'<div class="abs shadow" style="left:{w/2+rx*.98-tagw/2}px;top:{h/2-ry*1.55-44}px;transform:rotate(6deg)">'
                f'<div class="paper" style="width:{tagw}px;height:46px;clip-path:{deckle_polygon(tagw,46,8,1.4,5)};display:flex;align-items:center;justify-content:center">'
                f'<img src="{glyph_url(NAME, tag)}" style="width:34px;height:34px"></div></div>')
    return f'<div class="abs" style="left:{cx-w/2}px;top:{cy-h/2}px;width:{w}px;height:{h}px">{svg}{tag_html}</div>'


def mood_card(selected="rosewater_dusk", seed=40):
    items = []
    for i, (mid, title, sky, glow, ground, water) in enumerate(MOODS):
        s = 40 + i * 7
        sel = mid == selected
        frame = blob_path(24, 22, 19, s, n=8, wobble=.07)
        # A tiny painted postcard: sky wash, the light, a far hill, near ground, a sliver of water.
        card = (f'<svg width="58" height="54" viewBox="0 0 48 44" style="{"transform:translateY(-5px) rotate(-3deg)" if sel else ""}">'
                f'<defs><clipPath id="pc{i}"><path d="{frame}"/></clipPath></defs><g clip-path="url(#pc{i})">'
                f'<rect width="48" height="44" fill="#{sky}"/>'
                f'<circle cx="32" cy="17" r="9" fill="#{glow}" fill-opacity=".55"/><circle cx="32" cy="17" r="4.5" fill="#{glow}"/>'
                f'<path d="M0 27Q12 17 24 24T48 23V44H0Z" fill="#{ground}" fill-opacity=".6"/>'
                f'<path d="M0 32Q16 25 30 31T48 30V44H0Z" fill="#{ground}"/>'
                f'<path d="M14 38Q24 35.5 36 38.5Q26 40.5 14 38Z" fill="#{water}"/></g>'
                f'<path d="{frame}" fill="none" stroke="{INK}" stroke-width="{2 if sel else 1}" stroke-opacity="{1 if sel else .45}"/></svg>')
        cap = f'<div class="label" style="font-size:12px;position:absolute;top:54px;white-space:nowrap">{title}</div>' if sel else ""
        items.append(f'<div class="swatch">{card}{cap}</div>')
    w, h = 600, 84
    return (f'<div class="shadow" style="width:{w}px;height:{h}px;transform:rotate(-.6deg)">'
            f'<div class="paper" style="width:{w}px;height:{h}px;clip-path:{deckle_polygon(w,h,seed,1.8,7)};display:flex;gap:4px;padding:6px 14px">{"".join(items)}</div></div>')


def drawer_card(season="season-autumn", seed=44):
    seasons = []
    for gid, title in SEASONS:
        sel = gid == season
        wash = wash_svg(WASH["season"], 70, 44, 40, .5) if sel else ""
        seasons.append(f'<div class="form {"sel" if sel else ""}" style="width:50px">{wash}<img class="gl" src="{glyph_url(NAME, gid)}" style="width:34px;height:34px"><div class="t label" style="font-size:11px">{title}</div></div>')
    chips = []
    for gid, title, colour in (("meadow", "Grass", "#80917b"), ("rock", "Rock", "#8a8190"), ("water", "Water", "#9a91b1")):
        pan = (f'<svg width="48" height="40" viewBox="0 0 48 40"><rect x="3" y="4" width="42" height="32" rx="7" fill="#ffffff" fill-opacity=".55" stroke="{INK}" stroke-width="1.4"/>'
               f'<path d="{blob_path(24,20,12,len(title)*3)}" fill="{colour}" fill-opacity=".9"/></svg>')
        chips.append(f'<div class="chip">{pan}<div class="label" style="font-size:11px;display:flex;align-items:center;gap:2px"><img src="{glyph_url(NAME, gid)}" style="width:16px;height:16px">{title}</div></div>')
    w, h = 290, 178
    return (f'<div class="shadow" style="width:{w}px;height:{h}px;transform:rotate(1.2deg)">'
            f'<div class="paper" style="width:{w}px;height:{h}px;clip-path:{deckle_polygon(w,h,seed,1.8,7)};padding:10px 18px">'
            f'<div class="label" style="font-size:13px;opacity:.7;margin-bottom:2px">season</div>'
            f'<div style="display:flex;gap:10px">{"".join(seasons)}</div>'
            f'<div class="label" style="font-size:13px;opacity:.7;margin:4px 0 2px">colours</div>'
            f'<div style="display:flex;gap:14px">{"".join(chips)}</div></div></div>')


# ------------------------------------------------------------------ pages

def create_frame(bgs):
    land_hint = [("drag", "raise land"), ("shift", "press a hollow"), ("[ ]", "size"), ("tab", "just look")]
    body = (ribbons() + cursor(1120, 612) +
            f'<div class="abs" style="left:335px;top:664px">{forms_slip()}</div>'
            f'<div class="abs" style="left:335px;top:756px">{palette()}</div>'
            + tape(318, 752, -32) + tape(1062, 750, 28) + tape(520, 657, 4, 46, 16) +
            f'<div class="abs" style="left:0;right:0;top:864px;display:flex;justify-content:center">{hint_slip(land_hint)}</div>')
    return page(body, CSS, bgs["forest"])


def mood_frame(bgs):
    body = (ribbons() +
            f'<div class="abs" style="left:360px;top:664px">{mood_card()}</div>'
            f'<div class="abs" style="left:975px;top:568px">{drawer_card()}</div>'
            f'<div class="abs" style="left:335px;top:756px">{palette(held="land", mood=True)}</div>'
            + tape(318, 752, -32) + tape(1062, 750, 28) + tape(1100, 558, 12, 50, 17) +
            f'<div class="abs" style="left:0;right:0;top:864px;display:flex;justify-content:center">{hint_slip([("click", "a mood"), ("hold", "compare with now"), ("esc", "close")], 9, 380)}</div>')
    return page(body, CSS, bgs["island"])


def _card(title, inner, note="", w=None):
    style = f"width:{w}px;" if w else ""
    return (f'<div style="{style}display:flex;flex-direction:column;gap:10px">'
            f'<div class="sheet-h">{title}</div>{inner}'
            + (f'<div class="sheet-n">{note}</div>' if note else "") + "</div>")


SHEET_CSS = """
.sheet-bg{position:absolute;inset:-60px;background-size:cover;filter:blur(26px) brightness(.62) saturate(.8)}
.sheet{position:relative;padding:40px 56px;display:flex;flex-direction:column;gap:34px}
.sheet-title{font-family:'Fraunces';font-variation-settings:'SOFT' 100,'WONK' 1;font-size:40px;color:#f6eedc}
.sheet-sub{font-family:'Fraunces';font-style:italic;font-size:17px;color:#e7dcc4;opacity:.85;margin-top:-26px}
.sheet-h{font-family:'Fraunces';font-style:italic;font-size:16px;color:#f6eedc;opacity:.9}
.sheet-n{font-family:'Fraunces';font-size:12.5px;color:#eadfca;opacity:.75;max-width:360px;line-height:1.35}
.row{display:flex;gap:36px;align-items:flex-start;flex-wrap:wrap}
"""


def sheet(bgs):
    names = [g for g, _ in BRUSHES] + ["mood", "look", "photo", "craft", "world"] + [g for g, _ in FORMS] + [g for g, _ in SEASONS] + ["rock"]
    cells = "".join(
        f'<div style="display:flex;flex-direction:column;align-items:center;width:78px"><img src="{glyph_url(NAME, n)}" style="width:56px;height:56px">'
        f'<div class="label" style="font-size:11px;opacity:.7">{n.replace("form-","").replace("season-","")}</div></div>' for n in names)
    w, h = 1328, 190
    glyph_sheet = (f'<div class="shadow"><div class="paper" style="width:{w}px;height:{h}px;clip-path:{deckle_polygon(w,h,77)};'
                   f'display:flex;flex-wrap:wrap;gap:8px 4px;padding:18px 24px">{cells}</div></div>')
    sw = 104
    def state(st, label, gid="water"):
        return (f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px"><div class="shadow"><div class="paper" style="width:{sw}px;height:96px;clip-path:{deckle_polygon(sw,96,len(label))};display:flex;justify-content:center;align-items:center">'
                f'{button(gid, dict(BRUSHES)[gid], st, seed=4)}</div></div><div class="sheet-n" style="text-align:center">{label}</div></div>')
    states = "".join([state("", "idle"), state("hov", "hover: glyph tips 4°, underline inks in"), state("sel", "selected: wash blooms, underline stays")])
    nibs = "".join(f'<div style="display:flex;flex-direction:column;align-items:center"><div class="paper" style="border-radius:6px;padding:4px">{nib(s, t, WASH["water"], 64)}</div><div class="sheet-n">{lbl}</div></div>'
                   for s, t, lbl in ((.15, .3, "small, soft"), (.55, .65, "medium"), (.95, .95, "wide, strong")))
    cur_box = lambda s, st: (f'<div style="position:relative;width:300px;height:150px;border-radius:10px;overflow:hidden;background:url(file://{bgs["island"]}) {-760 + s*0}px -560px">'
                             f'{cursor(150, 96, int(140 + 120*s), int(58 + 50*s), "land")}</div>')
    body = (f'<div class="sheet-bg" style="background-image:url(file://{bgs["forest"]})"></div><div class="sheet">'
            f'<div class="sheet-title">A · Field Journal</div><div class="sheet-sub">Ink glyphs on torn watercolour paper. Your sketchbook for making a world.</div>'
            + _card("Glyph set (docs/ui/glyphs/field-journal)", glyph_sheet)
            + '<div class="row">'
            + _card("Brush button states", f'<div style="display:flex;gap:18px">{states}</div>')
            + _card("Size and strength: the ink well", f'<div style="display:flex;gap:18px">{nibs}</div>', "Ring = brush size ([ ]). Ink level = strength (Shift [ ]). The level sloshes and settles when it changes.")
            + _card("While painting", collapsed_tab("water"), "Mid-stroke the strip slides down behind the screen edge; only a torn tab with the held brush and its well stays.", 300)
            + '</div><div class="row">'
            + _card("Land forms slip (hover Land, or press 1 again)", forms_slip())
            + _card("Cursor: compass circle + paper tag", f'<div style="display:flex;gap:16px">{cur_box(.2,.3)}{cur_box(.8,.8)}</div>', "Ink ring on a pale under-stroke so it reads on grass and rock. The gap in the ring slowly turns; the tag shows the form in hand.")
            + '</div><div class="row">'
            + _card("Mood swatches", mood_card())
            + _card("Customise drawer", drawer_card())
            + '</div>'
            + _card("Hint line", hint_slip([("drag", "raise land"), ("shift", "press a hollow"), ("[ ]", "size"), ("tab", "just look")]))
            + '</div>')
    return page(body, CSS + SHEET_CSS, None, 1440, 1240)

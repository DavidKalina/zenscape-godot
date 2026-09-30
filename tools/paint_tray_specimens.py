#!/usr/bin/env python3
"""The field case's specimens (scripts/materials_tray.gd): botanical-engraving
line art, one colour, written to assets/ui/tray/<id>.svg.

Every glyph is white line work on a 48x48 box, tinted in Godot by `modulate`.
One engraver's hand: contours CONTOUR wide, detail DETAIL, hatching HATCH at
HATCH_OPACITY. Shade falls to the lower right. Hatching is laid as plain
strokes, clipped here to each form's shadow crescent, so the SVG holds no
clips, masks or gradients (Godot's importer drops some; rgba() imports as
black), only stroke-opacity.

    python3 tools/paint_tray_specimens.py
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "tray")
CONTOUR = 1.15
DETAIL = 0.85
HATCH = 0.55
HATCH_OPACITY = 0.8
FAINT = 0.55
# Light from the upper left: shade lies toward SHADE.
SHADE = (0.62, 0.78)


# --- Geometry -----------------------------------------------------------------

def cubic(p0, p1, p2, p3, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def quad(p0, p1, p2, n=16):
    return cubic(p0, (p0[0] + 2 / 3 * (p1[0] - p0[0]), p0[1] + 2 / 3 * (p1[1] - p0[1])),
                 (p2[0] + 2 / 3 * (p1[0] - p2[0]), p2[1] + 2 / 3 * (p1[1] - p2[1])), p2, n)


def ellipse(c, rx, ry, turn=0.0, n=64, a0=0.0, a1=math.tau):
    out = []
    ct, st = math.cos(turn), math.sin(turn)
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((c[0] + x * ct - y * st, c[1] + x * st + y * ct))
    return out


def chain(*parts):
    out = []
    for part in parts:
        out.extend(part if not out else part[1:])
    return out


def inside(poly, p):
    x, y = p
    hit = False
    for i in range(len(poly)):
        x0, y0 = poly[i - 1]
        x1, y1 = poly[i]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def edge_distance(poly, p):
    best = 1e9
    for i in range(len(poly)):
        ax, ay = poly[i - 1]
        bx, by = poly[i]
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        t = 0.0 if L == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L))
        qx, qy = ax + t * dx - p[0], ay + t * dy - p[1]
        best = min(best, qx * qx + qy * qy)
    return math.sqrt(best)


def centre(poly):
    return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))


def inward(poly):
    """Unit inward normals at each vertex of a closed polygon."""
    n = len(poly)
    out = []
    for i in range(n):
        ax, ay = poly[i - 1]
        bx, by = poly[(i + 1) % n]
        tx, ty = bx - ax, by - ay
        L = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / L, tx / L
        probe = (poly[i][0] + nx * 0.3, poly[i][1] + ny * 0.3)
        if not inside(poly, probe):
            nx, ny = -nx, -ny
        out.append((nx, ny))
    return out


def contour_hatch(poly, count=3, spacing=1.15, side=0.1, narrow=0.2, first=1.1, shade=SHADE):
    """Engraver's form lines: offsets of the contour, `first` then `spacing`
    apart inward, on the shade side only, each shorter than the last.
    Returns polylines with their opacity."""
    c = centre(poly)
    normals = inward(poly)
    lines = []
    for k in range(count):
        d = first + k * spacing
        keep = side + narrow * k
        run = []
        for p, nrm in zip(poly + poly[:1], normals + normals[:1]):
            v = (p[0] - c[0], p[1] - c[1])
            lv = math.hypot(*v) or 1.0
            facing = (v[0] * shade[0] + v[1] * shade[1]) / lv
            q = (p[0] + nrm[0] * d, p[1] + nrm[1] * d)
            if facing > keep and inside(poly, q) and edge_distance(poly, q) > d * 0.8:
                run.append(q)
            elif run:
                if len(run) > 2:
                    lines.append((run, 1.0 - 0.18 * k))
                run = []
        if len(run) > 2:
            lines.append((run, 1.0 - 0.18 * k))
    return lines


def hatch(poly, depth, spacing=1.45, angle=58.0, gap=1.0, side=0.05, shade=SHADE, holes=(), taper=True):
    """Straight hatching in a form's shadow crescent: parallel strokes at
    `angle` degrees, kept where a point is inside `poly`, `gap` to `depth`
    from its edge (less toward the lit side when `taper`) and on the shade
    side of its centre. Returns segments."""
    c = centre(poly)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    reach = max(max(xs) - min(xs), max(ys) - min(ys))
    a = math.radians(angle)
    d = (math.cos(a), math.sin(a))
    nrm = (-d[1], d[0])
    segs = []
    k = -reach
    while k <= reach:
        o = (c[0] + nrm[0] * k, c[1] + nrm[1] * k)
        run = []
        t = -reach
        while t <= reach:
            p = (o[0] + d[0] * t, o[1] + d[1] * t)
            ok = False
            if inside(poly, p) and not any(inside(h, p) for h in holes):
                v = (p[0] - c[0], p[1] - c[1])
                lv = math.hypot(*v) or 1.0
                facing = (v[0] * shade[0] + v[1] * shade[1]) / lv
                if facing > side:
                    e = edge_distance(poly, p)
                    reachd = depth * (0.35 + 0.65 * min(1.0, (facing - side) / 0.6)) if taper else depth
                    ok = gap <= e <= reachd
            if ok:
                run.append(p)
            elif run:
                if len(run) > 2:
                    segs.append((run[0], run[-1]))
                run = []
            t += 0.25
        if len(run) > 2:
            segs.append((run[0], run[-1]))
        k += spacing
    return [s for s in segs if math.dist(s[0], s[1]) > 1.1]


# --- SVG ------------------------------------------------------------------------

def f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def poly_d(points, closed=False):
    d = "M" + " L".join(f(x) + " " + f(y) for x, y in points)
    return d + ("Z" if closed else "")


class Glyph:
    def __init__(self):
        self.items = []

    def line(self, points, width=CONTOUR, opacity=1.0, closed=False):
        self.items.append((poly_d(points, closed), width, opacity))

    def path(self, d, width=CONTOUR, opacity=1.0):
        self.items.append((d, width, opacity))

    def segments(self, segs, width=HATCH, opacity=HATCH_OPACITY):
        if segs:
            self.items.append(("".join("M%s %sL%s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1])) for a, b in segs), width, opacity))

    def form(self, poly, count=3, spacing=1.15, side=0.1, narrow=0.2, first=1.1, opacity=HATCH_OPACITY):
        for run, o in contour_hatch(poly, count, spacing, side, narrow, first):
            self.line(run, HATCH, opacity * o)

    def dot(self, p, r=0.42, opacity=1.0):
        self.items.append(("M%s %sa%s %s 0 1 0 0.01 0Z" % (f(p[0] - r), f(p[1]), f(r), f(r)), r * 2.0, opacity))

    def svg(self, turn=0.0):
        body = []
        for d, w, o in self.items:
            attr = ' stroke-opacity="%s"' % f(o) if o < 1.0 else ""
            body.append('<path d="%s" stroke-width="%s"%s/>' % (d, f(w), attr))
        g = '<g fill="none" stroke="#ffffff" stroke-linecap="round" stroke-linejoin="round"%s>' % (
            ' transform="rotate(%s 24 24)"' % f(turn) if turn else "")
        return '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">\n' + g + "\n" + "\n".join(body) + "\n</g>\n</svg>\n"


# --- Specimens -------------------------------------------------------------------

def acorn():
    g = Glyph()
    rim_l, rim_r = (14.4, 21.8), (33.6, 21.8)
    nut = chain(cubic(rim_l, (14.2, 31.0), (19.4, 38.6), (24.0, 42.2)),
                cubic((24.0, 42.2), (28.6, 38.6), (33.8, 31.0), rim_r))
    rim = cubic(rim_r, (29.0, 24.8), (19.0, 24.8), rim_l)
    body = chain(nut, rim[1:-1])
    g.line(nut)
    g.line([(24.0, 42.2), (24.1, 43.8)], DETAIL)
    g.form(body, 4, 1.05, 0.05, 0.16)
    # Faint striations along the nut, on its lit side.
    g.line(cubic((19.0, 25.2), (18.4, 31.0), (20.4, 36.6), (23.0, 40.4)), HATCH, 0.45)
    # The cup: a dome of small overlapping scales.
    dome = chain(cubic(rim_l, (13.4, 14.8), (18.6, 11.8), (24.0, 11.8)),
                 cubic((24.0, 11.8), (29.4, 11.8), (34.6, 14.8), rim_r))
    g.line(dome)
    g.line(rim)
    cup = chain(dome, rim[1:-1])
    rows = [(14.6, 2.3, 0.0), (16.9, 2.4, 1.2), (19.2, 2.5, 0.0), (21.5, 2.6, 1.3)]
    for y, step, shift in rows:
        x = 12.6 + shift
        while x < 36.0:
            arc = [(x - step * 0.34 + step * 0.68 * t, y + 0.85 * math.sin(math.pi * t)) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
            if all(inside(cup, p) and edge_distance(cup, p) > 0.8 for p in arc):
                v = (x - 24.0) * SHADE[0] + (y - 17.0) * SHADE[1]
                g.line(arc, HATCH, 0.95 if v > 0 else 0.7)
                if v > 1.5:
                    g.line([(x - 0.3, y + 1.35), (x + 0.5, y + 1.25)], HATCH, 0.6)
            x += step
    g.form(cup, 1, 1.0, 0.25, 0.2, 0.9)
    # The stalk, cut.
    g.line(cubic((24.0, 11.8), (24.0, 9.8), (24.8, 7.8), (26.6, 6.2)))
    g.line([(25.7, 5.4), (27.4, 7.0)], DETAIL)
    return g.svg(-14.0)


def pine_cone():
    g = Glyph()
    top, bottom = 7.5, 43.0
    cx = 24.0

    def radius(v):
        return 9.0 * math.sin(math.pi * min(max(v, 0.0), 1.0)) ** 0.72 * (1.12 - 0.32 * v)

    def at(v, phi):
        return (cx + radius(v) * math.sin(phi), top + (bottom - top) * v)

    left = [at(i / 40, -math.pi / 2) for i in range(41)]
    right = [at(i / 40, math.pi / 2) for i in range(41)]
    outline = left + right[::-1][1:-1]
    # Scales: two families of spirals cross into a diamond lattice, finer
    # toward the turning edges.
    for family in (1, -1):
        for n in range(-10, 11):
            a0 = n * math.pi / 5.0
            pts = []
            for i in range(61):
                v = 0.04 + 0.93 * i / 60
                phi = a0 + family * 3.2 * v
                if math.cos(phi) > 0.1:
                    pts.append(at(v, phi))
                elif pts:
                    if len(pts) > 2:
                        g.line(pts, HATCH * 1.2, 0.9)
                    pts = []
            if len(pts) > 2:
                g.line(pts, HATCH * 1.2, 0.9)
    # Each scale's lip, a short dark stroke under its lattice crossing, on the
    # scales facing the viewer.
    for n in range(-10, 11):
        for m in range(-10, 11):
            v = (m - n) * (math.pi / 5.0) / 6.4
            if not 0.1 < v < 0.93:
                continue
            phi = n * math.pi / 5.0 + 3.2 * v
            phi = math.atan2(math.sin(phi), math.cos(phi))
            if math.cos(phi) > 0.4:
                p = at(v + 0.028, phi)
                w = 1.0 * math.cos(phi)
                g.line([(p[0] - w, p[1]), (p[0], p[1] + 0.55), (p[0] + w, p[1])], HATCH, 0.8)
    g.line(outline, CONTOUR, closed=True)
    g.form(outline, 2, 1.0, 0.2, 0.25, 0.9)
    # The stalk.
    g.line(cubic((cx, top), (cx - 0.2, 5.6), (cx + 0.6, 4.2), (cx + 2.2, 3.2)))
    return g.svg(-12.0)


def _catkin(g, c, rx, ry, turn, foot):
    """A pussy-willow catkin: silky, pointed a little at its tip, and the
    hooded bud scale it broke from at its foot. `turn` tilts it from upright."""
    ct, st = math.cos(turn), math.sin(turn)

    def to(x, y):
        return (c[0] + x * ct - y * st, c[1] + x * st + y * ct)
    body = []
    for i in range(48):
        a = math.tau * i / 48
        y = -ry * math.sin(a)
        x = rx * math.cos(a) * (1.0 - 0.28 * max(0.0, math.sin(a)) ** 2)
        body.append(to(x, y))
    # A soft edge of small tufts, not a hard line.
    n = len(body)
    for i in range(0, n, 2):
        a, b = body[i], body[(i + 2) % n]
        m = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        o = (m[0] - c[0], m[1] - c[1])
        lo = math.hypot(*o) or 1.0
        bulge = (m[0] + o[0] / lo * 0.75, m[1] + o[1] / lo * 0.75)
        g.line(quad(a, bulge, b, 5), DETAIL * 0.9)
    # Down: a stipple, denser in the shade, and the form lines.
    for i in range(30):
        a = i * 2.39996
        r = math.sqrt((i + 0.5) / 30) * 0.8
        p = to(r * rx * math.cos(a), r * ry * math.sin(a))
        v = (p[0] - c[0]) * SHADE[0] + (p[1] - c[1]) * SHADE[1]
        if v > -0.5 or i % 3 == 0:
            g.dot(p, 0.26, 0.75)
    g.form(body, 2, 0.95, 0.2, 0.3, 1.0)
    # The bud scale, a hooded cup, and the short stalk to the twig.
    cup = [to(-rx * 0.9, ry * 0.62), to(-rx * 0.6, ry * 1.12), to(0.0, ry * 1.28), to(rx * 0.6, ry * 1.12), to(rx * 0.9, ry * 0.62)]
    g.line(cubic(cup[0], cup[1], cup[3], cup[4], 14), DETAIL)
    g.line([to(0.0, ry * 1.0), to(0.0, ry * 1.18)], HATCH, 0.8)
    g.line([to(rx * 0.3, ry * 0.9), to(rx * 0.55, ry * 1.02)], HATCH, 0.8)
    g.line([to(0.0, ry * 1.26), foot], DETAIL)


def willow_catkin():
    g = Glyph()
    twig = cubic((18.6, 45.6), (21.4, 34.0), (22.8, 22.0), (27.6, 5.0), 30)
    g.line(twig)
    # Nodes: each catkin on a short stalk from the twig.
    _catkin(g, (29.4, 12.6), 3.4, 5.8, 0.34, (26.2, 16.8))
    _catkin(g, (15.8, 22.4), 3.1, 5.3, -0.62, (22.2, 26.8))
    _catkin(g, (29.0, 30.0), 2.8, 4.8, 0.72, (21.8, 34.0))
    # One narrow leaf, midrib and a few veins.
    leaf_a, leaf_b = (20.4, 39.6), (8.6, 36.2)
    upper = cubic(leaf_a, (17.4, 36.0), (12.4, 34.8), leaf_b, 20)
    lower = cubic(leaf_b, (12.6, 37.8), (17.2, 39.8), leaf_a, 20)
    g.line(chain(upper, lower), DETAIL, closed=True)
    g.line(cubic(leaf_a, (17.0, 37.8), (12.6, 36.4), leaf_b, 16), HATCH, 0.75)
    for t in (0.3, 0.55, 0.78):
        m = cubic(leaf_a, (17.0, 37.8), (12.6, 36.4), leaf_b, 16)[int(t * 16)]
        g.line([m, (m[0] - 1.2, m[1] + 1.1)], HATCH, 0.55)
    return g.svg(0.0)


def _samara(g, at, scale, turn, shade_lines=2):
    """A birch nutlet with its two papery wings, drawn about `at`."""
    ct, st = math.cos(turn), math.sin(turn)

    def to(p):
        x, y = (p[0] - 24.0) * scale, (p[1] - 24.0) * scale
        return (at[0] + x * ct - y * st, at[1] + x * st + y * ct)
    # One outline round both wings: a broad round seed, notched at the top
    # between the styles, the nutlet at its heart.
    half = chain(cubic((24.0, 20.4), (23.0, 18.6), (21.0, 16.0), (17.4, 15.8), 10),
                 cubic((17.4, 15.8), (12.6, 15.8), (10.6, 20.4), (11.0, 24.8), 14),
                 cubic((11.0, 24.8), (11.4, 30.4), (17.0, 34.4), (24.0, 34.4), 16))
    rim = half + [(48.0 - x, y) for x, y in half[::-1]][1:-1]
    rim = [to(p) for p in rim]
    g.line(rim, DETAIL, closed=True)
    n = len(half)
    for sign in (-1, 1):
        for t in (0.26, 0.42, 0.58, 0.74, 0.9):
            x, y = half[int(t * (n - 1))]
            end = to((x if sign < 0 else 48.0 - x, y))
            start = to((24.0 + sign * 2.5, 22.0 + 6.6 * t))
            mid = ((start[0] * 0.55 + end[0] * 0.45), (start[1] * 0.55 + end[1] * 0.45))
            g.line(quad(start, mid, end, 8)[:-2], HATCH, 0.45)
    g.form(rim, shade_lines, 1.0, 0.15, 0.3, 1.0)
    nut = [to(p) for p in ellipse((24.0, 25.2), 1.9, 4.7, 0.0, 36)]
    g.line(nut, CONTOUR, closed=True)
    g.form(nut, 2, 0.8, -0.3, 0.35, 0.8)
    g.line([to((23.5, 20.6)), to((22.7, 18.4))], DETAIL)
    g.line([to((24.5, 20.6)), to((25.3, 18.4))], DETAIL)


def birch_samara():
    g = Glyph()
    # One nutlet shed from the catkin, drawn large, as a plate figure would be.
    _samara(g, (24.0, 22.6), 1.34, math.radians(-10), 3)
    # A second, small and far, still turning on the air.
    _samara(g, (38.6, 40.2), 0.42, math.radians(38), 1)
    return g.svg(0.0)


def seed_head():
    g = Glyph()
    c = (24.0, 18.6)
    # The stalk, hollow, drawn as two close lines.
    stalk = cubic((23.6, 21.2), (23.2, 30.0), (22.4, 38.0), (19.8, 46.0), 20)
    g.line(stalk, CONTOUR)
    g.line([(x + 1.0, y) for x, y in stalk[3:]], HATCH, 0.6)
    # The clock: rays out to a small parachute each; a few have gone.
    gone = {3, 4}
    n = 20
    for i in range(n):
        a = -math.pi / 2 + math.tau * i / n + 0.07 * math.sin(i * 1.7)
        if i in gone:
            continue
        lower = math.sin(a) > 0.55
        r = 13.0 if not lower else 11.4
        start = (c[0] + math.cos(a) * 2.8, c[1] + math.sin(a) * 2.8)
        end = (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r)
        g.line([start, end], HATCH, 0.72)
        for j in (-1.5, -0.5, 0.5, 1.5):
            b = a + j * 0.42
            tip = (end[0] + math.cos(b) * 1.9, end[1] + math.sin(b) * 1.9)
            g.line([end, tip], HATCH * 0.85, 0.8)
    # Two seeds adrift, up and away to the right.
    for (x, y, a, s) in ((39.4, 7.2, -0.9, 1.0), (43.2, 12.8, -0.55, 0.8)):
        foot = (x - math.cos(a) * 3.8 * s, y - math.sin(a) * 3.8 * s)
        g.line([foot, (x, y)], HATCH, 0.72)
        g.line([foot, (foot[0] - math.cos(a) * 1.1, foot[1] - math.sin(a) * 1.1)], DETAIL, 0.9)
        for j in (-1.5, -0.5, 0.5, 1.5):
            b = a + j * 0.42
            g.line([(x, y), (x + math.cos(b) * 1.8 * s, y + math.sin(b) * 1.8 * s)], HATCH * 0.85, 0.8)
    # The receptacle.
    head = ellipse(c, 2.8, 2.4, 0.0, 28)
    g.line(head, DETAIL, closed=True)
    g.form(head, 1, 0.8, -0.2, 0.2, 0.75)
    # Its bracts, turned down.
    for dx in (-1.8, 0.0, 1.8):
        g.line(quad((c[0] + dx * 0.6, c[1] + 2.3), (c[0] + dx * 1.4, c[1] + 3.7), (c[0] + dx * 1.2 - 0.3, c[1] + 5.3), 8), HATCH, 0.9)
    return g.svg(0.0)


def reed():
    g = Glyph()
    # The seed head: a long rounded club, finely barred.
    top, bot, w = 11.0, 27.4, 3.0
    xc = 24.8
    head = chain(cubic((xc - w, top + 1.6), (xc - w, top - 0.4), (xc + w, top - 0.4), (xc + w, top + 1.6), 10),
                 [(xc + w + 0.15, (top + bot) * 0.5)],
                 cubic((xc + w, bot - 1.6), (xc + w, bot + 0.6), (xc - w, bot + 0.6), (xc - w, bot - 1.6), 10),
                 [(xc - w - 0.15, (top + bot) * 0.5)])
    g.line(head, CONTOUR, closed=True)
    y = top + 1.5
    i = 0
    while y < bot - 0.9:
        half = w - 0.4 if top + 1.2 < y < bot - 1.2 else w - 1.2
        x0 = xc - half + (1.5 if i % 2 else 2.3)
        g.line(quad((x0, y), (xc + half * 0.4, y + 0.45), (xc + half - 0.2, y), 6), HATCH, 0.8)
        y += 0.95
        i += 1
    g.form(head, 1, 0.8, 0.2, 0.2, 0.7)
    # The spike over it, and the stem below.
    g.line([(xc, top - 0.2), (xc + 0.1, 4.0)], DETAIL)
    g.line(cubic((23.0, 46.0), (23.8, 38.0), (24.6, 32.0), (24.8, bot + 0.4), 16), CONTOUR)
    # A blade from the foot, lifting and folding over at its tip.
    outer = cubic((22.4, 45.6), (17.0, 34.0), (12.6, 22.0), (13.4, 13.6), 24)
    fold = cubic((13.4, 13.6), (13.5, 12.2), (14.4, 11.6), (15.4, 12.4), 8)
    inner = cubic((14.9, 14.8), (14.8, 22.8), (18.6, 33.6), (23.2, 44.6), 24)
    g.line(chain(outer, fold), DETAIL)
    g.line(inner, DETAIL)
    g.line(cubic((22.8, 45.2), (18.0, 34.0), (14.0, 24.0), (13.9, 16.0), 20), HATCH, 0.55)
    # A second, slighter blade to the right.
    outer2 = cubic((23.8, 45.8), (29.8, 38.0), (34.0, 30.0), (37.4, 24.4), 20)
    inner2 = cubic((37.4, 24.4), (34.6, 31.4), (30.2, 39.4), (24.4, 46.0), 20)
    g.line(chain(outer2, inner2), DETAIL, closed=True)
    g.line(cubic((24.2, 45.8), (29.8, 38.8), (33.8, 31.0), (36.4, 26.0), 16), HATCH, 0.55)
    return g.svg(0.0)


def water_drop():
    g = Glyph()
    tip = (24.0, 4.6)
    c = (24.0, 25.6)
    r = 10.6
    left = cubic(tip, (22.4, 10.6), (c[0] - r, 16.8), (c[0] - r, c[1]), 20)
    right = cubic((c[0] + r, c[1]), (c[0] + r, 16.8), (25.6, 10.6), tip, 20)
    under = ellipse(c, r, r, 0.0, 40, math.pi, 2 * math.pi)
    under = [(x, 2 * c[1] - y) for x, y in under]
    drop = chain(left, under, right)[:-1]
    g.line(drop + drop[:1], CONTOUR)
    g.form(drop, 4, 1.05, 0.05, 0.17)
    # The window of light, and a glint.
    g.line(ellipse(c, r - 3.2, r - 3.2, 0.0, 16, math.radians(196), math.radians(252)), DETAIL, 0.9)
    g.dot((c[0] - 4.4, c[1] - 8.6), 0.45, 0.9)
    # Where it will land: two rings on still water, broken where the light is.
    for rx, ry, o, a0, a1 in ((12.6, 1.8, 0.7, 12, 150), (7.2, 1.0, 0.5, 20, 160)):
        g.line(ellipse((24.0, 42.4), rx, ry, 0.0, 30, math.radians(a0), math.radians(a1)), HATCH, o)
    g.line(ellipse((24.0, 42.4), 12.6, 1.8, 0.0, 20, math.radians(200), math.radians(300)), HATCH, 0.35)
    return g.svg(0.0)


def river_stone():
    g = Glyph()

    def pebble(c, rx, ry, turn, lean):
        pts = []
        for i in range(72):
            a = math.tau * i / 72
            k = 1.0 + lean * math.sin(a) * 0.08 + 0.06 * math.cos(2 * a + 0.6) + 0.03 * math.cos(3 * a + 1.1)
            x = rx * math.cos(a) * k
            y = ry * math.sin(a) * (1.0 + (0.12 if math.sin(a) > 0 else -0.08)) * k
            ct, st = math.cos(turn), math.sin(turn)
            pts.append((c[0] + x * ct - y * st, c[1] + x * st + y * ct))
        return pts
    big = pebble((22.2, 25.4), 15.4, 9.0, math.radians(-8), 1.0)
    small = pebble((37.0, 36.6), 5.2, 3.3, math.radians(14), -1.0)
    # The ground it lies on: level strokes under both.
    for y, x0, x1, o in ((36.4, 10.0, 26.0, 0.5), (37.9, 14.0, 28.4, 0.38), (41.6, 30.2, 44.2, 0.45), (43.0, 33.0, 42.2, 0.34)):
        g.line([(x0, y), (x1, y)], HATCH, o)
    g.line(big, CONTOUR, closed=True)
    # A thin quartz vein across its far end.
    vein = cubic((26.8, 33.0), (29.0, 27.0), (31.8, 21.4), (33.4, 17.2), 24)
    for off in (0.0, 0.9):
        kept = [(x + off, y + off * 0.2) for x, y in vein]
        kept = [p for p in kept if inside(big, p) and edge_distance(big, p) > 0.7]
        if kept:
            g.line(kept, HATCH, 0.85)
    g.form(big, 4, 1.1, 0.05, 0.16)
    # A few pits and grains on the lit face.
    g.line(small, CONTOUR, closed=True)
    g.form(small, 2, 0.9, 0.1, 0.25, 0.8)
    return g.svg(0.0)


def crystal():
    """Undiscovered: bare outline only."""
    g = Glyph()

    def prism(base, h, w, turn):
        ct, st = math.cos(turn), math.sin(turn)

        def p(x, y):
            return (base[0] + x * ct - y * st, base[1] + x * st + y * ct)
        g.line([p(-w, 0), p(-w, -h), p(0, -h - w * 1.3), p(w, -h), p(w, 0)], CONTOUR)
        g.line([p(0, 0), p(0, -h), p(0, -h - w * 1.3)], DETAIL, 0.7)
        g.line([p(-w, -h), p(0, -h), p(w, -h)], DETAIL, 0.7)
    prism((24.0, 41.0), 22.0, 4.2, 0.0)
    prism((17.6, 41.6), 12.0, 3.2, math.radians(-24))
    prism((31.0, 41.6), 9.0, 2.8, math.radians(26))
    g.line([(10.0, 42.2), (38.0, 42.2)], HATCH, 0.6)
    return g.svg(0.0)


def snowflake():
    """Undiscovered: bare outline only."""
    g = Glyph()
    c = (24.0, 24.0)
    for k in range(6):
        a = -math.pi / 2 + k * math.pi / 3
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        g.line([(c[0] + d[0] * 2.4, c[1] + d[1] * 2.4), (c[0] + d[0] * 17.0, c[1] + d[1] * 17.0)], CONTOUR)
        for t, L in ((7.0, 4.4), (11.6, 3.2)):
            base = (c[0] + d[0] * t, c[1] + d[1] * t)
            for s in (1, -1):
                tip = (base[0] + (d[0] * 0.75 + n[0] * 0.66 * s) * L, base[1] + (d[1] * 0.75 + n[1] * 0.66 * s) * L)
                g.line([base, tip], DETAIL)
    g.line([(c[0] + 2.4 * math.cos(-math.pi / 2 + k * math.pi / 3), c[1] + 2.4 * math.sin(-math.pi / 2 + k * math.pi / 3)) for k in range(7)], DETAIL)
    return g.svg(0.0)


SPECIMENS = {
    "acorn": acorn,
    "pine_cone": pine_cone,
    "willow_catkin": willow_catkin,
    "birch_samara": birch_samara,
    "seed_head": seed_head,
    "reed": reed,
    "water_drop": water_drop,
    "river_stone": river_stone,
    "crystal": crystal,
    "snowflake": snowflake,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, draw in SPECIMENS.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as fh:
            fh.write(draw())
        print(name)

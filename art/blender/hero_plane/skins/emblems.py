"""The emblems: small decals the hangar lays over any paint and pattern
(scripts/endless/plane_decals.gd lists them; the look's `decal`).
Run: python tools/blender.py run art/blender/hero_plane/skins/emblems.py
     (... -- swift bolt   makes only those)

Each is a mark or two where such marks sit on a biplane, clear elsewhere,
with a dark or light keyline so it reads on any colour. The plane's own
atlas already carries a roundel on the upper wing's top and the lower
wing's underside, a 27 on the fuselage's sides (and a small one at the fin's
leading edge); an emblem that sits on one of those covers it whole.

A mark is drawn in its own frame by `place`: (u, v) in toy units from its
centre, v up (on a wing, to the leading edge), u nose-ward on the body and
fin (the same picture on both sides, facing forward) or, with read=True,
the way writing runs (so a number reads right on port and starboard), and
out along the span on a wing (both halves share the atlas: a wing's mark
is mirrored, so no writing there). Shapes are signed distances (+ inside),
laid with `cov`, so every edge is a pixel soft.
"""
import math
import sys

import numpy as np
from hero_plane.hero_plane_decal import Decal, girth, sst

OUT = "assets/models/hero_plane/skins/emblems/"

CREAM, INK, GOLD = "f2e8d2", "23242a", "e3b23c"
RED, NAVY, GREEN = "c8452b", "1d2b4a", "2f5d46"

# Where the plane's own marks are (hero_plane_paint.py), to sit on them.
WING_UP = ("up_top", (0.459, 0.150))       # the upper wing's roundel
WING_LO = ("lo_under", (0.420, 0.148))     # the lower wing's, underneath
WING_MID = ("up_top", (0.0, 0.150))        # the upper wing's centre
SIDE = ("body", (0.242, 1.2))              # the fuselage's 27: (z, angle round from the top)
CONE = ("body", (0.545, 1.18))             # the tail cone's side
RUDDER = ("fin", (0.722, 0.135))           # the rudder's middle (the fin is z < 0.685)


def place(d, where, draw, read=False, turn=0.0):
	"""Lays draw(u, v, soft) -> [(colour, coverage), ...] at `where` (a
	region and its centre), the frame turned `turn` radians."""
	on, at = where
	for f in d.frames(on):
		a, b = f.ab(True)
		if f.name == "body":
			u = -(a - at[0])
			v = at[1] * girth(at[0]) / math.pi - b
		elif f.name in ("fin_r", "fin_l"):
			u = -(a - at[0])
			v = b - at[1]
		else:
			u = a - at[0]
			v = at[1] - b
		if read and f.side is not None:
			u = u * f.side
		if turn:
			c, s = math.cos(turn), math.sin(turn)
			u, v = u * c + v * s, v * c - u * s
		for colour, t in draw(u, v, 1.2 / f.px):
			d.lay(f, t, colour)


def cov(sd, soft):
	return sst(-soft, soft, sd)


def disc_sd(u, v, r, at=(0.0, 0.0)):
	return r - np.hypot(u - at[0], v - at[1])


def ring_sd(u, v, r0, r1):
	q = np.hypot(u, v)
	return np.minimum(q - r0, r1 - q)


def seg_d(u, v, p, q):
	"""Distance to the segment p-q."""
	du, dv = q[0] - p[0], q[1] - p[1]
	t = np.clip(((u - p[0]) * du + (v - p[1]) * dv) / max(du * du + dv * dv, 1e-12), 0.0, 1.0)
	return np.hypot(u - p[0] - du * t, v - p[1] - dv * t)


def poly_sd(u, v, pts, k=1.0):
	"""Signed distance to the polygon `pts` (scaled by k), + inside."""
	pts = [(x * k, y * k) for x, y in pts]
	d = np.full(u.shape, 9.0, dtype=np.float32)
	ins = np.zeros(u.shape, dtype=bool)
	for p, q in zip(pts, pts[1:] + pts[:1]):
		d = np.minimum(d, seg_d(u, v, p, q))
		if p[1] != q[1]:
			cross = ((p[1] > v) != (q[1] > v)) & (u < (q[0] - p[0]) * (v - p[1]) / (q[1] - p[1]) + p[0])
			ins ^= cross
	return np.where(ins, d, -d)


def line_sd(u, v, pts, w, k=1.0):
	"""A stroke w wide (round ends) along the points, + inside."""
	pts = [(x * k, y * k) for x, y in pts]
	d = np.full(u.shape, 9.0, dtype=np.float32)
	for p, q in zip(pts, pts[1:]):
		d = np.minimum(d, seg_d(u, v, p, q))
	return w * 0.5 - d


def star_pts(n, r_out, r_in, turn=math.pi / 2):
	return [((r_out if i % 2 == 0 else r_in) * math.cos(turn + i * math.pi / n),
		(r_out if i % 2 == 0 else r_in) * math.sin(turn + i * math.pi / n)) for i in range(2 * n)]


def arc(c, r, a0, a1, n=24):
	return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


# --- The marks ---------------------------------------------------------------------------

def roundel(field, ring, mark):
	"""A disc, a ring in it and an eight-point sun at its middle."""
	sun = star_pts(8, 0.052, 0.027)
	def draw(u, v, s):
		return [(INK, cov(disc_sd(u, v, 0.108), s)), (field, cov(disc_sd(u, v, 0.103), s)),
			(ring, cov(ring_sd(u, v, 0.068, 0.089), s)), (mark, cov(poly_sd(u, v, sun), s))]
	return draw


def roundels(name, field, ring, mark):
	d = Decal()
	place(d, WING_UP, roundel(field, ring, mark))
	place(d, WING_LO, roundel(field, ring, mark))
	d.save(OUT + name + "_decal.png")


# The numerals, a unit tall about (0, 0), drawn as strokes.
DIGITS = {
	"5": [[(0.26, 0.5), (-0.24, 0.5), (-0.27, 0.06)] + arc((-0.03, -0.17), 0.33, 134, -140, 30)],
}


def number(text, r, disc, ink):
	"""`text` in a ringed disc of radius r."""
	h = r * 1.02
	def draw(u, v, s):
		out = [(ink, cov(disc_sd(u, v, r), s)), (disc, cov(disc_sd(u, v, r * 0.89), s))]
		x = -(len(text) - 1) * 0.36 * h
		for ch in text:
			for stroke in DIGITS[ch]:
				out.append((ink, cov(line_sd(u - x, v, stroke, 0.19 * h, h), s)))
			x += 0.72 * h
		return out
	return draw


def swift_pts():
	half = [(0.50, 0.0), (0.40, 0.055), (0.24, 0.07), (0.12, 0.19), (-0.08, 0.40), (-0.36, 0.56),
		(-0.22, 0.33), (-0.15, 0.13), (-0.32, 0.065), (-0.66, 0.17), (-0.44, 0.0)]
	return half + [(x, -y) for x, y in reversed(half[1:-1])]


def swift(k, fill, line):
	def draw(u, v, s):
		sd = poly_sd(u, v, swift_pts(), k)
		return [(line, cov(sd + 0.0045, s)), (fill, cov(sd, s))]
	return draw


BOLT = [(-0.50, 0.11), (0.06, 0.21), (-0.02, 0.045), (0.52, -0.17), (-0.15, -0.085), (-0.07, 0.075)]
PENNANT = [(0.5, 0.2), (-0.5, 0.075), (-0.37, 0.0), (-0.5, -0.075), (0.5, -0.2)]


def laurel(r):
	"""Two sprays of leaves round a ring of radius r, open at the top, tied
	at the foot."""
	def draw(u, v, s):
		sd = np.full(u.shape, -9.0, dtype=np.float32)
		for side in (-1.0, 1.0):
			for k in range(7):
				ang = math.radians(270.0 + side * (16.0 + k * 21.0))
				cx, cy = r * math.cos(ang), r * math.sin(ang)
				# The leaf's long way: along the ring, upward, leaning out.
				t = ang + side * math.radians(90.0 - 28.0)
				lu = (u - cx) * math.cos(t) + (v - cy) * math.sin(t)
				lv = -(u - cx) * math.sin(t) + (v - cy) * math.cos(t)
				ln, wd = r * 0.27, r * 0.105
				# A pointed leaf: an ellipse's distance, near enough at this size.
				q = np.hypot(lu / ln, lv / wd)
				sd = np.maximum(sd, (1.0 - q) * wd)
			sd = np.maximum(sd, line_sd(u, v, arc((0.0, 0.0), r, 270.0 + side * 6.0, 270.0 + side * 140.0, 20), r * 0.045))
		tie = np.maximum(disc_sd(u, v, r * 0.085, (0.0, -r)), line_sd(u, v, [(-r * 0.16, -r * 1.2), (0.0, -r), (r * 0.16, -r * 1.2)], r * 0.06))
		sd = np.maximum(sd, tie)
		return [(INK, cov(sd + 0.003, s)), (GOLD, cov(sd, s))]
	return draw


def make_roundel_ember():
	roundels("roundel_ember", CREAM, RED, INK)


def make_roundel_tide():
	roundels("roundel_tide", NAVY, CREAM, GOLD)


def make_roundel_meadow():
	roundels("roundel_meadow", GREEN, GOLD, CREAM)


def make_number_5():
	d = Decal()
	place(d, SIDE, number("5", 0.066, CREAM, INK), read=True)
	place(d, RUDDER, number("5", 0.034, CREAM, INK), read=True)
	d.save(OUT + "number_5_decal.png")


def make_flash():
	# The fin and rudder dark, three bars up them leaning with the fin's
	# leading edge.
	d = Decal()
	d.rect("fin", INK, (0.4, 0.8), (0.0, 0.35))
	def draw(u, v, s):
		t = -u - 0.53 * v          # aft of the bars' middle, along the lean
		return [(c, cov(0.0125 - np.abs(t - at), s)) for c, at in ((GOLD, -0.034), (CREAM, 0.0), (RED, 0.034))]
	place(d, ("fin", (0.7, 0.168)), draw)
	d.save(OUT + "flash_decal.png")


def make_streamer():
	# A swallow-tailed pennant streaming aft along the fuselage's side, over
	# its number and name.
	d = Decal()
	k = 0.3
	def draw(u, v, s):
		sd = poly_sd(u, v, PENNANT, k)
		return [(CREAM, cov(sd + 0.005, s)), (NAVY, cov(sd, s)), (CREAM, cov(np.minimum(sd, u - 0.3 * k), s)),
			(GOLD, cov(np.minimum(sd, disc_sd(u, v, 0.08 * k, (0.05 * k, 0.0))), s)),
			(GOLD, cov(np.minimum(sd, 0.004 - np.abs(u - 0.27 * k)), s))]
	place(d, ("body", (0.19, 1.2)), draw)
	d.save(OUT + "streamer_decal.png")


def make_star():
	d = Decal()
	def star(r):
		pts = star_pts(5, r, r * 0.42)
		def draw(u, v, s):
			sd = poly_sd(u, v, pts)
			return [(INK, cov(sd + 0.006, s)), (GOLD, cov(sd, s))]
		return draw
	place(d, WING_MID, star(0.1))
	place(d, CONE, star(0.05))
	d.save(OUT + "star_decal.png")


def make_bolt():
	# A bolt out along each half of the upper wing, and one struck forward
	# down the tail cone.
	d = Decal()
	def bolt(k, turn=0.0):
		def draw(u, v, s):
			sd = poly_sd(u, v, BOLT, k)
			return [(INK, cov(sd + 0.0055, s)), (GOLD, cov(sd, s))]
		return draw
	place(d, ("up_top", (0.215, 0.15)), bolt(0.27))
	place(d, ("body", (0.53, 1.18)), bolt(0.2))
	d.save(OUT + "bolt_decal.png")


def make_compass():
	# A compass rose over the upper wing's centre: north to the nose.
	d = Decal()
	long_, short = star_pts(4, 0.128, 0.03), star_pts(4, 0.078, 0.026, math.pi / 4)
	north = [(0.0, 0.128), (0.0212, 0.0212), (-0.0212, 0.0212)]
	def draw(u, v, s):
		a, b = poly_sd(u, v, long_), poly_sd(u, v, short)
		both = np.maximum(a, b)
		return [(INK, cov(np.maximum(both + 0.005, ring_sd(u, v, 0.083, 0.098)), s)),
			(CREAM, cov(ring_sd(u, v, 0.087, 0.094), s)), (INK, cov(both + 0.005, s)),
			(GOLD, cov(b, s)), (CREAM, cov(a, s)), (RED, cov(np.minimum(a, poly_sd(u, v, north)), s)),
			(INK, cov(disc_sd(u, v, 0.012), s))]
	place(d, WING_MID, draw)
	d.save(OUT + "compass_decal.png")


def make_swift():
	# A swift over the upper wing's centre, flying the plane's way, and one
	# in a disc over the fuselage's number and on the rudder.
	d = Decal()
	place(d, WING_MID, swift(0.2, INK, CREAM), turn=math.radians(90.0))
	def badge(r):
		def draw(u, v, s):
			c, n = math.cos(0.3), math.sin(0.3)
			return [(INK, cov(disc_sd(u, v, r), s)), (CREAM, cov(disc_sd(u, v, r * 0.89), s)),
				(INK, cov(poly_sd(u * c + v * n, v * c - u * n, swift_pts(), r * 1.38), s))]
		return draw
	place(d, SIDE, badge(0.066))
	place(d, RUDDER, badge(0.034))
	d.save(OUT + "swift_decal.png")


def make_laurel():
	# A wreath round the plane's own number on the fuselage's sides.
	d = Decal()
	place(d, SIDE, laurel(0.064))
	d.save(OUT + "laurel_decal.png")


MAKERS = {n[5:]: f for n, f in list(globals().items()) if n.startswith("make_")}
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for _name, _make in MAKERS.items():
	if not ONLY or _name in ONLY:
		_make()

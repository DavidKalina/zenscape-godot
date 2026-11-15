"""The hero plane's painted atlas, in numpy (hero_plane_build.py runs it).

No photographs. Each region of the atlas (the build's REG) is painted in its own
toy-unit coordinates, as a real one is: bare skin or cloth, primer, the livery's
coats with panel seams and rib tape under them, then the wear: rubbed edges where
hands go, chips along leading edges, exhaust soot laid back by the wind, oil from
the engine's belly, dust and streaks along the airflow.

Maps: albedo (the plane's own colours, sRGB numbers), a height map for the
normal, `mask` (body, trim, wing, dark livery shares) and `orm` (roughness, metal,
lacquer). A chip or a soot stain lowers the mask, so a livery can't paint over it.
"""
import math

import numpy as np

K = {}          # the build's constants

# A bake's settings (hero_plane_bake.py, a skin's own atlas): the build paints
# with these defaults, which leave its atlas as it was.
BAKE_DEFAULTS = {
	"WEAR": 1.0,      # chips: 0 factory fresh, 1 the plane's own, 2 battered
	"DIRT": 1.0,      # soot, oil, dust and streaks: 0 clean, 2 filthy
	"BARE": 0.0,      # the livery's coat off the metal (body forward, cowl), 0..1
	"BARE_C": None,   # the bared metal's colour (None: aluminium)
	"RUST": 0.0,      # chips on metal rust, and rust runs back from them, 0..1
	"RUST_C": None,   # the corrosion's colour (None: rust; a verdigris for copper)
	"CLOTH": "doped", # the wings' and tail's cloth: doped (cream, takes the wing
	                  # colour), silver (aluminium dope, takes no livery) or bare
	                  # (skinned in the bared metal, BARE_C, like the body aft)
}


def chipped(x, a, b):
	"""The wear's threshold: sst(a, b, x) at WEAR 1, fewer chips below, more above."""
	w = K["WEAR"]
	if w <= 1.0:
		return sst(a, b, x) * w
	d = (w - 1.0) * 0.08
	return sst(a - d, b - d, x)


def bare_metal(p):
	"""Bared metal, polished along the airflow (BARE_C, or aluminium)."""
	c = np.array(K["BARE_C"] if K["BARE_C"] is not None else K["ALU_C"], dtype=np.float32)
	tone = 1.0 + (p.along - 0.5) * 0.22 + (p.big - 0.5) * 0.12
	return np.broadcast_to(c, p.col.shape) * tone[..., None]


RUST_C = np.array((0.36, 0.17, 0.08), dtype=np.float32)
def rust_c():
	return np.array(K["RUST_C"] if K["RUST_C"] is not None else RUST_C, dtype=np.float32)


SILVER_C = np.array((0.7, 0.7, 0.68), dtype=np.float32)


def silver_cloth(p, t=None):
	"""CLOTH silver: the cloth doped in aluminium, by t (all of it by default);
	CLOTH bare: skinned in the bared metal instead."""
	if K["CLOTH"] not in ("silver", "bare"):
		return
	t = np.ones(p.col.shape[:2], dtype=np.float32) if t is None else t
	if K["CLOTH"] == "bare":
		p.lay(bare_metal(p), t, None, 0.24, 0.35, 1.0)
		return
	tone = 1.0 + (p.big - 0.5) * 0.1 + (p.mid - 0.5) * 0.06
	p.lay(SILVER_C * tone[..., None], t, None, 0.45, 0.25, 0.55)


def rusted(p, t):
	"""Rust where metal shows under chips: t is the chips' share."""
	r = K["RUST"]
	if r <= 0.0:
		return
	c = rust_c()
	p.lay(c * (0.8 + 0.4 * p.fine[..., None]), np.clip(t * r, 0.0, 1.0), None, 0.9, 0.0, 0.15)
	# Runs: back along the wind from each chip.
	run = blur(t, 6.0) * 3.0 * sst(0.45, 0.75, p.along)
	p.stain(c * 0.85, np.clip(run * r * 0.6, 0.0, 0.7), 0.85)


# --- Tools --------------------------------------------------------------------

def spectral(h, w, beta, seed, sx=1.0, sy=1.0):
	"""Noise 0..1 about 0.5, 1/f^beta; sx > 1 stretches it along x."""
	rng = np.random.default_rng(seed)
	f = np.fft.rfft2(rng.standard_normal((h, w)).astype(np.float32))
	fy = np.fft.fftfreq(h)[:, None] * h / max(h, w) * sy
	fx = np.fft.rfftfreq(w)[None, :] * w / max(h, w) * sx
	r = np.sqrt(fx * fx + fy * fy)
	r[0, 0] = 1e9
	out = np.fft.irfft2(f / (r ** beta), s=(h, w))
	out = (out - out.mean()) / (out.std() + 1e-9)
	return np.clip(out * 0.2 + 0.5, 0.0, 1.0).astype(np.float32)


def blur(a, px):
	h, w = a.shape
	fy = np.fft.fftfreq(h)[:, None]
	fx = np.fft.rfftfreq(w)[None, :]
	g = np.exp(-2.0 * (math.pi * px) ** 2 * (fx * fx + fy * fy))
	return np.fft.irfft2(np.fft.rfft2(a) * g, s=(h, w)).astype(np.float32)


def sst(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def over(a, b, t):
	"""b over a by t (a colour or an array of them)."""
	return a * (1.0 - t[..., None]) + b * t[..., None]


def band(x, a, b, soft=0.001):
	return sst(a - soft, a + soft, x) * (1.0 - sst(b - soft, b + soft, x))


def dots(a, b, pitch_a, pitch_b, r):
	"""A lattice of round dots; a and b in the same units. 0..1."""
	da = (a / pitch_a + 0.5) % 1.0 - 0.5
	db = (b / pitch_b + 0.5) % 1.0 - 0.5
	d = np.sqrt((da * pitch_a) ** 2 + (db * pitch_b) ** 2)
	return 1.0 - sst(r * 0.7, r * 1.15, d)


FONT = {
	"0": "01110 10001 10011 10101 11001 10001 01110", "1": "00100 01100 00100 00100 00100 00100 01110",
	"2": "01110 10001 00001 00110 01000 10000 11111", "3": "11110 00001 00001 01110 00001 00001 11110",
	"4": "00010 00110 01010 10010 11111 00010 00010", "5": "11111 10000 11110 00001 00001 10001 01110",
	"6": "00110 01000 10000 11110 10001 10001 01110", "7": "11111 00001 00010 00100 01000 01000 01000",
	"8": "01110 10001 10001 01110 10001 10001 01110", "9": "01110 10001 10001 01111 00001 00010 01100",
	"A": "01110 10001 10001 11111 10001 10001 10001", "B": "11110 10001 10001 11110 10001 10001 11110",
	"C": "01111 10000 10000 10000 10000 10000 01111", "D": "11110 10001 10001 10001 10001 10001 11110",
	"E": "11111 10000 10000 11110 10000 10000 11111", "F": "11111 10000 10000 11110 10000 10000 10000",
	"G": "01111 10000 10000 10011 10001 10001 01111", "H": "10001 10001 10001 11111 10001 10001 10001",
	"I": "01110 00100 00100 00100 00100 00100 01110", "K": "10001 10010 10100 11000 10100 10010 10001",
	"L": "10000 10000 10000 10000 10000 10000 11111", "M": "10001 11011 10101 10101 10001 10001 10001",
	"N": "10001 11001 10101 10011 10001 10001 10001", "O": "01110 10001 10001 10001 10001 10001 01110",
	"P": "11110 10001 10001 11110 10000 10000 10000", "R": "11110 10001 10001 11110 10100 10010 10001",
	"S": "01111 10000 10000 01110 00001 00001 11110", "T": "11111 00100 00100 00100 00100 00100 00100",
	"U": "10001 10001 10001 10001 10001 10001 01110", "V": "10001 10001 10001 10001 10001 01010 00100",
	"W": "10001 10001 10001 10101 10101 11011 10001", "X": "10001 10001 01010 00100 01010 10001 10001",
	"Y": "10001 10001 01010 00100 00100 00100 00100", "-": "00000 00000 00000 11111 00000 00000 00000",
	".": "00000 00000 00000 00000 00000 01100 01100", " ": "00000 00000 00000 00000 00000 00000 00000",
}


def text_bits(s, cell):
	"""A 0..1 stamp of `s`, each font pixel `cell` px, softened a touch."""
	rows = []
	for r in range(7):
		line = []
		for ch in s:
			line.append(np.array([int(c) for c in FONT[ch].split()[r]], dtype=np.float32))
			line.append(np.zeros(1, dtype=np.float32))
		rows.append(np.concatenate(line))
	bits = np.stack(rows)
	bits = np.kron(bits, np.ones((cell, cell), dtype=np.float32))
	return bits


class Canvas:
	def __init__(self):
		h, w = K["AH"], K["AW"]
		self.a = np.zeros((h, w, 3), dtype=np.float32)
		self.h = np.zeros((h, w), dtype=np.float32)
		self.r = np.full((h, w), 0.7, dtype=np.float32)
		self.m = np.zeros((h, w), dtype=np.float32)
		self.c = np.zeros((h, w), dtype=np.float32)
		self.k = np.zeros((h, w, 4), dtype=np.float32)
		self.big = spectral(h, w, 1.5, 11)
		self.mid = spectral(h, w, 1.05, 12)
		self.fine = spectral(h, w, 0.7, 13)
		self.along = spectral(h, w, 1.05, 14, sx=0.14, sy=1.0)    # streaks running along x
		self.across = spectral(h, w, 1.05, 15, sx=1.0, sy=0.14)   # streaks running along y
		self.chip = spectral(h, w, 1.0, 16)


class Part:
	"""A region's window: its own colour, height, rough, metal, lacquer and mask."""

	def __init__(self, cv, name=None, rect=None):
		self.cv = cv
		x, y, w, h = rect or K["REG"][name]
		self.s = (slice(y, y + h), slice(x, x + w))
		self.w, self.h_ = w, h
		self.yy, self.xx = np.mgrid[0:h, 0:w].astype(np.float32)
		self.col = np.zeros((h, w, 3), dtype=np.float32)
		self.hgt = np.zeros((h, w), dtype=np.float32)
		self.rgh = np.full((h, w), 0.7, dtype=np.float32)
		self.met = np.zeros((h, w), dtype=np.float32)
		self.coat = np.zeros((h, w), dtype=np.float32)
		self.mk = np.zeros((h, w, 4), dtype=np.float32)
		for n in ("big", "mid", "fine", "along", "across", "chip"):
			setattr(self, n, getattr(cv, n)[self.s])

	def lay(self, colour, t, slot=None, rough=None, coat=None, metal=None):
		"""A coat of `colour` over what's there by t; it takes over the mask."""
		self.col = over(self.col, np.broadcast_to(colour, self.col.shape), t)
		keep = (1.0 - t)[..., None]
		self.mk *= keep
		if slot is not None:
			self.mk[..., slot] += t
		if rough is not None:
			self.rgh = self.rgh * (1.0 - t) + rough * t
		if coat is not None:
			self.coat = self.coat * (1.0 - t) + coat * t
		if metal is not None:
			self.met = self.met * (1.0 - t) + metal * t

	def stain(self, colour, t, rough=None):
		"""Dirt on the paint: colours it and leaves the mask at a lower share, so
		a livery shows through a light stain and not a heavy one."""
		if K["DIRT"] != 1.0:
			t = np.clip(t * K["DIRT"], 0.0, 1.0)
		self.col = over(self.col, np.broadcast_to(colour, self.col.shape), t)
		self.mk *= (1.0 - t * 0.85)[..., None]
		if rough is not None:
			self.rgh = self.rgh * (1.0 - t) + rough * t
		self.coat *= 1.0 - t * 0.8

	def shade(self, k):
		"""A multiply on the paint alone (tone variation); the mask holds."""
		self.col = self.col * k[..., None]

	def text(self, s, x, y, cell, colour, slot=None, flip_x=False, flip_y=False, strength=0.92, emboss=0.0):
		bits = text_bits(s, cell)
		if flip_x:
			bits = bits[:, ::-1]
		if flip_y:
			bits = bits[::-1]
		h, w = bits.shape
		x0, y0 = int(x - w * 0.5), int(y - h * 0.5)
		t = np.zeros((self.h_, self.w), dtype=np.float32)
		ys = slice(max(y0, 0), min(y0 + h, self.h_))
		xs = slice(max(x0, 0), min(x0 + w, self.w))
		t[ys, xs] = bits[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0]
		# Worn stencil: the paint breaks up a little.
		t *= strength * (0.8 + 0.2 * sst(0.3, 0.55, self.chip))
		self.lay(colour, t, slot)
		self.hgt += t * emboss

	def store(self):
		c = self.cv
		c.a[self.s] = np.clip(self.col, 0.0, 1.0)
		c.h[self.s] = self.hgt
		c.r[self.s] = self.rgh
		c.m[self.s] = self.met
		c.c[self.s] = self.coat
		c.k[self.s] = np.clip(self.mk, 0.0, 1.0)


def weave(a, b, pitch):
	return (np.sin(a * math.tau / pitch) * np.sin(b * math.tau / pitch)) * 0.5 + 0.5


# --- Wings --------------------------------------------------------------------

def paint_wing(cv, reg, top, upper):
	p = Part(cv, reg)
	half = (K["SPAN"] if upper else K["LOWER_SPAN"]) * 0.5
	ribs = K["RIBS_UP"] if upper else K["RIBS_LO"]
	D, CHORD = K["D"], K["CHORD"]
	a = (p.xx - 6.0) / D                 # out along the span
	b = (p.yy - 10.0) / D                # back along the chord
	c = b / CHORD
	pitch = half / ribs
	rib = np.abs(((a / pitch + 0.5) % 1.0) - 0.5) * pitch   # m from the nearest rib
	bay = (a % pitch) / pitch
	tip = half * K["TIP_FROM"]
	WING = K["WING_C"]

	# The cloth: tautened, doped, faintly gold where the dope pooled; warmer
	# under. The cream stays the plane's cream; the tone moves round it.
	p.col[:] = WING
	p.mk[..., 2] = 1.0
	p.rgh[:] = 0.62
	p.coat[:] = 0.32 if top else 0.18
	tone = 1.0 + (p.big - 0.5) * 0.11 + (p.mid - 0.5) * 0.07
	p.shade(tone)
	p.col = over(p.col, np.array((0.87, 0.76, 0.55), dtype=np.float32), sst(0.5, 0.75, p.big) * 0.22)
	silver_cloth(p)
	if not top:
		p.shade(np.full_like(a, 0.95))
	# The bays go slack and catch shade toward their middles: the ribs read as
	# drawn lines at a distance. Cloth over the spar lines shows as a soft bar.
	slack = np.sin(bay * math.pi)
	p.shade(1.0 - 0.04 * slack * sst(0.1, 0.3, c))
	p.shade(1.0 + 0.04 * (band(c, 0.26, 0.32, 0.02) + band(c, 0.62, 0.68, 0.02)) * (1.0 - slack * 0.5))
	p.hgt += 0.9 * (1.0 - slack) + weave(a, b, 0.0034) * 0.09 + (p.fine - 0.5) * 0.25
	# Rib tape, pinked edged, sewn: a band a little brighter with stitches down it.
	tape = 1.0 - sst(0.0058, 0.0074, rib + (p.fine - 0.5) * 0.002)
	p.shade(1.0 + tape * 0.05)
	p.hgt += tape * 1.3
	stitch = dots(rib, b, 0.2, 0.0115, 0.0016) * tape
	p.shade(1.0 - stitch * 0.34)
	p.hgt -= stitch * 0.9
	# The nose sheet and tapes: the ply forward of the spar, its edge taped, and
	# a line of pins down it.
	nose = 1.0 - sst(0.125, 0.135, c)
	p.shade(1.0 + nose * 0.03)
	p.hgt += nose * 0.7
	te_tape = band(c, 0.122, 0.142, 0.002)
	p.shade(1.0 + te_tape * 0.05)
	p.hgt += te_tape * 0.7
	pin = dots(a, b - 0.11 * CHORD, 0.0145, 10.0, 0.0017)
	p.shade(1.0 - pin * nose * 0.3)
	back = sst(0.955, 0.965, c)
	p.shade(1.0 + back * 0.05)
	p.hgt += back * 0.7
	# The aileron's slot.
	if upper:
		ail = band(a, K["AIL"][0], K["AIL"][1], 0.0006)
		h = K["AIL_H"]
		slot = band(c, h - 0.006, h + 0.012, 0.002) * ail
		p.lay(np.array((0.08, 0.075, 0.07), dtype=np.float32), slot, None, 0.8, 0.0)
		p.hgt -= slot * 2.2
		p.shade(1.0 - band(c, h + 0.012, h + 0.05, 0.01) * ail * 0.05)
		for ax in K["AIL"]:
			p.lay(np.array((0.3, 0.27, 0.23), dtype=np.float32), (1.0 - sst(0.0009, 0.0016, np.abs(a - ax))) * sst(h - 0.01, h, c), None)
		# Hinges: three small plates.
		for q in (0.12, 0.5, 0.88):
			ax = K["AIL"][0] + (K["AIL"][1] - K["AIL"][0]) * q
			hinge = band(a, ax - 0.012, ax + 0.012, 0.001) * band(c, h - 0.03, h + 0.03, 0.003)
			p.lay(K["ALU_C"] * 0.8, hinge, None, 0.5, 0.0, 0.8)
			p.hgt += hinge * 1.3
	# Tips: the trim, cut square at a rib with a thin cream gap.
	cut = half * 0.82
	tipped = sst(cut, cut + 0.0015, a)
	p.lay(K["TRIM_C"], tipped, 1, 0.5, 0.45)
	p.shade(1.0 + (p.mid - 0.5) * 0.26 * tipped)
	stripe = band(a, cut - 0.03, cut - 0.015, 0.001)
	p.lay(K["BODY_C"], stripe, 0, 0.5, 0.45)
	# Roundels: on the upper wing's top, the lower wing's underside.
	if top == upper:
		rx, rz = (0.46, 0.5 * CHORD) if upper else (0.42, 0.5 * CHORD)
		r = np.sqrt((a - rx) ** 2 + (b - rz) ** 2)
		p.lay(K["WING_C"], 1.0 - sst(0.1, 0.1012, r), 2)
		p.lay(K["TRIM_C"], 1.0 - sst(0.093, 0.0942, r), 1, 0.5, 0.45)
		p.lay(K["WING_C"], 1.0 - sst(0.06, 0.0612, r), 2)
		p.lay(K["BODY_C"], 1.0 - sst(0.037, 0.0382, r), 0, 0.5, 0.45)
	# The walkway on the lower wing's root: a dark non-slip board, scuffed.
	if not upper and top:
		walk = band(a, 0.09, 0.2, 0.0015) * band(c, 0.2, 0.72, 0.006)
		p.lay(K["DARK_C"], walk, 3, 0.95, 0.0)
		p.shade(1.0 + walk * (p.fine - 0.5) * 0.6)
		p.hgt += walk * (0.6 + (p.fine - 0.5) * 3.0)
		scuff = walk * sst(0.42, 0.7, p.mid * 0.6 + p.across * 0.4)
		p.stain(K["DUST_C"], scuff * 0.75)
	# Repair patches: a couple a wing, doped on a shade off.
	rng = np.random.default_rng((1 if upper else 2) * (3 if top else 5))
	for _ in range(2):
		ca, cb = rng.uniform(0.1, half * 0.76), rng.uniform(0.22, 0.86) * CHORD
		w, h = rng.uniform(0.016, 0.034), rng.uniform(0.012, 0.03)
		d = np.maximum(np.abs(a - ca) - w, np.abs(b - cb) - h)
		t = 1.0 - sst(-0.0012, 0.0006, d)
		p.shade(1.0 + t * rng.uniform(-0.05, 0.03))
		p.hgt += t * 0.8
		p.shade(1.0 - (1.0 - sst(0.0, 0.0012, np.abs(d))) * 0.08)
	# Wear: chips at the nose to primer and bare wood, rubbed tape.
	nose_edge = 1.0 - sst(0.01, 0.06, c)
	chips = chipped(p.chip + nose_edge * 0.22 + (p.fine - 0.5) * 0.3, 0.62, 0.68) * (0.15 + nose_edge)
	chips = np.clip(chips, 0.0, 1.0) * sst(0.5, 0.75, nose_edge + (p.chip > 0.72) * 0.4)
	p.lay(K["PRIMER_C"], chips * 0.9, None, 0.85, 0.0)
	# The wind's dirt: long streaks back the chord, heavier aft of the spar;
	# dust in the slack of the bays; a sun-pale over the top.
	streak = sst(0.5, 0.8, p.across) * (0.3 + 0.7 * sst(0.1, 0.9, c))
	p.stain(K["DUST_C"], streak * (0.16 if top else 0.2))
	p.stain(np.array((0.2, 0.15, 0.1), dtype=np.float32), sst(0.56, 0.82, p.across * 0.7 + p.big * 0.3) * (0.12 if top else 0.16))
	p.stain(K["DUST_C"], slack * sst(0.45, 0.8, p.mid) * 0.14)
	if not top:
		# Under: the engine's oil and soot thrown back down the root, thrown mud
		# from the wheels on the lower wing.
		root = 1.0 - sst(0.09, 0.34, a)
		p.stain(K["OIL_C"], root * sst(0.42, 0.75, p.across) * 0.45)
		p.stain(K["SOOT_C"], root * sst(0.48, 0.78, p.across * 0.6 + p.mid * 0.4) * 0.3)
		if not upper:
			spray = (1.0 - sst(0.03, 0.17, np.abs(a - K["WHEEL_X"]))) * sst(0.2, 0.9, c)
			spots = sst(0.62, 0.74, p.fine * 0.7 + p.mid * 0.3)
			p.stain(np.array((0.26, 0.2, 0.13), dtype=np.float32), spray * (0.3 + spots * 0.6))
	else:
		p.col = over(p.col, np.array((0.97, 0.94, 0.86), dtype=np.float32), sst(0.5, 0.7, p.big) * 0.1 * p.mk[..., 2])
	p.store()


# --- The body -----------------------------------------------------------------

def paint_body(cv):
	p = Part(cv, "body")
	W, H = p.w, p.h_
	Z0 = -0.5
	f = 2190.0
	z = (p.xx - 8.0) / f + Z0
	th = (p.yy - 8.0) / (H - 16.0) * math.tau
	phi = (th + math.pi) % math.tau - math.pi          # 0 on top, +- pi the keel, + the right
	aphi = np.abs(phi)
	r = np.interp(z, [b[0] for b in K["BODY"]], [max(b[1], (b[2] - b[3]) * 0.5) for b in K["BODY"]]).astype(np.float32)
	s = phi * r                                         # m round from the top
	metal = 1.0 - sst(K["FABRIC_FROM"] - 0.0015, K["FABRIC_FROM"] + 0.0015, z)
	fabric = 1.0 - metal
	# Under it all: aluminium forward, grey primer'd cloth aft.
	p.col[:] = K["ALU_C"]
	p.rgh[:] = 0.42
	p.met[:] = metal
	# The livery: body colour, deep and uneven, thinner where it was brushed out.
	p.lay(K["BODY_C"], np.ones_like(z), 0, 0.46, 0.55, 0.0)
	p.shade(1.0 + (p.big - 0.5) * 0.2 + (p.mid - 0.5) * 0.12)
	p.col = over(p.col, np.array((0.78, 0.45, 0.28), dtype=np.float32), sst(0.5, 0.8, p.big) * 0.2)
	p.col = over(p.col, np.array((0.56, 0.24, 0.16), dtype=np.float32), sst(0.5, 0.8, 1.0 - p.mid) * 0.14)
	if K["BARE"] > 0.0:
		skin = metal + fabric * (K["CLOTH"] == "bare")
		p.lay(bare_metal(p), skin * K["BARE"], None, 0.22, 0.35, 1.0)

	# Metal: panel seams, rivets and access plates.
	seams_z = (-0.44, -0.33, -0.22, -0.11, K["FABRIC_FROM"])
	seam = np.zeros_like(z)
	riv = np.zeros_like(z)
	for sz in seams_z:
		d = np.abs(z - sz)
		seam = np.maximum(seam, 1.0 - sst(0.0006, 0.0014, d))
		for off in (-0.0058, 0.0058):
			riv = np.maximum(riv, dots(z - sz - off, s, 10.0, 0.0105, 0.0017))
	for ph in (0.72, 1.55, 2.35):
		d = np.abs(aphi - ph) * r
		seam = np.maximum(seam, (1.0 - sst(0.0006, 0.0014, d)))
		for off in (-0.0058, 0.0058):
			riv = np.maximum(riv, dots(z, (aphi - ph) * r - off, 0.0105, 10.0, 0.0017))
	seam *= metal
	riv *= metal
	p.hgt += metal * ((sst(-0.16, 0.16, np.sin(z * 90.0)) * 0.12))
	# Each panel oil-canned a little: a soft dome between the seams.
	p.hgt += metal * (blur_dome(z, s, seams_z)) * 1.2
	p.shade(1.0 - seam * 0.62)
	p.hgt -= seam * 2.4
	p.shade(1.0 + riv * 0.16)
	p.hgt += riv * 1.6
	if K["RUST"] > 0.0:
		# Corrosion gathered in the seams and round the rivets, a little run aft.
		gather = np.clip(blur(np.maximum(seam, riv), 4.0) * 3.0, 0.0, 1.0)
		gather *= 0.55 + 0.45 * sst(0.35, 0.65, p.fine)
		p.lay(rust_c() * (0.85 + 0.3 * p.fine[..., None]), gather * K["RUST"], None, 0.8, 0.0, 0.1)
	# Rivet halos: paint rubbed thin round each head.
	halo = riv * chipped(p.chip + (1.0 - sst(-0.33, 0.1, z)) * 0.08, 0.5, 0.72) * 0.8
	p.lay(K["ALU_C"], halo, None, 0.4, 0.0, 1.0)
	# Hatches: oil tank, battery, tool locker, with dzus fasteners.
	for (cz, cs, wz, ws) in ((-0.27, 0.115, 0.04, 0.03), (-0.165, -0.115, 0.03, 0.026), (-0.27, -0.115, 0.04, 0.03), (-0.165, 0.115, 0.03, 0.026)):
		dd = np.maximum(np.abs(z - cz) - wz, np.abs(s - cs) - ws)
		line = (1.0 - sst(0.0005, 0.0013, np.abs(dd))) * metal
		p.shade(1.0 - line * 0.65)
		p.hgt -= line * 2.2
		p.hgt += (1.0 - sst(-0.0015, 0.0, dd)) * metal * 0.5
		for az, bs in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
			fz, fs = cz + az * (wz - 0.006), cs + bs * (ws - 0.006)
			rr = np.sqrt((z - fz) ** 2 + (s - fs) ** 2)
			head = 1.0 - sst(0.0028, 0.0036, rr)
			p.lay(K["ALU_C"] * 0.9, head, None, 0.35, 0.0, 1.0)
			p.hgt += head * 1.4
			slot_ = head * (1.0 - sst(0.0004, 0.0008, np.abs(z - fz + (s - fs)) * 0.7))
			p.shade(1.0 - slot_ * 0.75)
			p.hgt -= slot_ * 1.5
	# Fabric aft: tape along each stringer, faint formers, belly lacing, patches.
	n = K["BODY_STRINGERS"]
	bay = (th / (math.tau / n)) % 1.0
	dist = np.abs(bay - 0.0) * (math.tau / n) * r
	dist = np.minimum(dist, np.abs(1.0 - bay) * (math.tau / n) * r)
	tape = (1.0 - sst(0.0042, 0.0056, dist + (p.fine - 0.5) * 0.0015)) * fabric
	slack = np.sin(bay * math.pi) * fabric
	p.shade(1.0 - slack * 0.04)
	p.shade(1.0 + tape * 0.05)
	p.hgt += tape * 1.1 + fabric * (weave(z, s, 0.0034) * 0.1 + (p.fine - 0.5) * 0.25)
	former = (1.0 - sst(0.0032, 0.0046, np.abs(((z - 0.02) / 0.084 + 0.5) % 1.0 - 0.5) * 0.084)) * fabric
	p.shade(1.0 + former * 0.05)
	p.hgt += former * 0.8
	lace = (1.0 - sst(0.0026, 0.0036, np.abs(aphi - math.pi) * r)) * fabric
	cross = dots(z, (aphi - math.pi) * r, 0.0085, 10.0, 0.0028) * fabric * (1.0 - sst(0.003, 0.0045, np.abs(aphi - math.pi) * r))
	p.shade(1.0 - cross * 0.4)
	p.hgt += lace * 0.7 + cross * 1.0
	# The join: a metal strip with a rivet row where the cloth starts.
	strip = band(z, K["FABRIC_FROM"] - 0.005, K["FABRIC_FROM"] + 0.018, 0.0006)
	p.lay(K["BODY_C"] * 0.95, strip, 0, 0.42, 0.5, 0.0)
	p.hgt += strip * 1.2
	p.hgt += dots(z - K["FABRIC_FROM"] - 0.007, s, 10.0, 0.0115, 0.0018) * strip * 1.5
	# Inspection rings along the flank's cloth.
	for cz, sign in ((0.18, 1.0), (0.3, -1.0), (0.46, 1.0), (0.54, -1.0)):
		rr = np.sqrt((z - cz) ** 2 + (s - sign * 0.075) ** 2)
		ring = (1.0 - sst(0.012, 0.0132, rr)) * sst(0.0086, 0.0098, rr)
		p.lay(K["ALU_C"] * 0.85, ring, None, 0.5, 0.0, 0.7)
		p.hgt += ring * 1.4
		p.shade(1.0 - (1.0 - sst(0.0, 0.0098, rr)) * 0.05)

	# The scheme. A dark deck ahead of the screen; the cheat line down the flank,
	# a cream pinstripe over it, the trim round the tail, the cockpit's well.
	deck = (1.0 - sst(-0.03, -0.028, z)) * (1.0 - sst(0.46, 0.47, aphi))
	p.lay(K["DARK_C"], deck, 3, 0.74, 0.08, 0.0)
	line_top = np.interp(z, [-0.5, 0.0, 0.3, 0.72], [1.5, 1.58, 1.66, 1.7]).astype(np.float32)
	line_w = np.interp(z, [-0.5, 0.0, 0.3, 0.72], [0.34, 0.34, 0.3, 0.2]).astype(np.float32)
	cheat = band(aphi, line_top, line_top + line_w, 0.006) * (1.0 - sst(0.335, 0.34, z))
	pin_ = (band(aphi, line_top - 0.065, line_top - 0.03, 0.005) + band(aphi, line_top + line_w + 0.03, line_top + line_w + 0.05, 0.005)) * (1.0 - sst(0.335, 0.34, z))
	p.lay(K["TRIM_C"], cheat, 1, 0.44, 0.55)
	p.lay(K["WING_C"], pin_, 2, 0.5, 0.45)
	# The rear in big plain blocks, for the chase: a wide cream band, then the
	# tail cone in the trim, running into the fin.
	block = sst(0.3385, 0.3415, z)
	p.lay(K["WING_C"], block, 2, 0.5, 0.45)
	cone = sst(0.4185, 0.4215, z)
	p.lay(K["TRIM_C"], cone, 1, 0.44, 0.55)
	p.shade(1.0 + block * ((p.big - 0.5) * 0.14 + (p.mid - 0.5) * 0.06))
	# Re-cut the seams through the scheme, since a coat doesn't hide them.
	p.shade(1.0 - seam * 0.3 * (deck + cheat * 1.0))
	# Cockpit well under the glass.
	well = band(z, -0.04, 0.37, 0.002) * (1.0 - sst(0.62, 0.64, aphi))
	p.lay(np.array((0.08, 0.09, 0.09), dtype=np.float32), well, 3, 0.9, 0.0)
	# Stencils and the number.
	bone = K["WING_C"]
	def on(side, z_at, a_phi):
		r_at = float(np.interp(z_at, [b[0] for b in K["BODY"]], [max(b[1], (b[2] - b[3]) * 0.5) for b in K["BODY"]]))
		col = 8.0 + (z_at - Z0) * f
		row = 8.0 + (a_phi if side > 0 else math.tau - a_phi) / math.tau * (H - 16.0)
		return col, row
	for side in (1.0, -1.0):
		fx, fy = side > 0, side < 0
		c, rw = on(side, 0.24, 1.2)
		p.text("27", c, rw, 15, bone, 2, fx, fy, 0.96, 0.5)
		c, rw = on(side, -0.27, 1.32)
		p.text("OIL 12 L", c, rw, 3, bone, 2, fx, fy, 0.85)
		c, rw = on(side, 0.02, 2.5)
		p.text("NO STEP", c, rw, 3, bone, 2, fx, fy, 0.85)
	c, rw = on(1.0, -0.165, 0.5 + 0.34)
	p.text("FUEL", c, rw, 3, bone, 2, True, False, 0.85)
	c, rw = on(-1.0, 0.09, 1.34)
	p.text("WANDERER", c, rw, 4, bone, 2, False, True, 0.85)
	c, rw = on(1.0, 0.09, 1.34)
	p.text("WANDERER", c, rw, 4, bone, 2, True, False, 0.85)
	c, rw = on(1.0, 0.56, 1.28)
	p.text("LIFT", c, rw, 3, bone, 2, True, False, 0.7)
	c, rw = on(-1.0, 0.56, 1.28)
	p.text("LIFT", c, rw, 3, bone, 2, False, True, 0.7)

	# Wear. Hands: the flank under the cockpit and round the step, rubbed to
	# bare skin in places, the paint chipped along every seam nearest to it.
	near = np.exp(-(((z - 0.03) / 0.12) ** 2)) * np.exp(-(((aphi - 1.45) / 0.55) ** 2))
	worn = chipped(p.chip + near * 0.2 + (p.fine - 0.5) * 0.25, 0.56, 0.66) * metal
	on_seam = np.maximum(blur(seam, 3.0) * 3.0, 0.0)
	chips = worn * np.clip(on_seam * 2.0 + near * 0.7, 0.0, 1.0) * sst(0.6, 0.7, p.chip + (p.fine - 0.5) * 0.3 + on_seam * 0.25)
	p.lay(K["ALU_C"], chips, None, 0.36, 0.0, 1.0)
	rusted(p, np.clip(chips + halo, 0.0, 1.0))
	p.stain(K["DUST_C"], near * sst(0.45, 0.8, p.mid) * 0.22)
	p.stain(K["SOOT_C"], near * sst(0.5, 0.8, p.fine) * 0.1)
	# The fabric's scrapes low on the tail, and the chafed keel.
	aft = sst(0.3, 0.68, z)
	p.stain(K["DUST_C"], aft * sst(1.9, 2.9, aphi) * sst(0.3, 0.7, p.along) * 0.3)
	# Exhaust: soot laid back from the stubs, thinning, climbing a little in the
	# wash. Three plumes a side, merging, gone by the tail.
	plume = np.zeros_like(z)
	for a0 in (1.85, 2.2, 2.55):
		climb = a0 - np.clip(z + 0.36, 0.0, 1.0) * 0.28
		spread = 0.1 + np.clip(z + 0.36, 0.0, 1.0) * 0.55
		plume = np.maximum(plume, np.exp(-((aphi - climb) / spread) ** 2) / (1.0 + np.clip(z + 0.36, 0.0, 1.0) * 2.2))
	plume *= sst(-0.40, -0.345, z) * (1.0 - sst(0.2, 0.62, z))
	soot = plume * (0.55 + 0.45 * sst(0.3, 0.75, p.along))
	p.stain(K["SOOT_C"], np.clip(soot * 0.7, 0.0, 0.65), 0.82)
	tan = plume * sst(0.45, 0.78, p.along * 0.6 + p.mid * 0.4)
	p.stain(np.array((0.3, 0.24, 0.18), dtype=np.float32), np.clip(tan * 0.2, 0.0, 0.3))
	# Oil: the belly, in long glossy runs from the sump.
	oil = sst(2.35, 3.0, aphi) * (1.0 - sst(-0.1, 0.4, z)) * sst(0.42, 0.68, p.along)
	p.stain(K["OIL_C"], np.clip(oil * 0.9, 0.0, 0.9), 0.3)
	# Runs under the fasteners and the rivets.
	drip = sst(0.62, 0.8, p.along) * metal * 0.08
	p.stain(np.array((0.18, 0.13, 0.1), dtype=np.float32), drip)
	# Sun: the cloth's top chalks a little.
	p.col = over(p.col, np.array((0.9, 0.72, 0.56), dtype=np.float32), fabric * (1.0 - sst(0.8, 1.5, aphi)) * sst(0.45, 0.75, p.big) * 0.12)
	p.store()


def blur_dome(z, s, seams):
	stops = np.array(seams, dtype=np.float32)
	idx = np.clip(np.searchsorted(stops, z), 1, len(stops) - 1)
	a = stops[idx - 1]
	b = stops[idx]
	q = np.clip((z - a) / (b - a), 0.0, 1.0)
	return np.sin(q * math.pi)


# --- The cowl -----------------------------------------------------------------

def paint_cowl(cv):
	p = Part(cv, "cowl")
	W, H = p.w, p.h_
	t = (p.xx - 6.0) / (W - 12.0) * math.tau
	q = (p.yy - 6.0) / (H - 12.0)           # 0 the lip's inside, 1 the skirt
	# The arc lengths along the profile.
	pr = K["COWL"]
	arc = [0.0]
	for a, b in zip(pr, pr[1:]):
		arc.append(arc[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
	arc = np.array(arc) / arc[-1]
	front = float(arc[7])
	p.col[:] = K["TRIM_C"]
	p.mk[..., 1] = 1.0
	p.rgh[:] = 0.4
	p.coat[:] = 0.62
	p.shade(1.0 + (p.big - 0.5) * 0.3 + (p.mid - 0.5) * 0.16)
	if K["BARE"] > 0.0:
		p.lay(bare_metal(p), np.full_like(q, K["BARE"]), None, 0.22, 0.35, 1.0)
	bay = math.tau / K["CYLINDERS"]
	# A polished brass lip.
	lip = sst(0.05, 0.08, q) * (1.0 - sst(front - 0.05, front - 0.04, q))
	brass = polished(p)
	p.col = over(p.col, brass, lip)
	p.mk *= (1.0 - lip)[..., None]
	p.met = p.met * (1.0 - lip) + lip
	p.rgh = p.rgh * (1.0 - lip) + 0.26 * lip
	p.coat = p.coat * (1.0 - lip) + 0.5 * lip
	# Inside: burnt dark.
	inside = 1.0 - sst(0.03, 0.08, q)
	p.lay(np.array((0.1, 0.09, 0.08), dtype=np.float32), inside, None, 0.8, 0.0)
	# Three panels, their seams, a latch line of fasteners along each; rows of
	# dzus heads round the skirt and behind the lip.
	cz = np.zeros_like(t)
	for k in range(3):
		a0 = (k + 0.5) * math.tau / 3.0
		d = np.abs((t - a0 + math.pi) % math.tau - math.pi) * 0.155
		ln = (1.0 - sst(0.0007, 0.0016, d)) * sst(0.26, 0.28, q)
		cz = np.maximum(cz, ln)
	p.shade(1.0 - cz * 0.7)
	p.hgt -= cz * 2.6
	u = t * 0.155
	for qq, pitch in ((0.94, 0.03), (0.44, 0.03)):
		d = dots(u, (q - qq) * 0.3, pitch, 10.0, 0.0034)
		p.lay(K["ALU_C"], d, None, 0.34, 0.0, 1.0)
		p.hgt += d * 1.4
		p.shade(1.0 - (1.0 - sst(0.0, 0.0011, np.abs((u / pitch + 0.5) % 1.0 - 0.5) * pitch)) * d * 0.7)
	# Louvres on the skirt, between the blisters: dark slits with raised lips.
	lou = np.zeros_like(t)
	for k in range(3):
		qk = 0.72 + 0.07 * k
		lou = np.maximum(lou, band(q, qk, qk + 0.018, 0.004))
	lou *= band(np.abs(((t / bay + 0.5) % 1.0) - 0.5), 0.2, 0.42, 0.01) * (1.0 - sst(1.2, 1.3, np.abs((t + math.pi) % math.tau - math.pi) - 0.75))
	p.shade(1.0 - lou * 0.85)
	p.hgt += (blur(lou, 3.0) * 2.2 - lou * 3.4) * 1.0
	# Chips along the skirt and the blisters' crowns; rubbed metal round fasteners.
	crown = np.exp(-(((t + bay * 0.5) % bay - bay * 0.5) / 0.14) ** 2) * band(q, 0.3, 0.6, 0.04)
	chips = chipped(p.chip + crown * 0.05 + sst(0.9, 1.0, q) * 0.1 + (p.fine - 0.5) * 0.16, 0.84, 0.88)
	p.lay(K["ALU_C"], chips * (1.0 - lip), None, 0.34, 0.0, 1.0)
	rusted(p, chips * (1.0 - lip))
	# Soot: back from the lip low down, heavy over the stubs, heat straw on top.
	lower = np.abs(t % math.tau - math.pi)     # from the keel
	low = 1.0 - sst(0.5, 1.7, lower)
	p.stain(K["SOOT_C"], np.clip(low * sst(0.55, 1.0, q) * (0.45 + 0.55 * p.across) * 1.1, 0.0, 0.85), 0.8)
	p.stain(K["OIL_C"], np.clip(low * sst(0.3, 0.72, p.across) * 0.7, 0.0, 0.7), 0.32)
	p.stain(np.array((0.3, 0.27, 0.22), dtype=np.float32), sst(0.2, 0.5, q) * sst(0.5, 0.8, p.across) * 0.12)
	heat = band(q, 0.64, 1.0, 0.12) * (0.25 + 0.5 * low)
	p.stain(np.array((0.22, 0.2, 0.19), dtype=np.float32), heat * 0.2)
	p.store()


# --- Tail ---------------------------------------------------------------------

def paint_fin(cv, reg):
	p = Part(cv, reg)
	right = reg == "fin_r"
	D = K["D"]
	col = (p.xx - 5.0) / D
	z = (0.77 - col) if right else (col + 0.47)
	y = 0.312 - (p.yy - 8.0) / D
	hinge = K["FIN_HINGE"]
	rudder = sst(hinge - 0.0005, hinge + 0.0005, z)
	# Fin: trim. Rudder: cloth, cream, with trim bars.
	p.col[:] = K["TRIM_C"]
	p.mk[..., 1] = 1.0
	p.rgh[:] = 0.46
	p.coat[:] = 0.45
	p.shade(1.0 + (p.big - 0.5) * 0.3 + (p.mid - 0.5) * 0.16)
	p.lay(K["WING_C"], rudder, 2, 0.6, 0.3)
	silver_cloth(p, rudder)
	p.shade(1.0 + (p.big - 0.5) * 0.1 * rudder)
	p.lay(K["BODY_C"], band(y, -0.2, 0.17, 0.001) * rudder, 0, 0.46, 0.45)
	# Ribs, horizontal; a spar line; cloth weave.
	pitch = 0.042
	rib = np.abs(((y / pitch + 0.5) % 1.0) - 0.5) * pitch
	tape = 1.0 - sst(0.004, 0.0054, rib)
	slack = np.sin(((y / pitch) % 1.0) * math.pi)
	p.shade(1.0 + tape * 0.09 - slack * 0.05)
	p.hgt += tape * 1.2 + weave(col, y, 0.0034) * 0.1 + (p.fine - 0.5) * 0.25
	stitch = dots(rib, col, 0.2, 0.0115, 0.0015) * tape
	p.shade(1.0 - stitch * 0.3)
	# The hinge: a gap and three plates.
	gap = 1.0 - sst(0.0012, 0.003, np.abs(z - hinge))
	p.lay(np.array((0.07, 0.07, 0.07), dtype=np.float32), gap, None, 0.8, 0.0)
	p.hgt -= gap * 2.4
	for hy in (0.09, 0.17, 0.25):
		pl = band(y, hy - 0.012, hy + 0.012, 0.001) * band(z, hinge - 0.02, hinge + 0.02, 0.001)
		p.lay(K["ALU_C"] * 0.8, pl, None, 0.45, 0.0, 0.8)
		p.hgt += pl * 1.3
	# Dirt: the wash streaks back along the fin; soot low; chips at the top.
	p.stain(K["DUST_C"], sst(0.5, 0.8, p.along) * 0.22)
	p.stain(K["SOOT_C"], (1.0 - sst(0.05, 0.16, y)) * sst(0.35, 0.7, p.along) * 0.42)
	chips = chipped(p.chip + (p.fine - 0.5) * 0.2 + sst(0.27, 0.31, y) * 0.1, 0.76, 0.8)
	p.lay(K["PRIMER_C"], chips * 0.85, None, 0.8, 0.0)
	cz = 0.6
	cx = (0.77 - cz) * D if right else (cz - 0.47) * D
	p.text("27", cx + 5.0, (0.312 - 0.165) * D, 8, K["WING_C"], 2, False, False, 0.92, 0.3)
	p.text("WANDERER", cx + 8.0, (0.312 - 0.105) * D, 2, K["WING_C"], 2, False, False, 0.8)
	p.store()


def paint_tailplane(cv):
	p = Part(cv, "tail")
	D = K["D"]
	a = (p.xx - 6.0) / D
	b = (p.yy - 6.0) / D
	p.col[:] = K["WING_C"]
	p.mk[..., 2] = 1.0
	p.rgh[:] = 0.6
	p.coat[:] = 0.3
	p.shade(1.0 + (p.big - 0.5) * 0.14)
	silver_cloth(p)
	pitch = 0.052
	rib = np.abs(((a / pitch + 0.5) % 1.0) - 0.5) * pitch
	tape = 1.0 - sst(0.0042, 0.0056, rib)
	slack = np.sin(((a / pitch) % 1.0) * math.pi)
	p.shade(1.0 + tape * 0.09 - slack * 0.05)
	p.hgt += tape * 1.2 + weave(a, b, 0.0034) * 0.1
	h = K["TAIL_CHORD"] * K["ELEV_H"]
	gap = 1.0 - sst(0.001, 0.0024, np.abs(b - h + 0.0 * a))
	p.lay(np.array((0.08, 0.08, 0.08), dtype=np.float32), gap, None, 0.8, 0.0)
	p.hgt -= gap * 2.2
	p.lay(K["TRIM_C"], sst(0.205, 0.207, a), 1, 0.46, 0.45)
	p.lay(K["BODY_C"], sst(h + 0.002, h + 0.004, b) * (1.0 - sst(0.205, 0.207, a)), 0, 0.46, 0.45)
	p.stain(K["DUST_C"], sst(0.5, 0.8, p.across) * 0.22)
	p.stain(K["SOOT_C"], (1.0 - sst(0.0, 0.1, a)) * sst(0.4, 0.75, p.across) * 0.35)
	p.store()


# --- Small parts --------------------------------------------------------------

def paint_prop(cv):
	p = Part(cv, "prop")
	D = K["D"]
	r = (p.xx - 6.0) / D
	v = (p.yy - 50.0) / 38.0
	# Laminations: walnut and ash, curving out of the boss.
	lam = np.sin((v * 2.3 + (r - 0.15) ** 2 * 6.0) * math.pi * 2.5)
	wood = over(np.broadcast_to(K["PROP_C"], p.col.shape), np.broadcast_to(np.array((0.62, 0.42, 0.24), dtype=np.float32), p.col.shape), sst(-0.3, 0.3, lam))
	p.col = wood * (1.0 + (p.across[..., None] - 0.5) * 0.3)
	p.rgh[:] = 0.28
	p.coat[:] = 0.8
	p.hgt += lam * 0.1
	# The tipping: brass sheathed, its edge pinned.
	tip = sst(0.2, 0.202, r)
	brass = K["BRASS_C"] * (1.0 + (p.mid[..., None] - 0.5) * 0.3)
	p.col = over(p.col, brass, tip)
	p.met = tip
	p.rgh = p.rgh * (1.0 - tip) + 0.3 * tip
	p.coat *= 1.0 - tip
	ln = dots(r - 0.205, v, 10.0, 0.25, 0.09)
	p.shade(1.0 - ln * 0.5)
	# The leading edge chipped by rain and grit.
	nick = sst(0.6, 0.66, p.chip + (p.fine - 0.5) * 0.3) * sst(0.5, 0.95, np.abs(v))
	p.col = over(p.col, np.array((0.3, 0.2, 0.13), dtype=np.float32), nick * (1.0 - tip) * 0.6)
	p.store()


def polished(p):
	"""Brass a hand keeps bright: gold, a breath of tarnish in the low places,
	rubbed pale along the grain."""
	c = np.broadcast_to(K["BRASS_C"] * np.array((0.98, 0.93, 0.8), dtype=np.float32), p.col.shape)
	c = over(c, np.array((0.56, 0.43, 0.22), dtype=np.float32), sst(0.58, 0.82, p.mid) * 0.16)
	c = over(c, np.array((0.95, 0.84, 0.58), dtype=np.float32), sst(0.56, 0.76, p.along) * 0.34)
	return c


def paint_wheel(cv):
	p = Part(cv, "wheel")
	D = K["D"]
	c = p.w * 0.5
	dy = (p.yy - c) / D
	dx = (p.xx - c) / D
	r = np.sqrt(dx * dx + dy * dy)
	ang = np.arctan2(dy, dx)
	p.col[:] = K["WING_C"]
	p.mk[..., 2] = 1.0
	p.rgh[:] = 0.5
	p.coat[:] = 0.4
	p.shade(1.0 + (p.mid - 0.5) * 0.2)
	# Rim and hub rings of rivets, the disc's two halves; brass at the hub.
	seam = 1.0 - sst(0.0006, 0.0014, np.abs(r - 0.042))
	p.shade(1.0 - seam * 0.6)
	p.hgt -= seam * 2.0
	spokes = dots(ang * 0.05, r - 0.05, math.tau * 0.05 / 18.0, 10.0, 0.0017)
	p.shade(1.0 + spokes * 0.14)
	p.hgt += spokes * 1.6
	spokes = dots(ang * 0.03, r - 0.031, math.tau * 0.03 / 10.0, 10.0, 0.0017)
	p.hgt += spokes * 1.6
	hub = 1.0 - sst(0.0195, 0.0205, r)
	brass = K["BRASS_C"] * (1.0 + (p.mid[..., None] - 0.5) * 0.3)
	p.col = over(p.col, brass, hub)
	p.mk *= (1.0 - hub)[..., None]
	p.met = hub
	p.rgh = p.rgh * (1.0 - hub) + 0.3 * hub
	p.coat *= 1.0 - hub
	rim = sst(0.052, 0.054, r)
	p.lay(np.array((0.12, 0.115, 0.11), dtype=np.float32), rim, None, 0.85, 0.0)
	p.stain(np.array((0.3, 0.23, 0.15), dtype=np.float32), sst(0.03, 0.055, r) * sst(0.42, 0.7, p.mid) * 0.6)
	p.store()
	t = Part(cv, "tread")
	u, v = t.xx, t.yy
	t.col[:] = (0.1, 0.095, 0.09)
	t.rgh[:] = 0.86
	bar = np.sin(u * 0.32) * sst(0.25, 0.3, v / t.h_) * (1.0 - sst(0.7, 0.75, v / t.h_))
	t.hgt += bar * 1.5
	t.shade(1.0 + bar * 0.25 + (t.mid - 0.5) * 0.4)
	t.stain(np.array((0.3, 0.24, 0.17), dtype=np.float32), sst(0.5, 0.75, t.mid) * 0.5)
	t.store()


def paint_swatches(cv):
	for name in K["SW_NAMES"]:
		x, y = K["SW"][name]
		p = Part(cv, rect=(x, y, K["SWATCH"], K["SWATCH"]))
		n = 1.0 + (p.mid - 0.5) * 0.3 + (p.fine - 0.5) * 0.14
		if name in ("dark", "trim", "body", "wing"):
			slot = {"body": 0, "trim": 1, "wing": 2, "dark": 3}[name]
			p.col[:] = K[{"body": "BODY_C", "trim": "TRIM_C", "wing": "WING_C", "dark": "DARK_C"}[name]]
			p.mk[..., slot] = 1.0
			p.rgh[:] = 0.48
			p.coat[:] = 0.4
			p.shade(n)
			p.stain(K["DUST_C"], sst(0.55, 0.8, p.mid) * 0.25)
			chips = chipped(p.chip, 0.76, 0.8)
			p.lay(K["ALU_C"], chips * 0.8, None, 0.4, 0.0, 1.0)
		elif name == "brass":
			p.col = polished(p)
			p.met[:] = 1.0
			p.rgh[:] = 0.26
			p.coat[:] = 0.5
		elif name == "steel":
			p.col[:] = (0.42, 0.42, 0.42)
			p.met[:] = 1.0
			p.rgh[:] = 0.42
			p.shade(n)
		elif name == "alu":
			p.col[:] = K["ALU_C"]
			p.met[:] = 1.0
			p.rgh[:] = 0.4
			p.shade(n)
		elif name == "fin_alu":
			p.col[:] = (0.34, 0.34, 0.33)
			p.met[:] = 0.6
			p.rgh[:] = 0.55
			p.shade(n)
			p.stain(K["SOOT_C"], sst(0.4, 0.7, p.mid) * 0.5)
		elif name == "burnt":
			p.col[:] = (0.3, 0.24, 0.2)
			p.met[:] = 0.7
			p.rgh[:] = 0.62
			p.shade(n)
			p.col = over(p.col, np.array((0.44, 0.27, 0.16), dtype=np.float32), sst(0.5, 0.75, p.mid) * 0.3)
			p.col = over(p.col, np.array((0.09, 0.08, 0.08), dtype=np.float32), sst(0.5, 0.8, p.fine) * 0.6)
			p.col = over(p.col, np.array((0.36, 0.31, 0.4), dtype=np.float32), sst(0.6, 0.8, p.big) * 0.3)
		elif name == "rubber":
			p.col[:] = (0.09, 0.085, 0.08)
			p.rgh[:] = 0.85
		elif name == "black":
			p.col[:] = (0.035, 0.035, 0.035)
			p.rgh[:] = 0.9
		elif name == "red":
			p.col[:] = (0.75, 0.1, 0.08)
			p.rgh[:] = 0.2
		elif name == "green":
			p.col[:] = (0.1, 0.65, 0.3)
			p.rgh[:] = 0.2
		elif name == "wire":
			p.col[:] = (0.36, 0.36, 0.35)
			p.met[:] = 0.8
			p.rgh[:] = 0.45
		p.store()


def normal_from(hgt, strength):
	gx = np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)
	gy = np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)
	nx = -gx * strength
	ny = gy * strength
	nz = np.ones_like(hgt)
	ln = np.sqrt(nx * nx + ny * ny + nz * nz)
	return np.stack((nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5), axis=-1)


def halve(a):
	h, w = a.shape[:2]
	h -= h % 2
	w -= w % 2
	a = a[:h, :w]
	return (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) * 0.25


def paint_all(constants, scale=1, **bake):
	"""The atlas's maps. `bake`: BAKE_DEFAULTS's names (a skin's own atlas)."""
	K.update(constants)
	for k, v in BAKE_DEFAULTS.items():
		K[k] = bake.get(k, v)
	unknown = set(bake) - set(BAKE_DEFAULTS)
	if unknown:
		raise ValueError("paint_all: no bake setting %s" % sorted(unknown))
	cv = Canvas()
	# What no region covers: the plane's own dull terracotta, never a bright seam.
	cv.a[:] = K["BODY_C"] * 0.5
	paint_wing(cv, "up_top", True, True)
	paint_wing(cv, "up_under", False, True)
	paint_wing(cv, "lo_top", True, False)
	paint_wing(cv, "lo_under", False, False)
	paint_body(cv)
	paint_cowl(cv)
	paint_fin(cv, "fin_r")
	paint_fin(cv, "fin_l")
	paint_tailplane(cv)
	paint_prop(cv)
	paint_wheel(cv)
	paint_swatches(cv)
	albedo = cv.a
	nrm = normal_from(cv.h, 1.1)
	mask = cv.k
	orm = np.stack((cv.r, cv.m, cv.c, np.ones_like(cv.r)), axis=-1)
	for _ in range(scale - 1):
		albedo = halve(albedo)
		nrm = halve(nrm)
	# Data maps at half the size: nothing in them is finer than a seam.
	return {"albedo": albedo, "normal": nrm, "mask": halve(mask), "orm": halve(orm)}
